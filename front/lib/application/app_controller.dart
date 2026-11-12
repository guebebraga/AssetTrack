import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/local_store.dart';
import '../core/utils/ids.dart';
import '../data/api_client.dart';
import '../data/app_repository.dart';
import '../data/outbox.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import '../domain/rfid/rfid.dart';
import '../services/alert_service.dart';
import '../services/inventory_service.dart';
import '../services/loan_service.dart';
import '../services/movement_service.dart';
import '../services/supplier_service.dart';
import 'auth_controller.dart';

class ActionResult {
  const ActionResult({required this.success, required this.message});

  final bool success;
  final String message;

  factory ActionResult.ok(String message) =>
      ActionResult(success: true, message: message);

  factory ActionResult.fail(String message) =>
      ActionResult(success: false, message: message);
}

final localStoreProvider = Provider<LocalStore>((ref) => JsonFileStore());

final outboxStoreProvider = Provider<LocalStore>(
  (ref) => JsonFileStore(fileName: 'assettrack_outbox.json'),
);

final outboxRepositoryProvider = Provider<OutboxRepository>(
  (ref) => OutboxRepository(ref.watch(outboxStoreProvider)),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final auth = ref.watch(authControllerProvider.notifier);
  return ApiClient(
    tokenProvider: ({bool forceRefresh = false}) =>
        auth.accessToken(forceRefresh: forceRefresh),
  );
});

final currentUserProvider = FutureProvider<Me>(
  (ref) => ref.watch(apiClientProvider).me(),
);

final currentRoleProvider = Provider<UserRole>((ref) {
  final me = ref.watch(currentUserProvider);
  return me.value?.role ?? UserRole.viewer;
});

final appRepositoryProvider = Provider<AppRepository>(
  (ref) => AppRepository(ref.watch(localStoreProvider)),
);

final appControllerProvider = AsyncNotifierProvider<AppController, AppState>(
  AppController.new,
);

final settingsProvider = Provider<AppSettings>((ref) {
  final value = ref.watch(appControllerProvider).value;
  return value?.settings ?? const AppSettings();
});

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final value = ref.watch(appControllerProvider).value;
  if (value == null) {
    return const DashboardStats(
      total: 0,
      inside: 0,
      outside: 0,
      unknown: 0,
      inRooms: 0,
      withoutRoom: 0,
      loans: 0,
      atSupplier: 0,
      todayMovements: 0,
      openAlerts: 0,
      criticalAlerts: 0,
      pendingReview: 0,
      overdueLoans: 0,
      pendingReturns: 0,
      maintenance: 0,
    );
  }
  return const InventoryService().stats(value, DateTime.now());
});

class AppController extends AsyncNotifier<AppState> {
  static const AlertService _alerts = AlertService();

  @override
  Future<AppState> build() async {
    final repository = ref.watch(appRepositoryProvider);
    final cached = await repository.load();
    final api = ref.read(apiClientProvider);
    try {
      await _flushOutbox(api);
      final snapshot = await api.getState();
      final loaded = AppState.fromSnapshot(snapshot);
      _alerts.rebuild(loaded);
      await repository.save(loaded);
      return loaded;
    } on ApiException catch (error) {
      if (cached != null) {
        _alerts.rebuild(cached);
        return cached;
      }
      throw ApiException(error.message, statusCode: error.statusCode);
    }
  }

  MovementService _movement(AppState current) => MovementService(
    current,
    dedupeWindowSeconds: current.settings.dedupeWindowSeconds,
  );

  Future<void> _applySnapshot(
    AppSnapshot snapshot, {
    bool rebuildAlerts = true,
  }) async {
    final next = AppState.fromSnapshot(snapshot);
    if (rebuildAlerts) _alerts.rebuild(next);
    state = AsyncData(next);
    await ref.read(appRepositoryProvider).save(next);
  }

  Future<void> _flushOutbox(ApiClient api) async {
    final outbox = ref.read(outboxRepositoryProvider);
    final items = await outbox.read();
    for (final item in items) {
      try {
        final response = await api.mutate(
          method: item.method,
          path: item.path,
          body: item.body,
          query: item.query,
          idempotencyKey: item.id,
        );
        await outbox.remove(item.id);
        if (!response.success) continue;
      } on ApiNetworkException {
        rethrow;
      } on ApiException catch (error) {
        await outbox.replace(
          item.copyWith(attempts: item.attempts + 1, lastError: error.message),
        );
        if (error.statusCode >= 400 && error.statusCode < 500) {
          await outbox.remove(item.id);
        }
        break;
      }
    }
  }

