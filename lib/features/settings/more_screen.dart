import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common.dart';
import '../alerts/alerts_screen.dart';
import '../loans/loans_screen.dart';
import '../suppliers/suppliers_screen.dart';
import 'about_screen.dart';
import 'accesses_screen.dart';
import 'categories_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).requireValue;
    final openLoans = state.loans.where((loan) => loan.isOpen).length;
    final openAlerts = state.alerts.where((alert) => alert.isOpen).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          child: PageBody(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.navyMid, AppColors.navyDark],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const AppMark(size: 48, light: true),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.settings.appName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              state.settings.organizationName,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const StatusPill(
                        label: 'DEMO',
                        color: AppColors.warning,
                        compact: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Operación',
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _MenuTile(
                        icon: Icons.handshake_rounded,
                        color: AppColors.purple,
                        title: 'Préstamos',
                        subtitle:
                            '$openLoans préstamo(s) abierto(s), devoluciones y '
                            'vencimientos',
                        onTap: () => _push(context, const LoansScreen()),
                      ),
                      const Divider(),
                      _MenuTile(
                        icon: Icons.local_shipping_rounded,
                        color: AppColors.warning,
                        title: 'Proveedores y recargas',
                        subtitle:
                            '${state.suppliers.length} proveedor(es), entregas '
                            'e intercambios',
                        onTap: () => _push(context, const SuppliersScreen()),
                      ),
                      const Divider(),
                      _MenuTile(
                        icon: Icons.notifications_active_rounded,
                        color: AppColors.danger,
                        title: 'Alertas',
                        subtitle: '$openAlerts alerta(s) abierta(s)',
                        onTap: () => _push(context, const AlertsScreen()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Configuración',
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _MenuTile(
                        icon: Icons.door_front_door_rounded,
                        color: AppColors.blue,
                        title: 'Accesos y lectores',
                        subtitle:
                            '${state.accesses.length} acceso(s) configurado(s)',
                        onTap: () => _push(context, const AccessesScreen()),
                      ),
                      const Divider(),
                      _MenuTile(
                        icon: Icons.category_rounded,
                        color: AppColors.teal,
                        title: 'Categorías de activos',
                        subtitle: '${state.categories.length} categoría(s)',
                        onTap: () => _push(context, const CategoriesScreen()),
                      ),
                      const Divider(),
                      _MenuTile(
                        icon: Icons.tune_rounded,
                        color: AppColors.navy,
                        title: 'Ajustes generales',
                        subtitle:
                            'Organización, marca, umbrales y simulación',
                        onTap: () => _push(context, const SettingsScreen()),
                      ),
                      const Divider(),
                      _MenuTile(
                        icon: Icons.info_outline_rounded,
                        color: AppColors.muted,
                        title: 'Acerca de AssetTrack',
                        subtitle: 'Versión, alcance y estado de la demo',
                        onTap: () => _push(context, const AboutScreen()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const DemoBanner(),
                const SizedBox(height: 14),
                const Center(
                  child: Text(
                    'AssetTrack 1.0.0 · Demostración local sin backend',
                    style: TextStyle(fontSize: 10.5, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10.8,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 21,
            ),
          ],
        ),
      ),
    );
  }
}
