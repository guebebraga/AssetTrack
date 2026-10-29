import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../domain/enums.dart';
import '../domain/models.dart';
import '../application/app_controller.dart';

void showResultMessage(BuildContext context, ActionResult result) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: result.success ? AppColors.navyDark : AppColors.danger,
        content: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(result.message)),
          ],
        ),
      ),
    );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child, this.maxWidth = 980});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 9 : 11,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyDark, AppColors.navyMid],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2206152F),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'DEMO — DATOS SIMULADOS — RFID NO CONECTADO',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ),
          const Spacer(),
          Icon(
            Icons.sensors_off_rounded,
            size: compact ? 15 : 17,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}

class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 40, this.light = false});

  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: light
              ? [Colors.white, const Color(0xFFDDE8FF)]
              : [AppColors.navyMid, AppColors.navyDark],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.22),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(
        Icons.track_changes_rounded,
        color: light ? AppColors.navy : Colors.white,
        size: size * 0.58,
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
    final card = Card(child: content);
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: card,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.background,
    this.icon,
    this.compact = false,
  });

  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 11 : 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

Color locationColor(AssetLocation location) => switch (location) {
  AssetLocation.inside => AppColors.success,
  AssetLocation.outside => AppColors.warning,
  AssetLocation.unknown => AppColors.muted,
  AssetLocation.pendingVerification => AppColors.blue,
};

Color situationColor(AssetSituation situation) => switch (situation) {
  AssetSituation.available => AppColors.success,
  AssetSituation.inUse => AppColors.blue,
  AssetSituation.onLoan => AppColors.purple,
  AssetSituation.atSupplier => AppColors.warning,
  AssetSituation.pendingReturn => AppColors.warning,
  AssetSituation.maintenance => AppColors.muted,
};

Color severityColor(AlertSeverity severity) => switch (severity) {
  AlertSeverity.info => AppColors.blue,
  AlertSeverity.warning => AppColors.warning,
  AlertSeverity.critical => AppColors.danger,
};

Color operationColor(SupplierOperationStatus status) => switch (status) {
  SupplierOperationStatus.prepared => AppColors.blue,
  SupplierOperationStatus.delivered => AppColors.warning,
  SupplierOperationStatus.partiallyReceived => AppColors.purple,
  SupplierOperationStatus.completed => AppColors.success,
  SupplierOperationStatus.pendingReview => AppColors.danger,
};

Color movementColor(MovementType type) => switch (type) {
  MovementType.entry ||
  MovementType.loanReturn ||
  MovementType.supplierReceipt ||
  MovementType.receiveAfterRefill => AppColors.success,
  MovementType.exit ||
  MovementType.loan ||
  MovementType.supplierDelivery ||
  MovementType.sendForRefill ||
  MovementType.unitExchange => AppColors.warning,
  MovementType.ambiguousRead => AppColors.danger,
  MovementType.adminAdjustment ||
  MovementType.inventoryCorrection => AppColors.purple,
};

IconData movementIcon(MovementType type) => switch (type) {
  MovementType.entry => Icons.login_rounded,
  MovementType.exit => Icons.logout_rounded,
  MovementType.loan => Icons.handshake_rounded,
  MovementType.loanReturn => Icons.assignment_return_rounded,
  MovementType.supplierDelivery => Icons.local_shipping_rounded,
  MovementType.supplierReceipt => Icons.inventory_rounded,
  MovementType.sendForRefill => Icons.propane_tank_rounded,
  MovementType.receiveAfterRefill => Icons.propane_tank_outlined,
  MovementType.unitExchange => Icons.swap_horiz_rounded,
  MovementType.adminAdjustment => Icons.tune_rounded,
  MovementType.ambiguousRead => Icons.help_outline_rounded,
  MovementType.inventoryCorrection => Icons.fact_check_rounded,
};

class LocationBadge extends StatelessWidget {
  const LocationBadge({super.key, required this.location, this.compact = false});

  final AssetLocation location;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = locationColor(location);
    return StatusPill(
      label: location.shortLabel,
      color: color,
      compact: compact,
      icon: switch (location) {
        AssetLocation.inside => Icons.home_work_rounded,
        AssetLocation.outside => Icons.north_east_rounded,
        AssetLocation.unknown => Icons.location_off_rounded,
        AssetLocation.pendingVerification => Icons.help_center_rounded,
      },
    );
  }
}

class SituationBadge extends StatelessWidget {
  const SituationBadge({super.key, required this.situation, this.compact = false});

  final AssetSituation situation;
  final bool compact;

  @override
  Widget build(BuildContext context) => StatusPill(
    label: situation.label,
    color: situationColor(situation),
    compact: compact,
  );
}

