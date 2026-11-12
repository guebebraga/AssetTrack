import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';
import 'supplier_detail_screen.dart';
import 'supplier_delivery_screen.dart';

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).requireValue;
    return Scaffold(
      appBar: AppBar(title: const Text('Proveedores')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo proveedor'),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
          child: PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.infoSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Los proveedores son configurables. Linde es solo un '
                          'proveedor de demostración y puede renombrarse o '
                          'marcarse como inactivo.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.navy, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (state.suppliers.isEmpty)
                  const SectionCard(
                    child: EmptyState(
                      icon: Icons.local_shipping_outlined,
                      title: 'Sin proveedores',
                      message: 'Agregá el primer proveedor externo.',
                    ),
                  )
                else
                  for (final supplier in state.suppliers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SupplierCard(
                        supplier: supplier,
                        state: state,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SupplierDetailScreen(supplierId: supplier.id),
                          ),
                        ),
                        onEdit: () => _openForm(context, ref, supplier),
                        onDeliver: supplier.active
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SupplierDeliveryScreen(
                                    initialSupplierId: supplier.id,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                const SizedBox(height: 8),
                const DemoBanner(compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, [
    Supplier? supplier,
  ]) async {
    final result = await showModalBottomSheet<ActionResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SupplierFormSheet(supplier: supplier, ref: ref),
    );
    if (result != null && context.mounted) {
      showResultMessage(context, result);
    }
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({
    required this.supplier,
    required this.state,
    required this.onTap,
    required this.onEdit,
    required this.onDeliver,
  });

  final Supplier supplier;
  final AppState state;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDeliver;

  @override
  Widget build(BuildContext context) {
    final assets = state.assets
        .where((asset) => asset.supplierId == supplier.id && asset.isAtSupplier)
        .length;
    final openOperations = state.supplierOperations
        .where(
          (operation) =>
              operation.supplierId == supplier.id &&
              operation.status != SupplierOperationStatus.completed,
        )
        .length;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color:
                          (supplier.active
                                  ? AppColors.warning
                                  : AppColors.muted)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.local_shipping_rounded,
                      color: supplier.active
                          ? AppColors.warning
                          : AppColors.muted,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          supplier.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontSize: 15),
                        ),
                        Text(
                          supplier.serviceType.isEmpty
                              ? 'Servicio no especificado'
                              : supplier.serviceType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: supplier.active ? 'Activo' : 'Inactivo',
                    color: supplier.active
                        ? AppColors.success
                        : AppColors.muted,
                    compact: true,
                  ),
                ],
              ),
              if (supplier.contact.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.mail_outline_rounded,
                      size: 14,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      supplier.contact,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _Metric(label: 'En proveedor', value: '$assets'),
                  const SizedBox(width: 18),
                  _Metric(
                    label: 'Operaciones abiertas',
                    value: '$openOperations',
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 19,
                      color: AppColors.muted,
                    ),
                  ),
                  IconButton(
                    tooltip: onDeliver == null
                        ? 'Proveedor inactivo'
                        : 'Nueva entrega',
                    onPressed: onDeliver,
                    icon: Icon(
                      Icons.add_box_outlined,
                      size: 20,
                      color: onDeliver == null
                          ? AppColors.border
                          : AppColors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 14),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9.5),
        ),
      ],
    );
  }
}

class _SupplierFormSheet extends ConsumerStatefulWidget {
  const _SupplierFormSheet({required this.supplier, required this.ref});

  final Supplier? supplier;
  final WidgetRef ref;

  @override
  ConsumerState<_SupplierFormSheet> createState() => _SupplierFormSheetState();
}

class _SupplierFormSheetState extends ConsumerState<_SupplierFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _service;
  late final TextEditingController _contact;
  late final TextEditingController _notes;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.supplier?.name ?? '');
    _service = TextEditingController(text: widget.supplier?.serviceType ?? '');
    _contact = TextEditingController(text: widget.supplier?.contact ?? '');
    _notes = TextEditingController(text: widget.supplier?.notes ?? '');
    _active = widget.supplier?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _service.dispose();
    _contact.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.supplier == null
                      ? 'Nuevo proveedor'
                      : 'Editar proveedor',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    hintText: 'Ej. Linde',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'El nombre es obligatorio'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _service,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de servicio',
                    hintText: 'Recarga, mantenimiento, logística...',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contact,
                  decoration: const InputDecoration(
                    labelText: 'Contacto',
                    hintText: 'Dato ficticio de demostración',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Observaciones'),
                ),
                if (widget.supplier != null) ...[
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Proveedor activo'),
                    subtitle: const Text(
                      'Los proveedores inactivos no permiten nuevas entregas.',
                    ),
                    value: _active,
                    onChanged: (value) => setState(() => _active = value),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _saving = true);
                          final controller = widget.ref.read(
                            appControllerProvider.notifier,
                          );
                          final result = widget.supplier == null
                              ? await controller.addSupplier(
                                  name: _name.text,
                                  serviceType: _service.text,
                                  contact: _contact.text,
                                  notes: _notes.text,
                                )
                              : await controller.updateSupplier(
                                  widget.supplier!.copyWith(
                                    name: _name.text.trim(),
                                    serviceType: _service.text.trim(),
                                    contact: _contact.text.trim(),
                                    notes: _notes.text.trim(),
                                    active: _active,
                                  ),
                                );
                          if (!context.mounted) return;
                          setState(() => _saving = false);
                          Navigator.pop(context, result);
                        },
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Guardando...' : 'Guardar proveedor'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