  Future<ActionResult> _mutate({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    required ActionResult Function(AppState current) local,
    bool rebuildAlerts = true,
  }) async {
    final current = state.value;
    if (current == null) {
      return ActionResult.fail('Los datos todavía se están cargando.');
    }
    final key = newId('IDEM');
    try {
      final response = await ref
          .read(apiClientProvider)
          .mutate(
            method: method,
            path: path,
            body: body,
            query: query,
            idempotencyKey: key,
          );
      await _applySnapshot(response.state, rebuildAlerts: rebuildAlerts);
      return ActionResult(success: response.success, message: response.message);
    } on ApiNetworkException {
      late ActionResult result;
      try {
        result = local(current);
      } catch (error) {
        return ActionResult.fail('No se pudo guardar el cambio: $error');
      }
      if (!result.success) return result;
      await ref
          .read(outboxRepositoryProvider)
          .add(
            PendingMutation(
              id: key,
              method: method,
              path: path,
              body: body,
              query: query,
              createdAt: DateTime.now(),
            ),
          );
      if (rebuildAlerts) _alerts.rebuild(current);
      state = AsyncData(current);
      await ref.read(appRepositoryProvider).save(current);
      return ActionResult(
        success: true,
        message:
            '${result.message} Se guardó offline y se sincronizará al '
            'recuperar la conexión.',
      );
    } on ApiException catch (error) {
      return ActionResult.fail(error.message);
    }
  }

  Future<ActionResult> syncPending() async {
    final api = ref.read(apiClientProvider);
    try {
      await _flushOutbox(api);
      final snapshot = await api.getState();
      await _applySnapshot(snapshot);
      return ActionResult.ok('Datos sincronizados con el servidor.');
    } on ApiException catch (error) {
      return ActionResult.fail(error.message);
    }
  }

  Future<ActionResult> createAsset(
    Asset asset, {
    bool allowContradiction = false,
  }) => _mutate(
    method: 'POST',
    path: '/api/v1/assets',
    body: asset.toJson(),
    query: allowContradiction ? {'allowContradiction': 'true'} : null,
    local: (current) {
      final category = current.categoryById(asset.categoryId);
      if (category == null) {
        return ActionResult.fail('Seleccioná una categoría válida.');
      }
      if (asset.code.trim().isEmpty) {
        return ActionResult.fail('El código interno es obligatorio.');
      }
      if (asset.rfidEpc.trim().isEmpty) {
        return ActionResult.fail('El identificador RFID es obligatorio.');
      }
      if (current.assetByCode(asset.code) != null) {
        return ActionResult.fail('El código ${asset.code} ya existe.');
      }
      if (current.assetByEpc(asset.rfidEpc) != null) {
        return ActionResult.fail('El identificador RFID ya está asignado.');
      }
      final contradiction = const InventoryService().contradictionFor(asset);
      if (contradiction != null && !allowContradiction) {
        return ActionResult.fail(contradiction);
      }
      current.assets.add(asset);
      return ActionResult.ok('Activo ${asset.code} creado correctamente.');
    },
  );

  Future<ActionResult> updateAsset(
    Asset asset, {
    bool allowContradiction = false,
  }) => _mutate(
    method: 'PUT',
    path: '/api/v1/assets/${asset.id}',
    body: asset.toJson(),
    query: allowContradiction ? {'allowContradiction': 'true'} : null,
    local: (current) {
      final index = current.assets.indexWhere((item) => item.id == asset.id);
      if (index < 0) return ActionResult.fail('No se encontró el activo.');
      final duplicatedCode = current.assets.any(
        (item) =>
            item.id != asset.id &&
            item.code.toLowerCase() == asset.code.trim().toLowerCase(),
      );
      if (duplicatedCode) {
        return ActionResult.fail('El código ${asset.code} ya existe.');
      }
      final duplicatedEpc = current.assets.any(
        (item) =>
            item.id != asset.id &&
            item.rfidEpc.toUpperCase() == asset.rfidEpc.trim().toUpperCase(),
      );
      if (duplicatedEpc) {
        return ActionResult.fail('El identificador RFID ya está asignado.');
      }
      final contradiction = const InventoryService().contradictionFor(asset);
      if (contradiction != null && !allowContradiction) {
        return ActionResult.fail(contradiction);
      }
      current.assets[index] = asset;
      return ActionResult.ok('Activo ${asset.code} actualizado.');
    },
  );

