import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/utils/formatters.dart';
import '../../domain/enums.dart';
import '../../widgets/common.dart';

class SupplierDeliveryScreen extends ConsumerStatefulWidget {
  const SupplierDeliveryScreen({
    super.key,
    this.initialSupplierId,
    this.initialAssetIds = const [],
  });

  final String? initialSupplierId;
  final List<String> initialAssetIds;

  @override
  ConsumerState<SupplierDeliveryScreen> createState() =>
      _SupplierDeliveryScreenState();
}

class _SupplierDeliveryScreenState
    extends ConsumerState<SupplierDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  final _search = TextEditingController();
  final Set<String> _selected = {};
  String? _supplierId;
  String? _accessId;
  String? _readerId;
  DateTime _dueAt = DateTime.now().add(const Duration(days: 3));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(appControllerProvider).requireValue;
    _selected.addAll(
      widget.initialAssetIds.where(
        (id) => state.assetById(id)?.isInside ?? false,
      ),
    );
    final active = state.suppliers.where((item) => item.active).toList();
    if (active.any((item) => item.id == widget.initialSupplierId)) {
      _supplierId = widget.initialSupplierId;
    } else if (active.isNotEmpty) {
      _supplierId = active.first.id;
    }
    final supplierAccess = state.accesses
        .where((item) => item.type == AccessType.supplier)
        .toList();
    final access = supplierAccess.isNotEmpty
        ? supplierAccess.first
        : (state.accesses.isNotEmpty ? state.accesses.first : null);
    _accessId = access?.id;
    _readerId = access != null && access.readerIds.isNotEmpty
        ? access.readerIds.first
        : null;
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    _notes.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    final eligible = state.assets
        .where(
          (asset) =>
              asset.location == AssetLocation.inside &&
              asset.situation != AssetSituation.atSupplier &&
              asset.situation != AssetSituation.onLoan,
        )
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final query = _search.text.trim().toLowerCase();
    final filtered = eligible
        .where(
          (asset) =>
              query.isEmpty ||
              asset.code.toLowerCase().contains(query) ||
              asset.name.toLowerCase().contains(query),
        )
        .toList();
    final access = state.accessById(_accessId);
    final readers = access?.readerIds ?? const <String>[];
    final activeSuppliers = state.suppliers
        .where((supplier) => supplier.active)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Entrega a proveedor')),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            child: PageBody(
              maxWidth: 820,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionCard(
                    title: 'Operación',
                    subtitle:
                        'Se registra un evento individual por cada activo '
                        'entregado',
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _supplierId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Proveedor *',
                          ),
                          items: [
                            for (final supplier in activeSuppliers)
                              DropdownMenuItem(
                                value: supplier.id,
                                child: Text(supplier.name),
                              ),
                          ],
                          validator: (value) => value == null
                              ? 'Seleccioná un proveedor activo'
                              : null,
                          onChanged: (value) =>
                              setState(() => _supplierId = value),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Retorno previsto',
                              suffixIcon: Icon(Icons.calendar_month_rounded),
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
                            hintText: 'Recarga, intercambio, reparación...',
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
                    title: 'Activos a entregar',
                    subtitle:
                        '${_selected.length} seleccionado(s) de '
                        '${eligible.length} disponible(s)',
                    child: Column(
                      children: [
                        SearchInput(
                          controller: _search,
                          hint: 'Buscar activo dentro de las instalaciones',
                          onChanged: (_) => setState(() {}),
                          onClear: () => setState(_search.clear),
                        ),
                        const SizedBox(height: 10),
                        if (eligible.isEmpty)
                          const EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'Sin activos disponibles',
                            message:
                                'No hay activos dentro y libres para entregar.',
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 330),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const Divider(),
                              itemBuilder: (context, index) {
                                final asset = filtered[index];
                                final checked =
                                    _selected.contains(asset.id);
                                return CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: checked,
                                  onChanged: (value) => setState(() {
                                    if (value == true) {
                                      _selected.add(asset.id);
                                    } else {
                                      _selected.remove(asset.id);
                                    }
                                  }),
                                  title: Text(
                                    '${asset.code} · ${asset.name}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${asset.situation.label} · '
                                    '${asset.lastMovementAt == null ? 'Sin registros' : relativeTime(asset.lastMovementAt)}',
                                    style: const TextStyle(fontSize: 10.5),
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Acceso y lector',
                    subtitle: 'Punto de salida asociado a la operación',
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
                            _readerId = selected != null &&
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
                    onPressed: _saving || _selected.isEmpty ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.local_shipping_rounded),
                    label: Text(
                      _saving
                          ? 'Guardando...'
                          : 'Registrar entrega (${_selected.length})',
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
      helpText: 'Retorno previsto',
    );
    if (date == null) return;
    setState(() => _dueAt = DateTime(date.year, date.month, date.day, 18));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_supplierId == null || _selected.isEmpty) return;
    setState(() => _saving = true);
    final result = await ref
        .read(appControllerProvider.notifier)
        .createSupplierDelivery(
          supplierId: _supplierId!,
          assetIds: _selected.toList(),
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
