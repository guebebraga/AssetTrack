import '../domain/enums.dart';
import '../domain/models.dart';

class DashboardStats {
  const DashboardStats({
    required this.total,
    required this.inside,
    required this.outside,
    required this.unknown,
    required this.loans,
    required this.atSupplier,
    required this.todayMovements,
    required this.openAlerts,
    required this.criticalAlerts,
    required this.pendingReview,
    required this.overdueLoans,
    required this.pendingReturns,
    required this.maintenance,
  });

  final int total;
  final int inside;
  final int outside;
  final int unknown;
  final int loans;
  final int atSupplier;
  final int todayMovements;
  final int openAlerts;
  final int criticalAlerts;
  final int pendingReview;
  final int overdueLoans;
  final int pendingReturns;
  final int maintenance;

  double get insideRatio => total == 0 ? 0 : inside / total;
  double get outsideRatio => total == 0 ? 0 : outside / total;
}

class InventoryService {
  const InventoryService();

  DashboardStats stats(AppState state, DateTime now) {
    final todayMovements = state.movements.where((movement) {
      return movement.timestamp.year == now.year &&
          movement.timestamp.month == now.month &&
          movement.timestamp.day == now.day;
    }).length;

    return DashboardStats(
      total: state.assets.length,
      inside: state.assets
          .where((asset) => asset.location == AssetLocation.inside)
          .length,
      outside: state.assets
          .where((asset) => asset.location == AssetLocation.outside)
          .length,
      unknown: state.assets
          .where(
            (asset) =>
                asset.location == AssetLocation.unknown ||
                asset.location == AssetLocation.pendingVerification,
          )
          .length,
      loans: state.assets
          .where((asset) => asset.situation == AssetSituation.onLoan)
          .length,
      atSupplier: state.assets
          .where((asset) => asset.situation == AssetSituation.atSupplier)
          .length,
      todayMovements: todayMovements,
      openAlerts: state.alerts.where((alert) => alert.isOpen).length,
      criticalAlerts: state.alerts
          .where((alert) => alert.isOpen && alert.severity == AlertSeverity.critical)
          .length,
      pendingReview: state.movements
          .where((movement) => movement.status == MovementStatus.pendingReview)
          .length,
      overdueLoans: state.loans
          .where((loan) => loan.effectiveStatus(now) == LoanStatus.overdue)
          .length,
      pendingReturns: state.assets
          .where((asset) => asset.situation == AssetSituation.pendingReturn)
          .length,
      maintenance: state.assets
          .where((asset) => asset.situation == AssetSituation.maintenance)
          .length,
    );
  }

  String? contradictionFor(Asset asset) {
    if (asset.location == AssetLocation.inside &&
        (asset.situation == AssetSituation.onLoan ||
            asset.situation == AssetSituation.atSupplier)) {
      return 'Un activo prestado o en poder de un proveedor no puede figurar '
          'dentro de las instalaciones sin una corrección explícita.';
    }
    if (asset.location == AssetLocation.inside &&
        asset.situation == AssetSituation.pendingReturn) {
      return 'Un activo pendiente de devolución normalmente se encuentra fuera '
          'de las instalaciones.';
    }
    return null;
  }

  String? validateTransition(Asset asset, MovementType type) {
    final inside = asset.location == AssetLocation.inside;
    switch (type) {
      case MovementType.entry:
        if (inside) return 'El activo ya figura dentro de las instalaciones.';
        if (asset.situation == AssetSituation.onLoan) {
          return 'El activo tiene un préstamo abierto. Registrá la devolución '
              'del préstamo en lugar de una entrada genérica.';
        }
        if (asset.situation == AssetSituation.atSupplier) {
          return 'El activo está en poder de un proveedor. Registrá la '
              'recepción de proveedor correspondiente.';
        }
      case MovementType.exit:
        if (!inside) return 'El activo no figura dentro de las instalaciones.';
      case MovementType.loan:
        if (!inside) return 'Solo se pueden prestar activos que están dentro.';
        if (asset.situation == AssetSituation.onLoan) {
          return 'El activo ya tiene un préstamo activo.';
        }
        if (asset.situation == AssetSituation.atSupplier) {
          return 'El activo está en poder de un proveedor.';
        }
      case MovementType.loanReturn:
        if (inside) return 'El activo ya figura dentro de las instalaciones.';
      case MovementType.supplierDelivery:
      case MovementType.sendForRefill:
        if (!inside) return 'La entrega requiere que el activo esté dentro.';
        if (asset.situation == AssetSituation.atSupplier) {
          return 'El activo ya figura en poder de un proveedor.';
        }
      case MovementType.supplierReceipt:
      case MovementType.receiveAfterRefill:
      case MovementType.unitExchange:
        if (inside) return 'El activo ya figura dentro de las instalaciones.';
      case MovementType.adminAdjustment:
      case MovementType.inventoryCorrection:
      case MovementType.ambiguousRead:
        return null;
    }
    return null;
  }
}