  Future<ActionResult> addCategory({
    required String name,
    required String prefix,
    String description = '',
  }) => _mutate(
    method: 'POST',
    path: '/api/v1/categories',
    body: {
      'name': name.trim(),
      'codePrefix': prefix.trim().toUpperCase(),
      'description': description.trim(),
    },
    local: (current) {
      if (name.trim().isEmpty || prefix.trim().isEmpty) {
        return ActionResult.fail('Nombre y prefijo son obligatorios.');
      }
      if (current.categories.any(
        (item) => item.name.toLowerCase() == name.trim().toLowerCase(),
      )) {
        return ActionResult.fail('La categoría ya existe.');
      }
      current.categories.add(
        AssetCategory(
          id: newId('CAT'),
          name: name.trim(),
          codePrefix: prefix.trim().toUpperCase(),
          description: description.trim(),
        ),
      );
      return ActionResult.ok('Categoría creada.');
    },
  );

  Future<ActionResult> addAccess({
    required String name,
    required AccessType type,
    required String description,
    required List<String> readerIds,
  }) => _mutate(
    method: 'POST',
    path: '/api/v1/accesses',
    body: {
      'name': name.trim(),
      'type': type.name,
      'description': description.trim(),
      'readerIds': readerIds,
    },
    local: (current) {
      if (name.trim().isEmpty) {
        return ActionResult.fail('El nombre del acceso es obligatorio.');
      }
      current.accesses.add(
        AccessPoint(
          id: newId('ACC'),
          name: name.trim(),
          type: type,
          description: description.trim(),
          readerIds: readerIds,
        ),
      );
      return ActionResult.ok('Acceso agregado.');
    },
  );

  Future<ActionResult> updateAccess(AccessPoint access) => _mutate(
    method: 'PUT',
    path: '/api/v1/accesses/${access.id}',
    body: {
      'name': access.name,
      'type': access.type.name,
      'description': access.description,
      'readerIds': access.readerIds,
    },
    local: (current) {
      final index = current.accesses.indexWhere((item) => item.id == access.id);
      if (index < 0) return ActionResult.fail('No se encontró el acceso.');
      current.accesses[index] = access;
      return ActionResult.ok('Acceso actualizado.');
    },
  );

  Future<ActionResult> addZone({
    required String name,
    required String description,
    required List<String> readerIds,
  }) => _mutate(
    method: 'POST',
    path: '/api/v1/zones',
    body: {
      'name': name.trim(),
      'description': description.trim(),
      'readerIds': readerIds,
    },
    local: (current) {
      if (name.trim().isEmpty) {
        return ActionResult.fail('El nombre de la habitación es obligatorio.');
      }
      if (current.zones.any(
        (zone) => zone.name.toLowerCase() == name.trim().toLowerCase(),
      )) {
        return ActionResult.fail('La habitación ya existe.');
      }
      current.zones.add(
        Zone(
          id: newId('ZON'),
          name: name.trim(),
          description: description.trim(),
          readerIds: readerIds,
        ),
      );
      return ActionResult.ok('Habitación agregada.');
    },
  );

  Future<ActionResult> updateZone(Zone zone) => _mutate(
    method: 'PUT',
    path: '/api/v1/zones/${zone.id}',
    body: {
      'name': zone.name,
      'description': zone.description,
      'readerIds': zone.readerIds,
    },
    local: (current) {
      final index = current.zones.indexWhere((item) => item.id == zone.id);
      if (index < 0) return ActionResult.fail('No se encontró la habitación.');
      current.zones[index] = zone;
      return ActionResult.ok('Habitación actualizada.');
    },
  );

  Future<ActionResult> updateZoneConfiguration(String zoneId, bool active) =>
      _mutate(
        method: 'PATCH',
        path: '/api/v1/zones/$zoneId',
        body: {'active': active},
        local: (current) {
          final index = current.zones.indexWhere((item) => item.id == zoneId);
          if (index < 0) {
            return ActionResult.fail('No se encontró la habitación.');
          }
          current.zones[index] = current.zones[index].copyWith(active: active);
          return ActionResult.ok('Estado de la habitación actualizado.');
        },
      );

  Future<ActionResult> addSupplier({
    required String name,
    required String serviceType,
    String contact = '',
    String notes = '',
  }) => _mutate(
    method: 'POST',
    path: '/api/v1/suppliers',
    body: {
      'name': name.trim(),
      'serviceType': serviceType.trim(),
      'contact': contact.trim(),
      'notes': notes.trim(),
    },
    local: (current) {
      if (name.trim().isEmpty) {
        return ActionResult.fail('El nombre del proveedor es obligatorio.');
      }
      current.suppliers.add(
        Supplier(
          id: newId('SUP'),
          name: name.trim(),
          serviceType: serviceType.trim(),
          contact: contact.trim(),
          notes: notes.trim(),
        ),
      );
      return ActionResult.ok('Proveedor agregado.');
    },
  );