class SeverityBadge extends StatelessWidget {
  const SeverityBadge({super.key, required this.severity});

  final AlertSeverity severity;

  @override
  Widget build(BuildContext context) => StatusPill(
    label: severity.label,
    color: severityColor(severity),
    compact: true,
    icon: switch (severity) {
      AlertSeverity.info => Icons.info_outline_rounded,
      AlertSeverity.warning => Icons.warning_amber_rounded,
      AlertSeverity.critical => Icons.report_problem_rounded,
    },
  );
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 17),
                  ),
                  const Spacer(),
                  if (caption != null)
                    Flexible(
                      child: Text(
                        caption!,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.muted),
            const SizedBox(width: 9),
          ],
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.blue, size: 28),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 5),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class AssetListTile extends StatelessWidget {
  const AssetListTile({
    super.key,
    required this.asset,
    required this.categoryName,
    required this.onTap,
    this.trailing,
  });

  final Asset asset;
  final String categoryName;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = locationColor(asset.location);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                asset.categoryId == 'cat-o2'
                    ? Icons.propane_tank_rounded
                    : Icons.inventory_2_rounded,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        asset.code,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontSize: 13,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(width: 7),
                      LocationBadge(location: asset.location, compact: true),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    asset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$categoryName · ${asset.situation.label} · '
                    '${relativeTime(asset.lastMovementAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted,
                  size: 22,
                ),
          ],
        ),
      ),
    );
  }
}

class MovementTile extends StatelessWidget {
  const MovementTile({
    super.key,
    required this.movement,
    required this.assetCode,
    this.accessName,
    this.supplierName,
    this.onTap,
  });

  final MovementEvent movement;
  final String assetCode;
  final String? accessName;
  final String? supplierName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = movementColor(movement.type);
    final details = [
      assetCode,
      ?accessName,
      ?supplierName,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(movementIcon(movement.type), color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          movement.type.label,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontSize: 13),
                        ),
                      ),
                      if (movement.status != MovementStatus.confirmed)
                        StatusPill(
                          label: movement.status.label,
                          color: movement.status == MovementStatus.rejected
                              ? AppColors.danger
                              : AppColors.warning,
                          compact: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatDateTime(movement.timestamp)} · '
                    '${movement.origin.label}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.inside,
    required this.outside,
    this.size = 150,
  });

  final int inside;
  final int outside;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = inside + outside;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          inside: inside,
          outside: outside,
          total: total,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$total',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'activos',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.inside,
    required this.outside,
    required this.total,
  });

  final int inside;
  final int outside;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 9;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = size.width * 0.12;

    final background = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, background);
    if (total == 0) return;

    final insideSweep = (inside / total) * math.pi * 2;
    final outsideSweep = (outside / total) * math.pi * 2;
    const start = -math.pi / 2;
    final insidePaint = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final outsidePaint = Paint()
      ..color = AppColors.warning
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    if (inside > 0) {
      canvas.drawArc(
        rect,
        start,
        math.max(0.02, insideSweep - 0.04),
        false,
        insidePaint,
      );
    }
    if (outside > 0) {
      canvas.drawArc(
        rect,
        start + insideSweep,
        math.max(0.02, outsideSweep - 0.04),
        false,
        outsidePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.inside != inside || oldDelegate.outside != outside;
}

class WeeklyBars extends StatelessWidget {
  const WeeklyBars({super.key, required this.values, this.height = 58});

  final List<int> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<int>(1, math.max);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: math.max(4, (values[i] / maxValue) * (height - 8)),
                    decoration: BoxDecoration(
                      color: i == values.length - 1
                          ? AppColors.navy
                          : AppColors.blue.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SearchInput extends StatelessWidget {
  const SearchInput({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 21),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
      ),
    );
  }
}

class AlertTile extends StatelessWidget {
  const AlertTile({
    super.key,
    required this.alert,
    this.assetCode,
    this.onTap,
    this.onResolve,
  });

  final Alert alert;
  final String? assetCode;
  final VoidCallback? onTap;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(alert.severity);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                alert.severity == AlertSeverity.critical
                    ? Icons.report_problem_rounded
                    : (alert.severity == AlertSeverity.warning
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline_rounded),
                color: color,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontSize: 13),
                        ),
                      ),
                      SeverityBadge(severity: alert.severity),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    alert.message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                    ),
                  ),
                  if (assetCode != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$assetCode · ${alert.type.label}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onResolve != null && alert.isOpen) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Marcar resuelta',
                onPressed: onResolve,
                icon: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 20,
                  color: AppColors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
