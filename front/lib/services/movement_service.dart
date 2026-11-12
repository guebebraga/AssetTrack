import '../core/utils/ids.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import 'inventory_service.dart';

class MovementResult {
  const MovementResult({
    required this.success,
    required this.message,
    this.event,
    this.duplicate = false,
    this.asset,
  });

  final bool success;
  final String message;
  final MovementEvent? event;
  final bool duplicate;
  final Asset? asset;

  static MovementResult failure(String message, {Asset? asset}) =>
      MovementResult(success: false, message: message, asset: asset);
}

class MovementService {
  MovementService(this.state, {this.dedupeWindowSeconds = 30});

  final AppState state;
  final InventoryService _inventory = const InventoryService();
  final int dedupeWindowSeconds;

  void _replaceAsset(Asset updated) {
    final index = state.assets.indexWhere((asset) => asset.id == updated.id);
    if (index >= 0) state.assets[index] = updated;
  }

  MovementEvent _append(MovementEvent event) {
    state.movements.add(event);
    return event;
  }

  MovementEvent? _lastConfirmed(String assetId, MovementType type) {
    MovementEvent? latest;
    for (final movement in state.movements) {
      if (movement.assetId != assetId ||
          movement.type != type ||
          movement.status != MovementStatus.confirmed) {
        continue;
      }
      if (latest == null || movement.timestamp.isAfter(latest.timestamp)) {
        latest = movement;
      }
    }
    return latest;
  }

  bool _isDuplicate(
    Asset asset,
    MovementType type,
    DateTime timestamp,
    String? accessId, {
    String? roomId,
  }) {
    final last = _lastConfirmed(asset.id, type);
    if (last == null) return false;
    final difference = timestamp.difference(last.timestamp).abs();
    if (difference.inSeconds > dedupeWindowSeconds) return false;
    if (accessId != null &&
        last.accessId != null &&
        last.accessId != accessId) {
      return false;
    }
    if (roomId != null && last.roomId != null && last.roomId != roomId) {
      return false;
    }
    return true;
  }

