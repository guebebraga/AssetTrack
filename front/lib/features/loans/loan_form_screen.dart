import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/enums.dart';
import '../../widgets/common.dart';

class LoanFormScreen extends ConsumerStatefulWidget {
  const LoanFormScreen({super.key, this.initialAssetId});

  final String? initialAssetId;

  @override
  ConsumerState<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends ConsumerState<LoanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _borrower = TextEditingController();
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  String? _assetId;
  String? _accessId;
  String? _readerId;
  DateTime _dueAt = DateTime.now().add(const Duration(days: 2));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(appControllerProvider).requireValue;
    final eligible = state.assets
        .where(
          (asset) =>
              asset.location == AssetLocation.inside &&
              asset.situation != AssetSituation.onLoan &&
              asset.situation != AssetSituation.atSupplier,
        )
        .toList();
    if (eligible.any((asset) => asset.id == widget.initialAssetId)) {
      _assetId = widget.initialAssetId;
    } else if (eligible.isNotEmpty) {
      _assetId = eligible.first.id;
    }
    final configured = state.accesses.where((item) => item.configured).toList();
    if (configured.isNotEmpty) {
      _accessId = configured.first.id;
      _readerId = configured.first.readerIds.isNotEmpty
          ? configured.first.readerIds.first
          : null;
    }
  }

  @override
  void dispose() {
    _borrower.dispose();
    _reason.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    final eligible = state.assets
        .where(
          (asset) =>
              asset.location == AssetLocation.inside &&
              asset.situation != AssetSituation.onLoan &&
              asset.situation != AssetSituation.atSupplier,
        )
        .toList();
    final selectedAsset = state.assetById(_assetId);
    final access = state.accessById(_accessId);
    final readers = access?.readerIds ?? const <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo préstamo')),
      body: SafeArea(
        bottom: false,
        child: eligible.isEmpty
            ? const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No hay activos disponibles',
                message:
                    'Todos los activos están fuera, prestados o en poder de '
                    'un proveedor.',
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                  child: PageBody(
                    maxWidth: 760,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionCard(
                          title: 'Activo a entregar',
                          subtitle: 'Solo se muestran unidades dentro y libres',
                          child: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _assetId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Activo *',
                                ),
                                items: [
                                  for (final asset in eligible)
                                    DropdownMenuItem(
                                      value: asset.id,
                                      child: Text(
                                        '${asset.code} · ${asset.name}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                validator: (value) => value == null
                                    ? 'Seleccioná un activo'
                                    : null,
                                onChanged: (value) =>
                                    setState(() => _assetId = value),
                              ),
                              if (selectedAsset != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      LocationBadge(
                                        location: selectedAsset.location,
                                        compact: true,
                                      ),
                                      const SizedBox(width: 8),
                                      SituationBadge(
                                        situation: selectedAsset.situation,
                                        compact: true,
                                      ),
                                      const Spacer(),
                                      Text(
                                        selectedAsset.rfidEpc,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.muted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SectionCard(
                          title: 'Datos del préstamo',
                          subtitle: 'Persona o entidad receptora',
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _borrower,
                                decoration: const InputDecoration(
                                  labelText: 'Persona o entidad *',
                                  hintText: 'Ej. Camillero turno mañana',
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Indicá el responsable'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _pickDate,
                                borderRadius: BorderRadius.circular(14),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Fecha prevista de devolución',
                                    suffixIcon: Icon(
                                      Icons.calendar_month_rounded,
                                    ),
                                  ),
                                  child: Text(
                                    formatDateTime(_dueAt),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _reason,
                                decoration: const InputDecoration(
                                  labelText: 'Motivo',
                                  hintText:
                                      'Traslado, estudio, apoyo externo...',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _notes,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Observaciones',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SectionCard(
                          title: 'Acceso y lector',
                          subtitle: 'Opcional para trazabilidad del evento',
                          child: Column(
                            children: [
                              DropdownButtonFormField<String?>(
                                initialValue: _accessId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Acceso',
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Sin acceso asociado'),
                                  ),
                                  for (final item in state.accesses)
                                    DropdownMenuItem<String?>(
                                      value: item.id,
                                      child: Text(item.name),
                                    ),
                                ],
                                onChanged: (value) => setState(() {
                                  _accessId = value;
                                  final selected = state.accessById(value);
                                  _readerId =
                                      selected != null &&
                                          selected.readerIds.isNotEmpty
                                      ? selected.readerIds.first
                                      : null;
                                }),
                              ),
                              if (readers.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _readerId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Lector',
                                  ),
                                  items: [
                                    for (final reader in readers)
                                      DropdownMenuItem(
                                        value: reader,
                                        child: Text(reader),
                                      ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _readerId = value),
                                ),
                              ],
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
                              : const Icon(Icons.handshake_rounded),
                          label: Text(
                            _saving ? 'Guardando...' : 'Registrar préstamo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Devolución prevista',
    );
    if (date == null) return;
    setState(() => _dueAt = DateTime(date.year, date.month, date.day, 18));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_assetId == null) return;
    setState(() => _saving = true);
    final result = await ref
        .read(appControllerProvider.notifier)
        .createLoan(
          assetId: _assetId!,
          borrower: _borrower.text,
          dueAt: _dueAt,
          reason: _reason.text.trim(),
          notes: _notes.text.trim(),
          accessId: _accessId,
          readerId: _readerId,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    showResultMessage(context, result);
    if (result.success) Navigator.pop(context, true);
  }
}
