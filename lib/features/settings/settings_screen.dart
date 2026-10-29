import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _organization;
  late final TextEditingController _appName;
  late final TextEditingController _outsideHours;
  late final TextEditingController _detectionHours;
  late final TextEditingController _dedupe;
  late final TextEditingController _antennas;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appControllerProvider).requireValue.settings;
    _organization = TextEditingController(text: settings.organizationName);
    _appName = TextEditingController(text: settings.appName);
    _outsideHours = TextEditingController(
      text: '${settings.outsideThresholdHours}',
    );
    _detectionHours = TextEditingController(
      text: '${settings.alertDetectionHours}',
    );
    _dedupe = TextEditingController(text: '${settings.dedupeWindowSeconds}');
    _antennas = TextEditingController(text: '${settings.readerAntennaCount}');
  }

  @override
  void dispose() {
    _organization.dispose();
    _appName.dispose();
    _outsideHours.dispose();
    _detectionHours.dispose();
    _dedupe.dispose();
    _antennas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            child: PageBody(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DemoBanner(compact: true),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Organización y marca',
                    subtitle:
                        'El nombre de la aplicación se puede personalizar',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _organization,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la organización',
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _appName,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la aplicación',
                          ),
                          validator: _required,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Umbrales',
                    subtitle:
                        'Configuración usada para generar alertas simuladas',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _outsideHours,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Horas fuera para alertar',
                            suffixText: 'h',
                          ),
                          validator: _positive,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _detectionHours,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Horas sin detección para alertar',
                            suffixText: 'h',
                          ),
                          validator: _positive,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Parámetros de simulación',
                    subtitle:
                        'No modifican el hardware: solo la fuente simulada',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _dedupe,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Ventana de agrupación de lecturas',
                            suffixText: 's',
                          ),
                          validator: _positive,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _antennas,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Antenas simuladas por lector',
                          ),
                          validator: _positive,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Fuente RFID',
                    child: Column(
                      children: [
                        InfoRow(
                          label: 'Fuente actual',
                          value: state.settings.rfidSourceName,
                          icon: Icons.settings_input_antenna_rounded,
                        ),
                        InfoRow(
                          label: 'Estado',
                          value:
                              '${state.settings.rfidSourceStatus} · sin hardware conectado',
                          icon: Icons.usb_off_rounded,
                          valueColor: AppColors.warning,
                        ),
                        InfoRow(
                          label: 'Integración real',
                          value:
                              'Requiere adapter RAIN RFID / EPC Gen2 y '
                              'definición del portal',
                          icon: Icons.construction_rounded,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warningSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: AppColors.warning,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'La aplicación no está conectada a lectores '
                                  'reales. Todos los eventos RFID provienen del '
                                  'simulador local.',
                                  style: TextStyle(
                                    fontSize: 10.8,
                                    color: AppColors.text,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Datos de demostración',
                    subtitle:
                        'Restablece el conjunto inicial de 50 balones y sus '
                        'movimientos',
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _resetDemo,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.dangerSoft),
                      ),
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Restablecer demostración'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Aplicación',
                    child: Column(
                      children: const [
                        InfoRow(
                          label: 'Versión',
                          value: '1.0.0 (build 1)',
                          icon: Icons.tag_rounded,
                        ),
                        InfoRow(
                          label: 'Plataforma',
                          value: 'Flutter · Android · Material 3',
                          icon: Icons.phone_android_rounded,
                        ),
                        InfoRow(
                          label: 'Persistencia',
                          value: 'Local, sin backend',
                          icon: Icons.storage_rounded,
                        ),
                        InfoRow(
                          label: 'Modo',
                          value: 'Demostración con datos simulados',
                          icon: Icons.science_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'Guardando...' : 'Guardar ajustes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obligatorio' : null;

  String? _positive(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed < 1) return 'Ingresá un valor mayor a cero';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final state = ref.read(appControllerProvider).requireValue;
    final settings = state.settings.copyWith(
      organizationName: _organization.text.trim(),
      appName: _appName.text.trim(),
      outsideThresholdHours: int.parse(_outsideHours.text),
      alertDetectionHours: int.parse(_detectionHours.text),
      dedupeWindowSeconds: int.parse(_dedupe.text),
      readerAntennaCount: int.parse(_antennas.text),
    );
    final result = await ref
        .read(appControllerProvider.notifier)
        .updateSettings(settings);
    if (!mounted) return;
    setState(() => _saving = false);
    showResultMessage(context, result);
  }

  Future<void> _resetDemo() async {
    final confirmed = await confirmAction(
      context,
      title: 'Restablecer demostración',
      message:
          'Se perderán todos los cambios locales, incluidos activos, '
          'movimientos, préstamos y operaciones. Se restaurará el conjunto '
          'inicial de demostración. Esta acción no se puede deshacer.',
      confirmLabel: 'Restablecer todo',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    final result = await ref
        .read(appControllerProvider.notifier)
        .resetDemo();
    if (!mounted) return;
    setState(() => _saving = false);
    showResultMessage(context, result);
  }
}