  MovementResult record({
    required String assetId,
    required MovementType type,
    required DateTime timestamp,
    required EventOrigin origin,
    MovementStatus status = MovementStatus.confirmed,
    String? accessId,
    String? readerId,
    String? roomId,
    String? responsible,
    String? supplierId,
    DateTime? expectedReturnAt,
    String reason = '',
    String notes = '',
    String? relatedOperationId,
    String? alertMessage,
    bool bypassValidation = false,
    bool checkDuplicate = true,
  }) {
    final asset = state.assetById(assetId);
    if (asset == null) {
      return MovementResult.failure('No se encontró el activo indicado.');
    }

    if (checkDuplicate &&
        status == MovementStatus.confirmed &&
        (type == MovementType.entry ||
            type == MovementType.exit ||
            type.isRoomMovement) &&
        _isDuplicate(asset, type, timestamp, accessId, roomId: roomId)) {
      _replaceAsset(
        asset.copyWith(
          lastDetectionAt: timestamp,
          lastAccessId: accessId,
          lastReaderId: readerId,
          lastRoomDetectionAt: roomId == null ? null : timestamp,
        ),
      );
      return MovementResult(
        success: false,
        duplicate: true,
        message:
            'Lectura repetida dentro de la ventana de agrupación. No se generó '
            'un movimiento nuevo.',
        asset: state.assetById(assetId),
      );
    }

    if (status == MovementStatus.confirmed && !bypassValidation) {
      final error = _inventory.validateTransition(asset, type, roomId: roomId);
      if (error != null) {
        final event = _append(
          MovementEvent(
            id: newId('MOV'),
            assetId: assetId,
            type: type,
            timestamp: timestamp,
            origin: origin,
            status: MovementStatus.pendingReview,
            accessId: accessId,
            readerId: readerId,
            roomId: roomId,
            responsible: responsible,
            supplierId: supplierId,
            reason: reason,
            notes: notes,
            relatedOperationId: relatedOperationId,
            alertMessage: error,
          ),
        );
        return MovementResult(
          success: false,
          message: error,
          event: event,
          asset: asset,
        );
      }
    }

    if (status == MovementStatus.pendingReview) {
      final event = _append(
        MovementEvent(
          id: newId('MOV'),
          assetId: assetId,
          type: type,
          timestamp: timestamp,
          origin: origin,
          status: MovementStatus.pendingReview,
          accessId: accessId,
          readerId: readerId,
          roomId: roomId,
          responsible: responsible,
          supplierId: supplierId,
          reason: reason,
          notes: notes,
          relatedOperationId: relatedOperationId,
          alertMessage:
              alertMessage ?? 'Evento pendiente de verificación manual.',
        ),
      );
      if (type != MovementType.ambiguousRead) {
        _replaceAsset(
          asset.copyWith(
            lastDetectionAt: timestamp,
            lastAccessId: accessId,
            lastReaderId: readerId,
            lastRoomDetectionAt: roomId == null ? null : timestamp,
          ),
        );
      }
      return MovementResult(
        success: false,
        message: 'Evento registrado como pendiente de revisión.',
        event: event,
        asset: state.assetById(assetId),
      );
    }

    var updated = asset.copyWith(
      lastDetectionAt: timestamp,
      lastAccessId: accessId,
      lastReaderId: readerId,
    );

    switch (type) {
      case MovementType.entry:
        var situation = updated.situation;
        if (situation == AssetSituation.pendingReturn) {
          situation = AssetSituation.available;
        }
        updated = updated.copyWith(
          location: AssetLocation.inside,
          situation: situation,
          lastEntryAt: timestamp,
          lastMovementAt: timestamp,
          clearRoom: true,
        );
      case MovementType.loan:
        updated = updated.copyWith(
          location: AssetLocation.outside,
          situation: AssetSituation.onLoan,
          lastExitAt: timestamp,
          lastMovementAt: timestamp,
          responsible: responsible,
          expectedReturnAt: expectedReturnAt,
          clearSupplier: true,
          clearRoom: true,
        );
      case MovementType.loanReturn:
        updated = updated.copyWith(
          location: AssetLocation.inside,
          situation: AssetSituation.available,
          lastEntryAt: timestamp,
          lastMovementAt: timestamp,
          clearResponsible: true,
          clearExpectedReturn: true,
          clearRoom: true,
        );
      case MovementType.supplierDelivery:
      case MovementType.sendForRefill:
        updated = updated.copyWith(
          location: AssetLocation.outside,
          situation: AssetSituation.atSupplier,
          lastExitAt: timestamp,
          lastMovementAt: timestamp,
          supplierId: supplierId,
          expectedReturnAt: expectedReturnAt,
          clearResponsible: true,
          clearRoom: true,
        );
      case MovementType.supplierReceipt:
      case MovementType.receiveAfterRefill:
      case MovementType.unitExchange:
        updated = updated.copyWith(
          location: AssetLocation.inside,
          situation: AssetSituation.available,
          lastEntryAt: timestamp,
          lastMovementAt: timestamp,
          clearSupplier: true,
          clearExpectedReturn: true,
          clearRoom: true,
        );
      case MovementType.exit:
        updated = updated.copyWith(
          location: AssetLocation.outside,
          situation: updated.situation == AssetSituation.available
              ? AssetSituation.inUse
              : updated.situation,
          lastExitAt: timestamp,
          lastMovementAt: timestamp,
          clearRoom: true,
        );
      case MovementType.roomEntry:
        updated = updated.copyWith(
          location: AssetLocation.inside,
          roomId: roomId,
          lastRoomEntryAt: timestamp,
          lastRoomDetectionAt: timestamp,
          lastMovementAt: timestamp,
        );
      case MovementType.roomExit:
        updated = updated.copyWith(
          roomId: roomId,
          clearRoom: true,
          lastRoomExitAt: timestamp,
          lastRoomDetectionAt: timestamp,
          lastMovementAt: timestamp,
        );
      case MovementType.roomTransfer:
        updated = updated.copyWith(
          location: AssetLocation.inside,
          roomId: roomId,
          lastRoomEntryAt: timestamp,
          lastRoomExitAt: timestamp,
          lastRoomDetectionAt: timestamp,
          lastMovementAt: timestamp,
        );
      case MovementType.adminAdjustment:
      case MovementType.inventoryCorrection:
        updated = updated.copyWith(lastMovementAt: timestamp, roomId: roomId);
      case MovementType.ambiguousRead:
        break;
    }

    _replaceAsset(updated);
    final event = _append(
      MovementEvent(
        id: newId('MOV'),
        assetId: assetId,
        type: type,
        timestamp: timestamp,
        origin: origin,
        status: MovementStatus.confirmed,
        accessId: accessId,
        readerId: readerId,
        roomId: roomId,
        responsible: responsible,
        supplierId: supplierId,
        reason: reason,
        notes: notes,
        relatedOperationId: relatedOperationId,
        alertMessage: alertMessage,
      ),
    );

    return MovementResult(
      success: true,
      message: 'Movimiento registrado correctamente.',
      event: event,
      asset: state.assetById(assetId),
    );
  }

