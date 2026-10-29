import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ids.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../services/inventory_service.dart';
import '../../widgets/common.dart';

class AssetFormScreen extends ConsumerStatefulWidget {
  const AssetFormScreen({super.key, this.asset});

  final Asset? asset;

  @override
  ConsumerState<AssetFormScreen> createState() => _AssetFormScreenState();
}

class _AssetFormScreenState extends ConsumerState<AssetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _rfid;
  late final TextEditingController _responsible;
  late final TextEditingController _notes;
  late String _categoryId;
  late AssetLocation _location;
  late AssetSituation _situation;
  late OperationalStatus _operational;
  String? _supplierId;
  DateTime? _expectedReturn;
  bool _saving = false;
  String? _autoCode;

  bool get _isEditing => widget.asset != null;

  @override
  void initState() {
    super.initState();
    final state = ref.read(appControllerProvider).requireValue;
    final asset = widget.asset;
    _code = TextEditingController(text: asset?.code ?? '');
    _name = TextEditingController(text: asset?.name ?? '');
    _description = TextEditingController(text: asset?.description ?? '');
    _rfid = TextEditingController(text: asset?.rfidEpc ?? '');
    _responsible = TextEditingController(text: asset?.responsible ?? '');
    _notes = TextEditingController(text: asset?.notes ?? '');
    _categoryId = asset?.categoryId ?? state.categories.first.id;
    _location = asset?.location ?? AssetLocation.inside;
    _situation = asset?.situation ?? AssetSituation.available;
    _operational =
        asset?.operationalStatus ?? OperationalStatus.operational;
    _supplierId = asset?.supplierId;
    _expectedReturn = asset?.expectedReturnAt;
    if (!_isEditing) {
      final category = state.categoryById(_categoryId);
      _autoCode = nextAssetCode(
        category?.codePrefix ?? 'ACT',
        state.assets.map((item) => item.code),
      );
      _code.text = _autoCode!;
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _description.dispose();
    _rfid.dispose();
    _responsible.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar activo' : 'Nuevo activo'),
      ),
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
                  SectionCard(
                    title: 'Identificación',
                    subtitle: 'Datos únicos del activo dentro del inventario',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Código interno *',
                            hintText: 'Ej. O2-051',
                          ),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'El código interno es obligatorio'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Nombre *',
                            hintText: 'Balón de oxígeno medicinal 51',
                          ),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'El nombre es obligatorio'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _categoryId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Categoría *',
                          ),
                          items: [
                            for (final category in state.categories)
                              DropdownMenuItem(
                                value: category.id,
                                child: Text(category.name),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              if (!_isEditing &&
                                  _autoCode != null &&
                                  _code.text == _autoCode) {
                                final category = state.categoryById(value);
                                _autoCode = nextAssetCode(
                                  category?.codePrefix ?? 'ACT',
                                  state.assets.map((item) => item.code),
                                );
                                _code.text = _autoCode!;
                              }
                              _categoryId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _description,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Descripción',
                            hintText: 'Detalle opcional del activo',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _rfid,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Identificador RFID / EPC *',
                            hintText: 'E280117000000...',
                            suffixIcon: IconButton(
                              tooltip: 'Generar EPC ficticio',
                              onPressed: _generateEpc,
                              icon: const Icon(Icons.autorenew_rounded),
                            ),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'El identificador RFID es obligatorio'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Estado',
                    subtitle:
                        'La ubicación física y la situación administrativa se '
                        'guardan por separado',
                    child: Column(
                      children: [
                        DropdownButtonFormField<AssetLocation>(
                          initialValue: _location,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Ubicación física',
                          ),
                          items: [
                            for (final value in AssetLocation.values)
                              DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _location = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<AssetSituation>(
                          initialValue: _situation,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Situación administrativa',
                          ),
                          items: [
                            for (final value in AssetSituation.values)
                              DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _situation = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<OperationalStatus>(
                          initialValue: _operational,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Estado operativo',
                          ),
                          items: [
                            for (final value in OperationalStatus.values)
                              DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _operational = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Asignación y devolución',
                    subtitle: 'Información opcional según la situación actual',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _responsible,
                          decoration: const InputDecoration(
                            labelText: 'Responsable',
                            hintText: 'Persona o entidad',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          initialValue: _supplierId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Proveedor asociado',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Sin proveedor'),
                            ),
                            for (final supplier in state.suppliers)
                              DropdownMenuItem<String?>(
                                value: supplier.id,
                                child: Text(
                                  supplier.active
                                      ? supplier.name
                                      : '${supplier.name} (inactivo)',
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() => _supplierId = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _pickReturnDate,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Fecha prevista de devolución',
                              suffixIcon: _expectedReturn == null
                                  ? const Icon(Icons.calendar_month_rounded)
                                  : IconButton(
                                      onPressed: () => setState(
                                        () => _expectedReturn = null,
                                      ),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                            child: Text(
                              _expectedReturn == null
                                  ? 'Sin fecha prevista'
                                  : formatDateTime(_expectedReturn),
                              style: TextStyle(
                                color: _expectedReturn == null
                                    ? AppColors.muted
                                    : AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notes,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Observaciones',
                            hintText: 'Notas o justificación de correcciones',
                          ),
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
                    label: Text(_saving ? 'Guardando...' : 'Guardar activo'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickReturnDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _expectedReturn ?? now.add(const Duration(days: 3)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 1825)),
      helpText: 'Fecha prevista de devolución',
    );
    if (date == null) return;
    setState(() {
      _expectedReturn = DateTime(date.year, date.month, date.day, 18);
    });
  }

  void _generateEpc() {
    final state = ref.read(appControllerProvider).requireValue;
    final existing = state.assets.map((item) => item.rfidEpc.toUpperCase()).toSet();
    var candidate = '';
    var counter = 0;
    do {
      final stamp = (DateTime.now().microsecondsSinceEpoch + counter) % 100000000;
      candidate =
          'E28011700000020${stamp.toString().padLeft(8, '0').substring(0, 8)}';
      counter += 1;
    } while (existing.contains(candidate) && counter < 50);
    setState(() => _rfid.text = candidate);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_situation == AssetSituation.atSupplier && _supplierId == null) {
      _showError('Seleccioná el proveedor asociado al activo.');
      return;
    }
    if (_situation == AssetSituation.onLoan &&
        _responsible.text.trim().isEmpty) {
      _showError('Indicá el responsable del préstamo.');
      return;
    }

    final original = widget.asset;
    final candidate = original == null
        ? Asset(
            id: newId('AST'),
            code: _code.text.trim().toUpperCase(),
            name: _name.text.trim(),
            categoryId: _categoryId,
            description: _description.text.trim(),
            rfidEpc: _rfid.text.trim().toUpperCase(),
            location: _location,
            situation: _situation,
            operationalStatus: _operational,
            createdAt: DateTime.now(),
            responsible: _emptyToNull(_responsible.text),
            supplierId: _supplierId,
            expectedReturnAt: _expectedReturn,
            notes: _notes.text.trim(),
          )
        : original.copyWith(
            code: _code.text.trim().toUpperCase(),
            name: _name.text.trim(),
            categoryId: _categoryId,
            description: _description.text.trim(),
            rfidEpc: _rfid.text.trim().toUpperCase(),
            location: _location,
            situation: _situation,
            operationalStatus: _operational,
            responsible: _emptyToNull(_responsible.text),
            supplierId: _supplierId,
            expectedReturnAt: _expectedReturn,
            notes: _notes.text.trim(),
            clearResponsible: _responsible.text.trim().isEmpty,
            clearSupplier: _supplierId == null,
            clearExpectedReturn: _expectedReturn == null,
          );

    var allowContradiction = false;
    final contradiction = const InventoryService().contradictionFor(candidate);
    if (contradiction != null) {
      final proceed = await confirmAction(
        context,
        title: 'Combinación contradictoria',
        message:
            '$contradiction\n\nPodés guardarla como corrección explícita, '
            'pero tenés que justificarla en Observaciones.',
        confirmLabel: 'Continuar',
      );
      if (!proceed) return;
      if (_notes.text.trim().isEmpty) {
        _showError(
          'Agregá una justificación en Observaciones para guardar la '
          'combinación contradictoria.',
        );
        return;
      }
      allowContradiction = true;
    }

    setState(() => _saving = true);
    final controller = ref.read(appControllerProvider.notifier);
    final result = original == null
        ? await controller.createAsset(
            candidate,
            allowContradiction: allowContradiction,
          )
        : await controller.updateAsset(
            candidate,
            allowContradiction: allowContradiction,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    showResultMessage(context, result);
    if (result.success) Navigator.pop(context, true);
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(message),
        ),
      );
  }
}
