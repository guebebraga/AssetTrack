import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';
import '../alerts/alerts_screen.dart';
import '../assets/asset_detail_screen.dart';
import '../assets/assets_screen.dart';
import '../loans/loans_screen.dart';
import '../movements/movements_screen.dart';
import '../rfid/rfid_simulator_screen.dart';
import '../settings/settings_screen.dart';
import '../suppliers/suppliers_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    final stats = ref.watch(dashboardStatsProvider);
    final now = DateTime.now();
    final openAlerts = state.alerts.where((alert) => alert.isOpen).toList()
      ..sort((a, b) => b.severity.index.compareTo(a.severity.index));
    final recentMovements = [...state.movements]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final weekly = List<int>.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      return state.movements
          .where(
            (movement) =>
                movement.timestamp.year == day.year &&
                movement.timestamp.month == day.month &&
                movement.timestamp.day == day.day,
          )
          .length;
    });

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          child: PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  settings: state.settings,
                  alertCount: openAlerts.length,
                  onAlerts: () => _push(context, const AlertsScreen()),
                ),
                const SizedBox(height: 16),
                const DemoBanner(),
                const SizedBox(height: 16),
                SearchInput(
                  controller: _search,
                  hint: 'Buscar por código, nombre o RFID',
                  onChanged: (_) => setState(() {}),
                  onClear: () => setState(_search.clear),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 760 ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: columns == 4 ? 1.4 : 1.28,
                      children: [
                        KpiCard(
                          label: 'Activos registrados',
                          value: '${stats.total}',
                          icon: Icons.inventory_2_rounded,
                          color: AppColors.navy,
                          caption: 'Total',
                          onTap: () =>
                              _push(context, const AssetsScreen()),
                        ),
                        KpiCard(
                          label: 'Dentro de las instalaciones',
                          value: '${stats.inside}',
                          icon: Icons.home_work_rounded,
                          color: AppColors.success,
                          caption: formatPercent(stats.insideRatio),
                          onTap: () => _push(
                            context,
                            const AssetsScreen(
                              initialLocation: AssetLocation.inside,
                            ),
                          ),
                        ),
                        KpiCard(
                          label: 'Fuera de las instalaciones',
                          value: '${stats.outside}',
                          icon: Icons.north_east_rounded,
                          color: AppColors.warning,
                          caption: formatPercent(stats.outsideRatio),
                          onTap: () => _push(
                            context,
                            const AssetsScreen(
                              initialLocation: AssetLocation.outside,
                            ),
                          ),
                        ),
                        KpiCard(
                          label: 'Movimientos de hoy',
                          value: '${stats.todayMovements}',
                          icon: Icons.route_rounded,
                          color: AppColors.blue,
                          caption: 'Hoy',
                          onTap: () =>
                              _push(context, const MovementsScreen()),
                        ),
                        KpiCard(
                          label: 'Activos prestados',
                          value: '${stats.loans}',
                          icon: Icons.handshake_rounded,
                          color: AppColors.purple,
                          caption: '${stats.overdueLoans} vencidos',
                          onTap: () =>
                              _push(context, const LoansScreen()),
                        ),
                        KpiCard(
                          label: 'En poder de proveedores',
                          value: '${stats.atSupplier}',
                          icon: Icons.local_shipping_rounded,
                          color: AppColors.warning,
                          caption: 'Externos',
                          onTap: () =>
                              _push(context, const SuppliersScreen()),
                        ),
                        KpiCard(
                          label: 'Alertas pendientes',
                          value: '${stats.openAlerts}',
                          icon: Icons.notifications_active_rounded,
                          color: AppColors.danger,
                          caption: '${stats.criticalAlerts} críticas',
                          onTap: () =>
                              _push(context, const AlertsScreen()),
                        ),
                        KpiCard(
                          label: 'Eventos por revisar',
                          value: '${stats.pendingReview}',
                          icon: Icons.fact_check_rounded,
                          color: AppColors.teal,
                          caption: 'Trazabilidad',
                          onTap: () => _push(
                            context,
                            const MovementsScreen(
                              initialStatus: MovementStatus.pendingReview,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 720;
                    final chart = _InventoryChart(
                      stats: stats,
                      weekly: weekly,
                    );
                    final actions = _QuickActions(
                      onAssets: () => _push(context, const AssetsScreen()),
                      onSimulator: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RfidSimulatorScreen(),
                        ),
                      ),
                      onLoans: () => _push(context, const LoansScreen()),
                      onSuppliers: () =>
                          _push(context, const SuppliersScreen()),
                      onAlerts: () => _push(context, const AlertsScreen()),
                      onSettings: () =>
                          _push(context, const SettingsScreen()),
                    );
                    if (!wide) {
                      return Column(
                        children: [
                          chart,
                          const SizedBox(height: 14),
                          actions,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: chart),
                        const SizedBox(width: 14),
                        Expanded(flex: 5, child: actions),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                SectionCard(
                  title: 'Últimos movimientos',
                  subtitle: 'Trazabilidad reciente de todos los accesos',
                  trailing: TextButton(
                    onPressed: () =>
                        _push(context, const MovementsScreen()),
                    child: const Text('Ver todos'),
                  ),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < recentMovements.length.clamp(0, 5); i++)
                        _MovementRow(
                          movement: recentMovements[i],
                          state: state,
                        ),
                      if (recentMovements.isEmpty)
                        const EmptyState(
                          icon: Icons.route_rounded,
                          title: 'Sin movimientos',
                          message: 'Todavía no se registraron eventos.',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Alertas recientes',
                  subtitle: '${openAlerts.length} alertas simuladas abiertas',
                  trailing: TextButton(
                    onPressed: () => _push(context, const AlertsScreen()),
                    child: const Text('Ver todas'),
                  ),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final alert in openAlerts.take(3))
                        AlertTile(
                          alert: alert,
                          assetCode: state.assetById(alert.assetId)?.code,
                          onTap: () {
                            final asset = state.assetById(alert.assetId);
                            if (asset != null) {
                              _openAsset(context, asset);
                            } else {
                              _push(context, const AlertsScreen());
                            }
                          },
                          onResolve: () async {
                            final result = await ref
                                .read(appControllerProvider.notifier)
                                .resolveAlert(alert.id);
                            if (context.mounted) {
                              showResultMessage(context, result);
                            }
                          },
                        ),
                      if (openAlerts.isEmpty)
                        const EmptyState(
                          icon: Icons.verified_rounded,
                          title: 'Sin alertas abiertas',
                          message: 'El inventario no presenta alertas activas.',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _ModeIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAsset(BuildContext context, Asset asset) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssetDetailScreen(assetId: asset.id),
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.settings,
    required this.alertCount,
    required this.onAlerts,
  });

  final AppSettings settings;
  final int alertCount;
  final VoidCallback onAlerts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppMark(size: 46),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings.appName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 23,
                  letterSpacing: -0.7,
                ),
              ),
              Text(
                settings.organizationName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Stack(
          children: [
            IconButton.filledTonal(
              onPressed: onAlerts,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            if (alertCount > 0)
              Positioned(
                right: 3,
                top: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    alertCount > 9 ? '9+' : '$alertCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _InventoryChart extends StatelessWidget {
  const _InventoryChart({required this.stats, required this.weekly});

  final dynamic stats;
  final List<int> weekly;

  @override
  Widget build(BuildContext context) {
    final inside = stats.inside as int;
    final outside = stats.outside as int;
    final weeklyTotal = weekly.fold<int>(0, (sum, item) => sum + item);
    return SectionCard(
      title: 'Distribución del inventario',
      subtitle: 'Ubicación física actual de los activos',
      child: Column(
        children: [
          Row(
            children: [
              DonutChart(inside: inside, outside: outside, size: 140),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendRow(
                      color: AppColors.success,
                      label: 'Dentro',
                      value: '$inside',
                    ),
                    const SizedBox(height: 12),
                    _LegendRow(
                      color: AppColors.warning,
                      label: 'Fuera',
                      value: '$outside',
                    ),
                    const SizedBox(height: 12),
                    _LegendRow(
                      color: AppColors.muted,
                      label: 'Sin ubicación cierta',
                      value: '${stats.unknown}',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Movimientos · 7 días',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$weeklyTotal eventos registrados',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 150,
                child: WeeklyBars(values: weekly),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 14),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAssets,
    required this.onSimulator,
    required this.onLoans,
    required this.onSuppliers,
    required this.onAlerts,
    required this.onSettings,
  });

  final VoidCallback onAssets;
  final VoidCallback onSimulator;
  final VoidCallback onLoans;
  final VoidCallback onSuppliers;
  final VoidCallback onAlerts;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Accesos rápidos',
      subtitle: 'Operaciones frecuentes de la demostración',
      child: Column(
        children: [
          Row(
            children: [
              _QuickAction(
                icon: Icons.inventory_2_rounded,
                label: 'Activos',
                color: AppColors.navy,
                onTap: onAssets,
              ),
              _QuickAction(
                icon: Icons.sensors_rounded,
                label: 'Simulador',
                color: AppColors.blue,
                onTap: onSimulator,
              ),
              _QuickAction(
                icon: Icons.handshake_rounded,
                label: 'Préstamos',
                color: AppColors.purple,
                onTap: onLoans,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _QuickAction(
                icon: Icons.local_shipping_rounded,
                label: 'Proveedores',
                color: AppColors.warning,
                onTap: onSuppliers,
              ),
              _QuickAction(
                icon: Icons.notifications_active_rounded,
                label: 'Alertas',
                color: AppColors.danger,
                onTap: onAlerts,
              ),
              _QuickAction(
                icon: Icons.tune_rounded,
                label: 'Config.',
                color: AppColors.teal,
                onTap: onSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement, required this.state});

  final MovementEvent movement;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final asset = state.assetById(movement.assetId);
    return MovementTile(
      movement: movement,
      assetCode: asset?.code ?? movement.assetId,
      accessName: state.accessById(movement.accessId)?.name,
      supplierName: state.supplierById(movement.supplierId)?.name,
      onTap: () {
        if (asset != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AssetDetailScreen(assetId: asset.id),
            ),
          );
        }
      },
    );
  }
}

class _ModeIndicator extends StatelessWidget {
  const _ModeIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modo demostración sin conexión',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  'Fuente RFID simulada · Sin backend · Datos locales',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10.8,
                  ),
                ),
              ],
            ),
          ),
          const StatusPill(
            label: 'SIMULADO',
            color: AppColors.warning,
            compact: true,
          ),
        ],
      ),
    );
  }
}