  Future<ActionResult> updateSupplier(Supplier supplier) => _mutate(
    method: 'PUT',
    path: '/api/v1/suppliers/${supplier.id}',
    body: {
      'name': supplier.name,
      'serviceType': supplier.serviceType,
      'contact': supplier.contact,
      'notes': supplier.notes,
    },
    local: (current) {
      final index = current.suppliers.indexWhere(
        (item) => item.id == supplier.id,
      );
      if (index < 0) return ActionResult.fail('No se encontró el proveedor.');
      current.suppliers[index] = supplier;
      return ActionResult.ok('Proveedor actualizado.');
    },
  );

  Future<ActionResult> deleteSupplier(String supplierId) => _mutate(
    method: 'DELETE',
    path: '/api/v1/suppliers/$supplierId',
    local: (current) {
      final usedByAsset = current.assets.any(
        (item) => item.supplierId == supplierId,
      );
      final usedByOperation = current.supplierOperations.any(
        (item) => item.supplierId == supplierId,
      );
      if (usedByAsset || usedByOperation) {
        final index = current.suppliers.indexWhere(
          (item) => item.id == supplierId,
        );
        if (index < 0) return ActionResult.fail('No se encontró el proveedor.');
        current.suppliers[index] = current.suppliers[index].copyWith(
          active: false,
        );
        return ActionResult.ok(
          'El proveedor tiene operaciones asociadas. Se marcó como inactivo.',
        );
      }
      current.suppliers.removeWhere((item) => item.id == supplierId);
      return ActionResult.ok('Proveedor eliminado.');
    },
  );

  Future<ActionResult> updateSettings(AppSettings settings) => _mutate(
    method: 'PUT',
    path: '/api/v1/settings',
    body: settings.toJson(),
    local: (current) {
      if (settings.outsideThresholdHours < 1 ||
          settings.alertDetectionHours < 1 ||
          settings.dedupeWindowSeconds < 1) {
        return ActionResult.fail('Los umbrales deben ser mayores a cero.');
      }
      current.settings = settings;
      return ActionResult.ok('Configuración guardada.');
    },
  );

  Future<ActionResult> updateAccessConfiguration(
    String accessId,
    bool configured,
  ) => _mutate(
    method: 'PATCH',
    path: '/api/v1/accesses/$accessId',
    body: {'configured': configured},
    local: (current) {
      final index = current.accesses.indexWhere((item) => item.id == accessId);
      if (index < 0) return ActionResult.fail('No se encontró el acceso.');
      current.accesses[index] = current.accesses[index].copyWith(
        configured: configured,
      );
      return ActionResult.ok('Estado del acceso actualizado.');
    },
  );

  Future<ActionResult> addReader(Reader reader) => _mutate(
    method: 'POST',
    path: '/api/v1/readers',
    body: reader.toJson(),
    local: (current) {
      if (reader.name.trim().isEmpty) {
        return ActionResult.fail('El nombre del lector es obligatorio.');
      }
      if (reader.antennaCount < 1) {
        return ActionResult.fail(
          'La cantidad de antenas debe ser mayor a cero.',
        );
      }
      if (reader.accessId != null && reader.zoneId != null) {
        return ActionResult.fail(
          'Un lector no puede pertenecer a un acceso y a una habitación a la vez.',
        );
      }
      current.readers.add(reader);
      return ActionResult.ok('Lector ${reader.id} creado correctamente.');
    },
  );

  Future<ActionResult> updateReader(Reader reader) => _mutate(
    method: 'PUT',
    path: '/api/v1/readers/${reader.id}',
    body: reader.toJson(),
    local: (current) {
      final index = current.readers.indexWhere((item) => item.id == reader.id);
      if (index < 0) return ActionResult.fail('No se encontró el lector.');
      if (reader.accessId != null && reader.zoneId != null) {
        return ActionResult.fail(
          'Un lector no puede pertenecer a un acceso y a una habitación a la vez.',
        );
      }
      current.readers[index] = reader;
      return ActionResult.ok('Lector ${reader.id} actualizado.');
    },
  );

  Future<ActionResult> updateReaderStatus(
    String readerId,
    ReaderStatus status,
  ) => _mutate(
    method: 'PATCH',
    path: '/api/v1/readers/$readerId/status',
    body: {'status': status.name},
    local: (current) {
      final index = current.readers.indexWhere((item) => item.id == readerId);
      if (index < 0) return ActionResult.fail('No se encontró el lector.');
      current.readers[index] = current.readers[index].copyWith(status: status);
      return ActionResult.ok('Estado del lector actualizado.');
    },
  );

