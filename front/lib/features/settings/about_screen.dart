import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/common.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de AssetTrack')),
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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.navyMid, AppColors.navyDark],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppMark(size: 52, light: true),
                      const SizedBox(height: 16),
                      const Text(
                        'AssetTrack',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Identificación y trazabilidad de activos por RFID',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text(
                          'DEMO · DATOS SIMULADOS · RFID NO CONECTADO',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Qué permite hacer',
                  child: Column(
                    children: const [
                      _FeatureRow(
                        icon: Icons.inventory_2_rounded,
                        title: 'Inventario y búsqueda',
                        description:
                            '50 balones de oxígeno de demostración con código, '
                            'EPC, categoría, estado, ubicación y situación '
                            'administrativa separadas.',
                      ),
                      _FeatureRow(
                        icon: Icons.settings_input_antenna_rounded,
                        title: 'Lecturas y movimientos',
                        description:
                            'Procesa lecturas RFID simuladas en entradas y '
                            'salidas, agrupa repeticiones y deja pendientes las '
                            'lecturas ambiguas sin inventar movimientos.',
                      ),
                      _FeatureRow(
                        icon: Icons.local_shipping_rounded,
                        title: 'Préstamos y proveedores',
                        description:
                            'Préstamos con devolución y proveedores con '
                            'entregas parciales, intercambios y recepciones no '
                            'registradas.',
                      ),
                      _FeatureRow(
                        icon: Icons.notifications_active_rounded,
                        title: 'Alertas y control',
                        description:
                            'Alertas simuladas por ubicación, estancamiento, '
                            'préstamos vencidos y diferencias de proveedor, con '
                            'resolución y registro de correcciones.',
                      ),
                      _FeatureRow(
                        icon: Icons.storage_rounded,
                        title: 'Funcionamiento local',
                        description:
                            'Persistencia en el dispositivo, sin backend ni '
                            'credenciales externas. Los datos sobreviven al '
                            'cierre de la aplicación.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Qué es simulado',
                  child: Column(
                    children: const [
                      _FeatureRow(
                        icon: Icons.usb_off_rounded,
                        title: 'Hardware RFID',
                        description:
                            'No hay lector físico conectado. La fuente es un '
                            'simulador que genera EPC válidos del inventario y '
                            'algunos EPC desconocidos.',
                        color: AppColors.warning,
                      ),
                      _FeatureRow(
                        icon: Icons.science_outlined,
                        title: 'Datos de ejemplo',
                        description:
                            'Los 50 activos, proveedor Linde, accesos, '
                            'movimientos y alertas son ficticios y '
                            'deterministas.',
                        color: AppColors.warning,
                      ),
                      _FeatureRow(
                        icon: Icons.cloud_off_rounded,
                        title: 'Backend y usuarios',
                        description:
                            'No existe sincronización, autenticación ni '
                            'servicios externos. La sesión es local.',
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Para integrar RFID real',
                  child: Column(
                    children: const [
                      _FeatureRow(
                        icon: Icons.extension_rounded,
                        title: 'Adaptador de lector',
                        description:
                            'Implementar la interfaz RfidReader existente con '
                            'el SDK del fabricante (RAIN RFID / EPC Gen2) y '
                            'traducir sus eventos a RfidEvent.',
                      ),
                      _FeatureRow(
                        icon: Icons.door_front_door_rounded,
                        title: 'Mapeo de portales',
                        description:
                            'Asociar cada lector y antena a un acceso, '
                            'definiendo entrada, salida o zona interna, y '
                            'gestionar la deduplicación física.',
                      ),
                      _FeatureRow(
                        icon: Icons.security_rounded,
                        title: 'Operación y seguridad',
                        description:
                            'Definir red, credenciales, diagnóstico de lectores, '
                            'reconciliación de lecturas y política de datos '
                            'antes de producción.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const DemoBanner(),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Version 1.0.0 · Flutter / Android\n'
                    'Sin datos clínicos ni información de pacientes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.muted,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
    this.color = AppColors.blue,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
