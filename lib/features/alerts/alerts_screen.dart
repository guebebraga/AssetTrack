import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';
import '../assets/asset_detail_screen.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  AlertSeverity? _severity;
  bool _showResolved = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    final alerts = state.alerts.where((alert) {
      if (!_showResolved && !alert.isOpen) return false;
      if (_showResolved && alert.isOpen) return false;
      if (_severity != null && alert.severity != _severity) return false;
      return true;
    }).toList();
    final open = state.alerts.where((alert) => alert.isOpen).toList();
    final critical = open
        .where((alert) => alert.severity == AlertSeverity.critical)
        .length;
    final warning = open
        .where((alert) => alert.severity == AlertSeverity.warning)
        .length;
    final info = open
        .where((alert) => alert.severity == AlertSeverity.info)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Alertas')),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          child: PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DemoBanner(compact: true),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SeverityCard(
                        label: 'Críticas',
                        value: '$critical',
                        severity: AlertSeverity.critical,
                        selected: _severity == AlertSeverity.critical,
                        onTap: () => setState(
                          () => _severity = _severity == AlertSeverity.critical
                              ? null
                              : AlertSeverity.critical,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SeverityCard(
                        label: 'Advertencias',
                        value: '$warning',
                        severity: AlertSeverity.warning,
                        selected: _severity == AlertSeverity.warning,
                        onTap: () => setState(
                          () => _severity = _severity == AlertSeverity.warning
                              ? null
                              : AlertSeverity.warning,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SeverityCard(
                        label: 'Información',
                        value: '$info',
                        severity: AlertSeverity.info,
                        selected: _severity == AlertSeverity.info,
                        onTap: () => setState(
                          () => _severity = _severity == AlertSeverity.info
                              ? null
                              : AlertSeverity.info,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showResolved
                            ? 'Alertas resueltas'
                            : 'Alertas abiertas (${alerts.length})',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontSize: 13),
                      ),
                    ),
                    Switch(
                      value: _showResolved,
                      onChanged: (value) =>
                          setState(() => _showResolved = value),
                    ),
                    const Text(
                      'Ver resueltas',
                      style: TextStyle(fontSize: 10.5),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (alerts.isEmpty)
                  SectionCard(
                    child: EmptyState(
                      icon: _showResolved
                          ? Icons.history_rounded
                          : Icons.verified_rounded,
                      title: _showResolved
                          ? 'Sin alertas resueltas'
                          : 'Sin alertas para el filtro',
                      message: _showResolved
                          ? 'Las alertas que marques como resueltas aparecerán '
                                'aquí.'
                          : 'El inventario no presenta alertas con esa '
                                'severidad.',
                    ),
                  )
                else
                  for (final alert in alerts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: AlertTile(
                          alert: alert,
                          assetCode: state.assetById(alert.assetId)?.code,
                          onTap: () => _showDetails(context, state, alert),
                          onResolve: alert.isOpen
                              ? () async {
                                  final result = await ref
                                      .read(appControllerProvider.notifier)
                                      .resolveAlert(alert.id);
                                  if (context.mounted) {
                                    showResultMessage(context, result);
                                  }
                                }
                              : null,
                        ),
                      ),
                    ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.infoSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.science_outlined,
                        color: AppColors.blue,
                        size: 18,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Todas las alertas de esta demostración son '
                          'simuladas y se calculan a partir de los datos '
                          'locales. Los umbrales se configuran en Ajustes.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 11,
                                color: AppColors.navy,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    AppState state,
    Alert alert,
  ) async {
    final asset = state.assetById(alert.assetId);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      alert.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  SeverityBadge(severity: alert.severity),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                alert.message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              InfoRow(
                label: 'Tipo',
                value: alert.type.label,
                icon: Icons.category_outlined,
              ),
              InfoRow(
                label: 'Activo',
                value: asset == null
                    ? 'Sin activo asociado'
                    : '${asset.code} · ${asset.name}',
                icon: Icons.inventory_2_outlined,
              ),
              InfoRow(
                label: 'Creada',
                value: formatDateTime(alert.createdAt),
                icon: Icons.schedule_rounded,
              ),
              InfoRow(
                label: 'Origen',
                value: alert.simulated
                    ? 'Datos simulados de demostración'
                    : 'Datos reales',
                icon: Icons.science_outlined,
              ),
              if (alert.resolvedAt != null)
                InfoRow(
                  label: 'Resuelta',
                  value: formatDateTime(alert.resolvedAt),
                  icon: Icons.check_circle_outline_rounded,
                ),
              const SizedBox(height: 12),
              if (asset != null)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssetDetailScreen(assetId: asset.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Ver activo'),
                ),
              if (alert.isOpen) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () async {
                    final result = await ref
                        .read(appControllerProvider.notifier)
                        .resolveAlert(alert.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                      showResultMessage(context, result);
                    }
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Marcar como resuelta'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SeverityCard extends StatelessWidget {
  const _SeverityCard({
    required this.label,
    required this.value,
    required this.severity,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final AlertSeverity severity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(severity);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontSize: 21,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