  Future<ActionResult> deleteReader(String readerId) => _mutate(
    method: 'DELETE',
    path: '/api/v1/readers/$readerId',
    local: (current) {
      current.readers.removeWhere((item) => item.id == readerId);
      for (var index = 0; index < current.accesses.length; index++) {
        final access = current.accesses[index];
        current.accesses[index] = access.copyWith(
          readerIds: access.readerIds.where((id) => id != readerId).toList(),
        );
      }
      for (var index = 0; index < current.zones.length; index++) {
        final zone = current.zones[index];
        current.zones[index] = zone.copyWith(
          readerIds: zone.readerIds.where((id) => id != readerId).toList(),
        );
      }
      return ActionResult.ok('Lector dado de baja.');
    },
  );

  Future<ActionResult> applyCorrection({
    required String assetId,
    AssetLocation? location,
    AssetSituation? situation,
    OperationalStatus? operationalStatus,
    String? roomId,
    required String notes,
  }) => _mutate(
    method: 'POST',
    path: '/api/v1/assets/$assetId/corrections',
    body: {
      'location': location?.name,
      'situation': situation?.name,
      'operationalStatus': operationalStatus?.name,
      'roomId': roomId,
      'notes': notes.trim(),
    },
    local: (current) {
      final asset = current.assetById(assetId);
      if (asset == null) return ActionResult.fail('No se encontró el activo.');
      if (notes.trim().isEmpty) {
        return ActionResult.fail('La corrección requiere una justificación.');
      }
      final keepRoom = (location ?? asset.location) == AssetLocation.inside;
      var updated = asset.copyWith(
        location: location,
        situation: situation,
        operationalStatus: operationalStatus,
        roomId: roomId,
        clearRoom: !keepRoom || roomId == null,
        lastMovementAt: DateTime.now(),
        clearResponsible: situation == AssetSituation.available,
        clearSupplier: situation == AssetSituation.available,
        clearExpectedReturn:
            situation == AssetSituation.available ||
            situation == AssetSituation.maintenance,
      );
      if (location == AssetLocation.inside &&
          (situation == AssetSituation.available ||
              situation == AssetSituation.maintenance)) {
        updated = updated.copyWith(
          lastEntryAt: DateTime.now(),
          lastDetectionAt: DateTime.now(),
        );
      }
      current.assets[current.assets.indexWhere((item) => item.id == assetId)] =
          updated;
      final movement = _movement(current).record(
        assetId: assetId,
        type: MovementType.inventoryCorrection,
        timestamp: DateTime.now(),
        origin: EventOrigin.correction,
        notes: notes.trim(),
        reason: 'Corrección administrativa explícita',
        bypassValidation: true,
        checkDuplicate: false,
      );
      if (!movement.success) {
        return ActionResult.fail(movement.message);
      }
      return ActionResult.ok('Corrección registrada en el historial.');
    },
  );

  Future<ActionResult> createLoan({
    required String assetId,
    required String borrower,
    DateTime? dueAt,
    String reason = '',
    String notes = '',
    String? accessId,
    String? readerId,
  }) => _mutate(
    method: 'POST',
    path: '/api/v1/loans',
    body: {
      'assetId': assetId,
      'borrower': borrower,
      'dueAt': dueAt?.toIso8601String(),
      'reason': reason,
      'notes': notes,
      'accessId': accessId,
      'readerId': readerId,
    },
    local: (current) {
      final result = LoanService(current, movementService: _movement(current))
          .createLoan(
            assetId: assetId,
            borrower: borrower,
            deliveredAt: DateTime.now(),
            dueAt: dueAt,
            reason: reason,
            notes: notes,
            accessId: accessId,
            readerId: readerId,
          );
      return ActionResult(success: result.success, message: result.message);
    },
  );

  Future<ActionResult> returnLoan({
    required String loanId,
    bool confirmedInside = false,
    bool administrativeCorrection = false,
    String notes = '',
  }) => _mutate(
    method: 'POST',
    path: '/api/v1/loans/$loanId/return',
    body: {
      'confirmedInside': confirmedInside,
      'administrativeCorrection': administrativeCorrection,
      'notes': notes,
    },
    local: (current) {
      final result = LoanService(current, movementService: _movement(current))
          .returnLoan(
            loanId: loanId,
            returnedAt: DateTime.now(),
            confirmedInside: confirmedInside,
            administrativeCorrection: administrativeCorrection,
            notes: notes,
          );
      return ActionResult(success: result.success, message: result.message);
    },
  );

