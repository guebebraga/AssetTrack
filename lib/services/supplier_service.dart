import '../core/utils/ids.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import 'inventory_service.dart';
import 'movement_service.dart';

class SupplierOperationResult {
  const SupplierOperationResult({
    required this.success,
    required this.message,
    this.operation,
  });

  final bool success;
  final String message;
  final SupplierOperation? operation;
}

class SupplierService {
  SupplierService(this.state, {required this.movementService});

  final AppState state;
  final MovementService movementService;
  final InventoryService _inventory = const InventoryService();

  SupplierOperationResult createDelivery({
    required String supplierId,
    required List<String> assetIds,
    required DateTime deliveredAt,
    DateTime? dueAt,
    String reason = '',
    String notes = '',
    String? accessId,
    String? readerId,
    bool deliverNow = true,
    EventOrigin origin = EventOrigin.manual,
  }) {
    final supplier = state.supplierById(supplierId);
    if (supplier == null) {
      return const SupplierOperationResult(
        success: false,
        message: 'No se encontró el proveedor.',
      );
    }
    if (!supplier.active) {
      return const SupplierOperationResult(
        success: false,
        message: 'El proveedor está inactivo.',
      );
    }
    final uniqueIds = assetIds.toSet().toList();
    if (uniqueIds.isEmpty) {
      return const SupplierOperationResult(
        success: false,
        message: 'Seleccioná al menos un activo.',
      );
    }
    for (final assetId in uniqueIds) {
      final asset = state.assetById(assetId);
      if (asset == null) {
        return const SupplierOperationResult(
          success: false,
          message: 'Uno de los activos seleccionados no existe.',
        );
      }
      if (deliverNow) {
        final error = _inventory.validateTransition(
          asset,
          MovementType.supplierDelivery,
        );
        if (error != null) {
          return SupplierOperationResult(
            success: false,
            message: '${asset.code}: $error',
          );
        }
      }
    }

    final operationId = newId('OPR');
    if (deliverNow) {
      for (final assetId in uniqueIds) {
        final result = movementService.record(
          assetId: assetId,
          type: MovementType.supplierDelivery,
          timestamp: deliveredAt,
          origin: origin,
          accessId: accessId,
          readerId: readerId,
          supplierId: supplierId,
          expectedReturnAt: dueAt,
          reason: reason,
          notes: notes,
          relatedOperationId: operationId,
          checkDuplicate: false,
        );
        if (!result.success) {
          return SupplierOperationResult(
            success: false,
            message: result.message,
            operation: state.operationById(operationId),
          );
        }
      }
    }

    final operation = SupplierOperation(
      id: operationId,
      supplierId: supplierId,
      deliveredAssetIds: uniqueIds,
      receivedAssetIds: const [],
      createdAt: deliveredAt,
      deliveredAt: deliverNow ? deliveredAt : null,
      dueAt: dueAt,
      reason: reason,
      notes: notes,
      status: deliverNow
          ? SupplierOperationStatus.delivered
          : SupplierOperationStatus.prepared,
    );
    state.supplierOperations.add(operation);

    return SupplierOperationResult(
      success: true,
      message: deliverNow
          ? 'Entrega al proveedor registrada con ${uniqueIds.length} activo(s).'
          : 'Operación preparada. Los activos todavía no salieron.',
      operation: operation,
    );
  }

  SupplierOperationResult deliverOperation({
    required String operationId,
    required DateTime deliveredAt,
    String? accessId,
    String? readerId,
    String notes = '',
  }) {
    final operation = state.operationById(operationId);
    if (operation == null) {
      return const SupplierOperationResult(
        success: false,
        message: 'No se encontró la operación.',
      );
    }
    if (operation.deliveredAt != null) {
      return const SupplierOperationResult(
        success: false,
        message: 'La operación ya fue entregada.',
      );
    }
    for (final assetId in operation.deliveredAssetIds) {
      final asset = state.assetById(assetId);
      if (asset == null) {
        return const SupplierOperationResult(
          success: false,
          message: 'Uno de los activos de la operación no existe.',
        );
      }
      final error = _inventory.validateTransition(
        asset,
        MovementType.supplierDelivery,
      );
      if (error != null) {
        return SupplierOperationResult(
          success: false,
          message: '${asset.code}: $error',
        );
      }
    }
    for (final assetId in operation.deliveredAssetIds) {
      final result = movementService.record(
        assetId: assetId,
        type: MovementType.supplierDelivery,
        timestamp: deliveredAt,
        origin: EventOrigin.manual,
        accessId: accessId,
        readerId: readerId,
        supplierId: operation.supplierId,
        expectedReturnAt: operation.dueAt,
        reason: operation.reason,
        notes: notes,
        relatedOperationId: operation.id,
        checkDuplicate: false,
      );
      if (!result.success) {
        return SupplierOperationResult(
          success: false,
          message: result.message,
          operation: operation,
        );
      }
    }
    final updated = operation.copyWith(
      delivered: true,
      deliveredAt: deliveredAt,
      status: SupplierOperationStatus.delivered,
      notes: notes.isEmpty ? operation.notes : notes,
    );
    final index = state.supplierOperations.indexWhere(
      (item) => item.id == operationId,
    );
    state.supplierOperations[index] = updated;
    return SupplierOperationResult(
      success: true,
      message: 'Salida de la operación registrada.',
      operation: updated,
    );
  }

