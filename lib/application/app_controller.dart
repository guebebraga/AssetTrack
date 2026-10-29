import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/local_store.dart';
import '../core/utils/ids.dart';
import '../data/app_repository.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import '../domain/rfid/rfid.dart';
import '../domain/seed/demo_seed.dart';
import '../services/alert_service.dart';
import '../services/inventory_service.dart';
import '../services/loan_service.dart';
import '../services/movement_service.dart';
import '../services/supplier_service.dart';

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
    final loaded = await repository.load();
    if (loaded != null) {
      _alerts.rebuild(loaded);
      return loaded;
    }
    final seeded = DemoSeed.buildState();
    _alerts.rebuild(seeded);
    await repository.save(seeded);
    return seeded;
  }

  MovementService _movement(AppState current) => MovementService(
    current,
    dedupeWindowSeconds: current.settings.dedupeWindowSeconds,
  );

  Future<ActionResult> _mutate(
    ActionResult Function(AppState current) action, {
    bool rebuildAlerts = true,
  }) async {
    final current = state.value;
    if (current == null) {
      return ActionResult.fail('Los datos todavía se están cargando.');
    }
    late ActionResult result;
    try {
      result = action(current);
      if (rebuildAlerts) _alerts.rebuild(current);
      state = AsyncData(current);
      await ref.read(appRepositoryProvider).save(current);
    } catch (error) {
      return ActionResult.fail('No se pudo guardar el cambio: $error');
    }
    return result;
  }

  Future<ActionResult> createAsset(
    Asset asset, {
    bool allowContradiction = false,
  }) => _mutate((current) {
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
  });

  Future<ActionResult> updateAsset(
    Asset asset, {
    bool allowContradiction = false,
  }) => _mutate((current) {
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
  });

  Future<ActionResult> addCategory({
    required String name,
    required String prefix,
    String description = '',
  }) => _mutate((current) {
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
  });

  Future<ActionResult> addAccess({
    required String name,
    required AccessType type,
    required String description,
    required List<String> readerIds,
  }) => _mutate((current) {
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
  });

  Future<ActionResult> updateAccess(AccessPoint access) => _mutate((current) {
    final index = current.accesses.indexWhere((item) => item.id == access.id);
    if (index < 0) return ActionResult.fail('No se encontró el acceso.');
    current.accesses[index] = access;
    return ActionResult.ok('Acceso actualizado.');
  });

  Future<ActionResult> addSupplier({
    required String name,
    required String serviceType,
    String contact = '',
    String notes = '',
  }) => _mutate((current) {
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
  });

  Future<ActionResult> updateSupplier(Supplier supplier) => _mutate((current) {
    final index = current.suppliers.indexWhere(
      (item) => item.id == supplier.id,
    );
    if (index < 0) return ActionResult.fail('No se encontró el proveedor.');
    current.suppliers[index] = supplier;
    return ActionResult.ok('Proveedor actualizado.');
  });

  Future<ActionResult> deleteSupplier(String supplierId) => _mutate((current) {
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
  });

  Future<ActionResult> updateSettings(AppSettings settings) =>
      _mutate((current) {
        if (settings.outsideThresholdHours < 1 ||
            settings.alertDetectionHours < 1 ||
            settings.dedupeWindowSeconds < 1) {
          return ActionResult.fail('Los umbrales deben ser mayores a cero.');
        }
        current.settings = settings;
        return ActionResult.ok('Configuración guardada.');
      });

  Future<ActionResult> updateAccessConfiguration(
    String accessId,
    bool configured,
  ) => _mutate((current) {
    final index = current.accesses.indexWhere((item) => item.id == accessId);
    if (index < 0) return ActionResult.fail('No se encontró el acceso.');
    current.accesses[index] = current.accesses[index].copyWith(
      configured: configured,
    );
    return ActionResult.ok('Estado del acceso actualizado.');
  });

  Future<ActionResult> applyCorrection({
    required String assetId,
    AssetLocation? location,
    AssetSituation? situation,
    OperationalStatus? operationalStatus,
    required String notes,
  }) => _mutate((current) {
    final asset = current.assetById(assetId);
    if (asset == null) return ActionResult.fail('No se encontró el activo.');
    if (notes.trim().isEmpty) {
      return ActionResult.fail('La corrección requiere una justificación.');
    }
    var updated = asset.copyWith(
      location: location,
      situation: situation,
      operationalStatus: operationalStatus,
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
  });

  Future<ActionResult> createLoan({
    required String assetId,
    required String borrower,
    DateTime? dueAt,
    String reason = '',
    String notes = '',
    String? accessId,
    String? readerId,
  }) => _mutate((current) {
    final result = LoanService(
      current,
      movementService: _movement(current),
    ).createLoan(
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
  });

  Future<ActionResult> returnLoan({
    required String loanId,
    bool confirmedInside = false,
    bool administrativeCorrection = false,
    String notes = '',
  }) => _mutate((current) {
    final result = LoanService(
      current,
      movementService: _movement(current),
    ).returnLoan(
      loanId: loanId,
      returnedAt: DateTime.now(),
      confirmedInside: confirmedInside,
      administrativeCorrection: administrativeCorrection,
      notes: notes,
    );
    return ActionResult(success: result.success, message: result.message);
  });

  Future<ActionResult> markLoanPendingVerification(String loanId) =>
      _mutate((current) {
        final result = LoanService(
          current,
          movementService: _movement(current),
        ).markPendingVerification(loanId);
        return ActionResult(success: result.success, message: result.message);
      });

  Future<ActionResult> createSupplierDelivery({
    required String supplierId,
    required List<String> assetIds,
    DateTime? dueAt,
    String reason = '',
    String notes = '',
    String? accessId,
    String? readerId,
    EventOrigin origin = EventOrigin.manual,
  }) => _mutate((current) {
    final result = SupplierService(
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
  });

  Future<ActionResult> deliverSupplierOperation(String operationId) =>
      _mutate((current) {
        final result = SupplierService(
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
      });

  Future<ActionResult> receiveSupplierAssets({
    required String operationId,
    required List<String> assetIds,
    String notes = '',
    String? accessId,
    String? readerId,
    EventOrigin origin = EventOrigin.manual,
  }) => _mutate((current) {
    final result = SupplierService(
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
  });

  Future<ActionResult> receiveNewSupplierAsset({
    required String operationId,
    required String code,
    required String name,
    required String categoryId,
    required String rfidEpc,
    String description = '',
    String notes = '',
  }) => _mutate((current) {
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
    final result = SupplierService(
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
  });

  Future<ActionResult> completeSupplierOperation(
    String operationId, {
    String notes = '',
  }) => _mutate((current) {
    final result = SupplierService(
      current,
      movementService: _movement(current),
    ).completeWithPending(operationId: operationId, notes: notes);
    return ActionResult(success: result.success, message: result.message);
  });

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
  }) => _simulateRead(
    assetId: assetId,
    accessId: accessId,
    readerId: readerId,
  );

  Future<ActionResult> simulateRepeatedRead({
    required String assetId,
    required String accessId,
    required String readerId,
    bool inbound = true,
  }) => _mutate((current) {
    final asset = current.assetById(assetId);
    if (asset == null) return ActionResult.fail('No se encontró el activo.');
    final processor = RfidEventProcessor(
      current,
      movementService: _movement(current),
    );
    final timestamp = DateTime.now();
    processor.process(
      RfidEvent(
        epc: asset.rfidEpc,
        readerId: readerId,
        accessId: accessId,
        timestamp: timestamp,
        directionHint: inbound
            ? RfidDirectionHint.inbound
            : RfidDirectionHint.outbound,
      ),
      origin: EventOrigin.simulator,
    );
    final repeated = processor.process(
      RfidEvent(
        epc: asset.rfidEpc,
        readerId: readerId,
        accessId: accessId,
        timestamp: timestamp.add(const Duration(seconds: 1)),
        directionHint: inbound
            ? RfidDirectionHint.inbound
            : RfidDirectionHint.outbound,
      ),
      origin: EventOrigin.simulator,
    );
    return ActionResult(
      success: repeated.duplicate,
      message: repeated.duplicate
          ? '${asset.code}: la segunda lectura fue ignorada. Solo se generó un '
                'movimiento.'
          : '${asset.code}: ${repeated.message}',
    );
  });

  Future<ActionResult> _simulateRead({
    required String assetId,
    required String accessId,
    required String readerId,
    RfidDirectionHint? direction,
  }) => _mutate((current) {
    final asset = current.assetById(assetId);
    if (asset == null) return ActionResult.fail('No se encontró el activo.');
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
  });

  Future<ActionResult> resolveAlert(String alertId) => _mutate((current) {
    final index = current.alerts.indexWhere((alert) => alert.id == alertId);
    if (index < 0) return ActionResult.fail('No se encontró la alerta.');
    current.alerts[index] = current.alerts[index].copyWith(
      resolvedAt: DateTime.now(),
    );
    return ActionResult.ok('Alerta marcada como resuelta.');
  });

  Future<ActionResult> resolvePendingEvent(
    String eventId, {
    required bool approve,
    String notes = '',
  }) => _mutate((current) {
    final result = _movement(current).resolvePendingEvent(
      eventId,
      approve: approve,
      notes: notes,
    );
    return ActionResult(success: result.success, message: result.message);
  });

  Future<ActionResult> resetDemo() async {
    final repository = ref.read(appRepositoryProvider);
    try {
      await repository.clear();
      final seeded = DemoSeed.buildState();
      _alerts.rebuild(seeded);
      await repository.save(seeded);
      state = AsyncData(seeded);
      return ActionResult.ok(
        'Datos de demostración restablecidos. Se crearon 50 activos.',
      );
    } catch (error) {
      return ActionResult.fail(
        'No se pudieron restablecer los datos de demostración: $error',
      );
    }
  }
}