  Future<ActionResult> markLoanPendingVerification(String loanId) => _mutate(
    method: 'POST',
    path: '/api/v1/loans/$loanId/pending-verification',
    local: (current) {
      final result = LoanService(
        current,
        movementService: _movement(current),
      ).markPendingVerification(loanId);
      return ActionResult(success: result.success, message: result.message);
    },
  );

  Future<ActionResult> createSupplierDelivery({
    required String supplierId,
    required List<String> assetIds,
    DateTime? dueAt,
    String reason = '',
    String notes = '',
    String? accessId,
    String? readerId,
    EventOrigin origin = EventOrigin.manual,
  }) => _mutate(
    method: 'POST',
    path: '/api/v1/supplier-operations',
    body: {
      'supplierId': supplierId,
      'assetIds': assetIds,
      'dueAt': dueAt?.toIso8601String(),
      'reason': reason,
      'notes': notes,
      'accessId': accessId,
      'readerId': readerId,
      'origin': origin.name,
    },
    local: (current) {
      final result =
          SupplierService(
            current,
            movementService: _movement(current),
          ).createDelivery(
            supplierId: supplierId,
            assetIds: assetIds,
            deliveredAt: DateTime.now(),
            dueAt: dueAt,
            reason: reason,
            notes: notes,
            accessId: accessId,
            readerId: readerId,
            origin: origin,
          );
      return ActionResult(success: result.success, message: result.message);
    },
  );

  Future<ActionResult> deliverSupplierOperation(String operationId) => _mutate(
    method: 'POST',
    path: '/api/v1/supplier-operations/$operationId/deliver',
    body: {
      'accessId': 'acc-proveedores',
      'readerId': 'LEC-PROV-01',
      'notes': 'Salida registrada desde la operación preparada.',
    },
    local: (current) {
      final result =
          SupplierService(
            current,
            movementService: _movement(current),
          ).deliverOperation(
            operationId: operationId,
            deliveredAt: DateTime.now(),
            accessId: 'acc-proveedores',
            readerId: 'LEC-PROV-01',
            notes: 'Salida registrada desde la operación preparada.',
          );
      return ActionResult(success: result.success, message: result.message);
    },
  );

  Future<ActionResult> receiveSupplierAssets({
    required String operationId,
    required List<String> assetIds,
    String notes = '',
    String? accessId,
    String? readerId,
    EventOrigin origin = EventOrigin.manual,
  }) => _mutate(
    method: 'POST',
    path: '/api/v1/supplier-operations/$operationId/receive',
    body: {
      'assetIds': assetIds,
      'notes': notes,
      'accessId': accessId,
      'readerId': readerId,
      'origin': origin.name,
    },
    local: (current) {
      final result =
          SupplierService(
            current,
            movementService: _movement(current),
          ).receiveAssets(
            operationId: operationId,
            receivedAssetIds: assetIds,
            receivedAt: DateTime.now(),
            notes: notes,
            accessId: accessId,
            readerId: readerId,
            origin: origin,
          );
      return ActionResult(success: result.success, message: result.message);
    },
  );

  Future<ActionResult> receiveNewSupplierAsset({
    required String operationId,
    required String code,
    required String name,
    required String categoryId,
    required String rfidEpc,
    String description = '',
    String notes = '',
  }) => _mutate(
    method: 'POST',
    path: '/api/v1/supplier-operations/$operationId/receive-new-asset',
    body: {
      'code': code.trim(),
      'name': name.trim(),
      'categoryId': categoryId,
      'rfidEpc': rfidEpc.trim().toUpperCase(),
      'description': description.trim(),
      'notes': notes,
    },
    local: (current) {
      if (current.assetByCode(code) != null) {
        return ActionResult.fail('El código $code ya existe.');
      }
      if (current.assetByEpc(rfidEpc) != null) {
        return ActionResult.fail('El identificador RFID ya está asignado.');
      }
      if (current.categoryById(categoryId) == null) {
        return ActionResult.fail('Seleccioná una categoría válida.');
      }
      final asset = Asset(
        id: newId('AST'),
        code: code.trim(),
        name: name.trim(),
        categoryId: categoryId,
        description: description.trim(),
        rfidEpc: rfidEpc.trim().toUpperCase(),
        location: AssetLocation.outside,
        situation: AssetSituation.available,
        operationalStatus: OperationalStatus.operational,
        createdAt: DateTime.now(),
        notes: 'Unidad incorporada durante una recepción de proveedor.',
      );
      current.assets.add(asset);
      final result =
          SupplierService(
            current,
            movementService: _movement(current),
          ).receiveAssets(
            operationId: operationId,
            receivedAssetIds: [asset.id],
            receivedAt: DateTime.now(),
            notes: notes.isEmpty
                ? 'Alta controlada de unidad no registrada.'
                : notes,
            origin: EventOrigin.manual,
          );
      if (!result.success) {
        current.assets.removeWhere((item) => item.id == asset.id);
      }
      return ActionResult(success: result.success, message: result.message);
    },
  );