  SupplierOperationResult receiveAssets({
    required String operationId,
    required List<String> receivedAssetIds,
    required DateTime receivedAt,
    String notes = '',
    String? accessId,
    String? readerId,
    EventOrigin origin = EventOrigin.manual,
  }) {
    final operation = state.operationById(operationId);
    if (operation == null) {
      return const SupplierOperationResult(
        success: false,
        message: 'No se encontró la operación.',
      );
    }
    if (operation.status == SupplierOperationStatus.completed) {
      return const SupplierOperationResult(
        success: false,
        message: 'La operación ya está completada.',
      );
    }
    if (operation.deliveredAt == null) {
      return const SupplierOperationResult(
        success: false,
        message: 'La operación todavía no fue entregada al proveedor.',
      );
    }
    final unique = receivedAssetIds
        .where((id) => !operation.receivedAssetIds.contains(id))
        .toSet()
        .toList();
    if (unique.isEmpty) {
      return const SupplierOperationResult(
        success: false,
        message: 'No se seleccionaron activos nuevos para recibir.',
      );
    }
    for (final assetId in unique) {
      final asset = state.assetById(assetId);
      if (asset == null) {
        return const SupplierOperationResult(
          success: false,
          message: 'Uno de los activos recibidos no existe en el inventario.',
        );
      }
      if (asset.location == AssetLocation.inside &&
          asset.situation != AssetSituation.atSupplier) {
        return SupplierOperationResult(
          success: false,
          message:
              '${asset.code} ya figura dentro y no puede recibirse nuevamente. '
              'Usá una corrección de inventario si corresponde.',
        );
      }
    }

    for (final assetId in unique) {
      final isExchange = !operation.deliveredAssetIds.contains(assetId);
      final type = isExchange
          ? MovementType.unitExchange
          : MovementType.supplierReceipt;
      final result = movementService.record(
        assetId: assetId,
        type: type,
        timestamp: receivedAt,
        origin: origin,
        accessId: accessId,
        readerId: readerId,
        supplierId: operation.supplierId,
        reason: operation.reason,
        notes: isExchange
            ? 'Unidad recibida en intercambio, distinta a las entregadas.'
            : notes,
        relatedOperationId: operation.id,
        bypassValidation: isExchange,
        checkDuplicate: false,
      );
      if (!result.success) {
        return SupplierOperationResult(
          success: false,
          message: result.message,
          operation: operation,
        );
      }
    }

    final received = [...operation.receivedAssetIds, ...unique];
    final pending = operation.deliveredAssetIds
        .where((id) => !received.contains(id))
        .toList();
    final status = pending.isEmpty
        ? SupplierOperationStatus.completed
        : SupplierOperationStatus.partiallyReceived;
    final updated = operation.copyWith(
      receivedAssetIds: received,
      status: status,
      receivedAt: receivedAt,
      notes: notes.isEmpty ? operation.notes : notes,
    );
    final index = state.supplierOperations.indexWhere(
      (item) => item.id == operationId,
    );
    state.supplierOperations[index] = updated;

    return SupplierOperationResult(
      success: true,
      message: pending.isEmpty
          ? 'Operación completada. Todas las unidades entregadas fueron recibidas.'
          : 'Recepción parcial registrada. Quedan ${pending.length} unidad(es) '
                'entregadas pendientes de retorno.',
      operation: updated,
    );
  }

  SupplierOperationResult completeWithPending({
    required String operationId,
    String notes = '',
    DateTime? closedAt,
  }) {
    final operation = state.operationById(operationId);
    if (operation == null) {
      return const SupplierOperationResult(
        success: false,
        message: 'No se encontró la operación.',
      );
    }
    final updated = operation.copyWith(
      status: SupplierOperationStatus.completed,
      receivedAt: closedAt ?? DateTime.now(),
      notes: notes.isEmpty
          ? 'Operación cerrada explícitamente con unidades no retornadas.'
          : notes,
    );
    final index = state.supplierOperations.indexWhere(
      (item) => item.id == operationId,
    );
    state.supplierOperations[index] = updated;
    return SupplierOperationResult(
      success: true,
      message:
          'Operación cerrada. Las unidades no recibidas mantienen su trazabilidad.',
      operation: updated,
    );
  }
}
