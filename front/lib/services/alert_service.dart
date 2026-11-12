import '../domain/enums.dart';
import '../domain/models.dart';

class AlertService {
  const AlertService();

  List<Alert> rebuild(AppState state, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final previous = {for (final alert in state.alerts) alert.id: alert};
    final generated = <String, Alert>{};

    void add({
      required AlertType type,
      required AlertSeverity severity,
      required String title,
      required String message,
      String? assetId,
      String? operationId,
    }) {
      final id = 'alt-${type.name}-${assetId ?? operationId ?? 'general'}';
      final existing = previous[id];
      generated[id] = Alert(
        id: id,
        type: type,
        severity: severity,
        title: title,
        message: message,
        createdAt: existing?.createdAt ?? reference,
        assetId: assetId,
        simulated: true,
        resolvedAt: existing?.resolvedAt,
      );
    }

    final threshold = Duration(hours: state.settings.outsideThresholdHours);
    for (final asset in state.assets) {
      if (asset.location != AssetLocation.outside) continue;
      if (asset.situation == AssetSituation.onLoan ||
          asset.situation == AssetSituation.atSupplier) {
        continue;
      }
      final since = asset.lastExitAt;
      if (since == null) continue;
      final elapsed = reference.difference(since);
      if (elapsed <= threshold) continue;
      add(
        type: AlertType.outsideTooLong,
        severity: elapsed > threshold * 2
            ? AlertSeverity.critical
            : AlertSeverity.warning,
        title: 'Activo fuera de las instalaciones',
        message:
            '${asset.code} lleva ${elapsed.inDays} día(s) fuera, superando el '
            'umbral de ${state.settings.outsideThresholdHours} h.',
        assetId: asset.id,
      );
    }

    for (final loan in state.loans) {
      if (loan.effectiveStatus(reference) != LoanStatus.overdue) continue;
      final due = loan.dueAt;
      final late = due == null ? 0 : reference.difference(due).inHours;
      final asset = state.assetById(loan.assetId);
      add(
        type: AlertType.loanOverdue,
        severity: late > 48 ? AlertSeverity.critical : AlertSeverity.warning,
        title: 'Préstamo vencido',
        message:
            '${asset?.code ?? loan.assetId} fue prestado a ${loan.borrower} y '
            'tenía que volver el ${_dateLabel(due)}.',
        assetId: loan.assetId,
      );
    }

    for (final operation in state.supplierOperations) {
      if (operation.status == SupplierOperationStatus.completed) continue;
      final pending = operation.pendingAssetIds;
      if (pending.isEmpty) continue;
      final supplier = state.supplierById(operation.supplierId);
      if (operation.status == SupplierOperationStatus.partiallyReceived) {
        add(
          type: AlertType.incompleteReturn,
          severity: AlertSeverity.warning,
          title: 'Devolución incompleta',
          message:
              'La operación con ${supplier?.name ?? 'el proveedor'} tiene '
              '${pending.length} unidad(es) sin retorno registrado.',
          operationId: operation.id,
        );
        continue;
      }
      if (operation.deliveredAt == null) continue;
      final due = operation.dueAt;
      final overdue = due != null && due.isBefore(reference);
      final longPending =
          reference.difference(operation.deliveredAt!) > threshold * 2;
      if (!overdue && !longPending) continue;
      add(
        type: AlertType.supplierPending,
        severity: overdue && due.difference(operation.deliveredAt!).inDays > 2
            ? AlertSeverity.critical
            : AlertSeverity.warning,
        title: 'Entrega a proveedor pendiente',
        message:
            '${pending.length} unidad(es) entregadas a '
            '${supplier?.name ?? 'proveedor'} todavía no fueron recibidas. '
            '${due == null ? '' : 'Retorno previsto: ${_dateLabel(due)}.'}',
        operationId: operation.id,
      );
    }

    for (final movement in state.movements) {
      if (movement.status != MovementStatus.pendingReview) continue;
      final asset = state.assetById(movement.assetId);
      if (movement.type == MovementType.ambiguousRead) {
        add(
          type: AlertType.ambiguousRead,
          severity: AlertSeverity.warning,
          title: 'Lectura ambigua pendiente',
          message:
              '${asset?.code ?? movement.assetId}: lectura sin sentido de '
              'movimiento confirmado. Requiere revisión manual.',
          assetId: movement.assetId,
          operationId: movement.id,
        );
      } else {
        add(
          type: AlertType.incompatibleMovement,
          severity: AlertSeverity.warning,
          title: 'Movimiento incompatible',
          message:
              '${asset?.code ?? movement.assetId}: '
              '${movement.alertMessage ?? 'movimiento pendiente de revisión.'}',
          assetId: movement.assetId,
          operationId: movement.id,
        );
      }
    }

    final detectionThreshold = Duration(
      hours: state.settings.alertDetectionHours,
    );
    for (final asset in state.assets) {
      if (asset.location != AssetLocation.inside) continue;
      final detection = asset.lastDetectionAt;
      if (detection == null) continue;
      final elapsed = reference.difference(detection);
      if (elapsed <= detectionThreshold) continue;
      add(
        type: AlertType.noRecentDetection,
        severity: AlertSeverity.info,
        title: 'Sin detecciones recientes',
        message:
            '${asset.code} no registra lecturas desde '
            '${_dateLabel(detection)}.',
        assetId: asset.id,
      );
    }

    final result = generated.values.toList()
      ..sort((a, b) {
        final severity = b.severity.index.compareTo(a.severity.index);
        if (severity != 0) return severity;
        return b.createdAt.compareTo(a.createdAt);
      });
    state.alerts = result;
    return result;
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'sin fecha';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }
}