  MovementResult registerDetection({
    required String assetId,
    required DateTime timestamp,
    String? accessId,
    String? readerId,
    String? roomId,
  }) {
    final asset = state.assetById(assetId);
    if (asset == null) {
      return MovementResult.failure('No se encontró el activo indicado.');
    }
    final lastDetection = asset.lastDetectionAt;
    final isRepeated =
        lastDetection != null &&
        timestamp.difference(lastDetection).abs().inSeconds <=
            dedupeWindowSeconds;
    _replaceAsset(
      asset.copyWith(
        lastDetectionAt: timestamp,
        lastAccessId: accessId,
        lastReaderId: readerId,
        lastRoomDetectionAt: roomId == null ? null : timestamp,
      ),
    );
    if (isRepeated) {
      return MovementResult(
        success: false,
        duplicate: true,
        message:
            'Lectura repetida. Se actualizó la última detección sin crear un '
            'movimiento.',
        asset: state.assetById(assetId),
      );
    }
    return MovementResult(
      success: true,
      message: 'Detección registrada sin movimiento confirmado.',
      asset: state.assetById(assetId),
    );
  }

  MovementResult resolvePendingEvent(
    String eventId, {
    required bool approve,
    String? notes,
    DateTime? timestamp,
  }) {
    final index = state.movements.indexWhere((event) => event.id == eventId);
    if (index < 0) {
      return MovementResult.failure('No se encontró el evento.');
    }
    final event = state.movements[index];
    if (event.status != MovementStatus.pendingReview) {
      return MovementResult.failure('El evento ya fue procesado.');
    }
    final moment = timestamp ?? DateTime.now();
    if (!approve) {
      state.movements[index] = event.copyWith(
        status: MovementStatus.rejected,
        notes: notes ?? 'Evento rechazado durante la revisión.',
      );
      return MovementResult(
        success: true,
        message: 'Evento rechazado. El inventario no se modificó.',
        event: state.movements[index],
      );
    }
    final previous = state.movements[index];
    state.movements.removeAt(index);
    final result = record(
      assetId: event.assetId,
      type: event.type == MovementType.ambiguousRead
          ? MovementType.adminAdjustment
          : event.type,
      timestamp: moment,
      origin: EventOrigin.correction,
      accessId: event.accessId,
      readerId: event.readerId,
      roomId: event.roomId,
      responsible: event.responsible,
      supplierId: event.supplierId,
      reason: event.reason,
      notes: notes ?? 'Evento ambiguo aprobado manualmente.',
      bypassValidation: true,
      checkDuplicate: false,
    );
    if (!result.success) {
      state.movements.insert(index, previous);
      return result;
    }
    return MovementResult(
      success: true,
      message: 'Evento aprobado y aplicado al inventario.',
      event: result.event,
      asset: result.asset,
    );
  }
}