  Future<ActionResult> completeSupplierOperation(
    String operationId, {
    String notes = '',
  }) => _mutate(
    method: 'POST',
    path: '/api/v1/supplier-operations/$operationId/complete',
    body: {'notes': notes},
    local: (current) {
      final result = SupplierService(
        current,
        movementService: _movement(current),
      ).completeWithPending(operationId: operationId, notes: notes);
      return ActionResult(success: result.success, message: result.message);
    },
  );

  Future<ActionResult> simulateEntry({
    required String assetId,
    required String accessId,
    required String readerId,
  }) => _simulateRead(
    assetId: assetId,
    accessId: accessId,
    readerId: readerId,
    direction: RfidDirectionHint.inbound,
  );

  Future<ActionResult> simulateExit({
    required String assetId,
    required String accessId,
    required String readerId,
  }) => _simulateRead(
    assetId: assetId,
    accessId: accessId,
    readerId: readerId,
    direction: RfidDirectionHint.outbound,
  );

  Future<ActionResult> simulateAmbiguousRead({
    required String assetId,
    required String accessId,
    required String readerId,
  }) => _simulateRead(assetId: assetId, accessId: accessId, readerId: readerId);

  Future<ActionResult> simulateRoomEntry({
    required String assetId,
    required String zoneId,
    required String readerId,
  }) => _simulateRoomRead(
    assetId: assetId,
    zoneId: zoneId,
    readerId: readerId,
    direction: RfidDirectionHint.inbound,
  );

  Future<ActionResult> simulateRoomExit({
    required String assetId,
    required String zoneId,
    required String readerId,
  }) => _simulateRoomRead(
    assetId: assetId,
    zoneId: zoneId,
    readerId: readerId,
    direction: RfidDirectionHint.outbound,
  );

  Future<ActionResult> simulateRoomAmbiguousRead({
    required String assetId,
    required String zoneId,
    required String readerId,
  }) => _simulateRoomRead(assetId: assetId, zoneId: zoneId, readerId: readerId);

  Future<ActionResult> _sendRfidReads(
    List<Map<String, dynamic>> reads, {
    required ActionResult Function(AppState current) local,
  }) async {
    final current = state.value;
    if (current == null) {
      return ActionResult.fail('Los datos todavía se están cargando.');
    }
    try {
      final response = await ref.read(apiClientProvider).sendRfidReads(reads);
      await _applySnapshot(response.state);
      if (response.results.isEmpty) {
        return ActionResult.fail('El servidor no devolvió resultados.');
      }
      final success = response.results.every(
        (result) => result.success || result.duplicate,
      );
      return ActionResult(
        success: success,
        message: response.results.map((result) => result.message).join('\n'),
      );
    } on ApiNetworkException {
      late ActionResult result;
      try {
        result = local(current);
      } catch (error) {
        return ActionResult.fail('No se pudo procesar la lectura: $error');
      }
      if (result.success) {
        _alerts.rebuild(current);
        state = AsyncData(current);
        await ref.read(appRepositoryProvider).save(current);
      }
      return result;
    } on ApiException catch (error) {
      return ActionResult.fail(error.message);
    }
  }

  Future<ActionResult> _simulateRoomRead({
    required String assetId,
    required String zoneId,
    required String readerId,
    RfidDirectionHint? direction,
  }) {
    final asset = state.value?.assetById(assetId);
    if (asset == null) {
      return Future.value(ActionResult.fail('No se encontró el activo.'));
    }
    return _sendRfidReads(
      [
        {
          'epc': asset.rfidEpc,
          'readerId': readerId,
          'accessId': '',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'directionHint': direction?.name,
          'roomId': zoneId,
          'antenna': 1,
          'rssi': -55,
          'origin': EventOrigin.simulator.name,
        },
      ],
      local: (current) {
        final processor = RfidEventProcessor(
          current,
          movementService: _movement(current),
        );
        final read = processor.process(
          RfidEvent(
            epc: asset.rfidEpc,
            readerId: readerId,
            accessId: '',
            timestamp: DateTime.now(),
            directionHint: direction,
            roomId: zoneId,
          ),
          origin: EventOrigin.simulator,
        );
        return ActionResult(
          success: read.recognised && !read.duplicate && !read.ambiguous,
          message: read.message,
        );
      },
    );
  }

  Future<ActionResult> simulateRepeatedRead({
    required String assetId,
    required String accessId,
    required String readerId,
    bool inbound = true,
  }) {
    final asset = state.value?.assetById(assetId);
    if (asset == null) {
      return Future.value(ActionResult.fail('No se encontró el activo.'));
    }
    final direction = inbound
        ? RfidDirectionHint.inbound
        : RfidDirectionHint.outbound;
    final timestamp = DateTime.now();
    Map<String, dynamic> read(DateTime moment) => {
      'epc': asset.rfidEpc,
      'readerId': readerId,
      'accessId': accessId,
      'timestamp': moment.toUtc().toIso8601String(),
      'directionHint': direction.name,
      'antenna': 1,
      'rssi': -55,
      'origin': EventOrigin.simulator.name,
    };
    return _sendRfidReads(
      [read(timestamp), read(timestamp.add(const Duration(seconds: 1)))],
      local: (current) {
        final processor = RfidEventProcessor(
          current,
          movementService: _movement(current),
        );
        processor.process(
          RfidEvent(
            epc: asset.rfidEpc,
            readerId: readerId,
            accessId: accessId,
            timestamp: timestamp,
            directionHint: direction,
          ),
          origin: EventOrigin.simulator,
        );
        final repeated = processor.process(
          RfidEvent(
            epc: asset.rfidEpc,
            readerId: readerId,
            accessId: accessId,
            timestamp: timestamp.add(const Duration(seconds: 1)),
            directionHint: direction,
          ),
          origin: EventOrigin.simulator,
        );
        return ActionResult(
          success: repeated.duplicate,
          message: repeated.duplicate
              ? '${asset.code}: la segunda lectura fue ignorada. Solo se '
                    'generó un movimiento.'
              : '${asset.code}: ${repeated.message}',
        );
      },
    );
  }

  Future<ActionResult> _simulateRead({
    required String assetId,
    required String accessId,
    required String readerId,
    RfidDirectionHint? direction,
  }) {
    final asset = state.value?.assetById(assetId);
    if (asset == null) {
      return Future.value(ActionResult.fail('No se encontró el activo.'));
    }
    return _sendRfidReads(
      [
        {
          'epc': asset.rfidEpc,
          'readerId': readerId,
          'accessId': accessId,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'directionHint': direction?.name,
          'antenna': 1,
          'rssi': -55,
          'origin': EventOrigin.simulator.name,
        },
      ],
      local: (current) {
        final processor = RfidEventProcessor(
          current,
          movementService: _movement(current),
        );
        final read = processor.process(
          RfidEvent(
            epc: asset.rfidEpc,
            readerId: readerId,
            accessId: accessId,
            timestamp: DateTime.now(),
            directionHint: direction,
          ),
          origin: EventOrigin.simulator,
        );
        return ActionResult(
          success: read.recognised && !read.duplicate,
          message: read.message,
        );
      },
    );
  }

  Future<ActionResult> resolveAlert(String alertId) => _mutate(
    method: 'POST',
    path: '/api/v1/alerts/$alertId/resolve',
    local: (current) {
      final index = current.alerts.indexWhere((alert) => alert.id == alertId);
      if (index < 0) return ActionResult.fail('No se encontró la alerta.');
      current.alerts[index] = current.alerts[index].copyWith(
        resolvedAt: DateTime.now(),
      );
      return ActionResult.ok('Alerta marcada como resuelta.');
    },
  );

  Future<ActionResult> resolvePendingEvent(
    String eventId, {
    required bool approve,
    String notes = '',
  }) => _mutate(
    method: 'POST',
    path: '/api/v1/movements/$eventId/resolve',
    body: {'approve': approve, 'notes': notes},
    local: (current) {
      final result = _movement(current)
          .resolvePendingEvent(eventId, approve: approve, notes: notes);
      return ActionResult(success: result.success, message: result.message);
    },
  );

  Future<ActionResult> resetDemo() async {
    final repository = ref.read(appRepositoryProvider);
    final api = ref.read(apiClientProvider);
    try {
      await repository.clear();
      final snapshot = await api.getState();
      final loaded = AppState.fromSnapshot(snapshot);
      _alerts.rebuild(loaded);
      state = AsyncData(loaded);
      await repository.save(loaded);
      return ActionResult.ok('Cache local eliminada y datos recargados.');
    } on ApiException catch (error) {
      return ActionResult.fail(error.message);
    }
  }
}
