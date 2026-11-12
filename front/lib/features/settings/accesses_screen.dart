import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';

class AccessesScreen extends ConsumerWidget {
  const AccessesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).requireValue;
    return Scaffold(
      appBar: AppBar(title: const Text('Accesos y lectores')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo acceso'),
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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.infoSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.door_front_door_rounded,
                        color: AppColors.blue,
                        size: 19,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Todos los accesos alimentan un inventario común. Un '
                          'mismo activo no se contabiliza varias veces si lo '
                          'detectan lectores distintos.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 11, color: AppColors.navy),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (final access in state.accesses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AccessCard(
                      access: access,
                      onEdit: () => _openForm(context, ref, access),
                      onToggle: (value) async {
                        final result = await ref
                            .read(appControllerProvider.notifier)
                            .updateAccessConfiguration(access.id, value);
                        if (context.mounted) {
                          showResultMessage(context, result);
                        }
                      },
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
    AccessPoint? access,
  ]) async {
    final result = await showModalBottomSheet<ActionResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AccessFormSheet(access: access, ref: ref),
    );
    if (result != null && context.mounted) showResultMessage(context, result);
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.access,
    required this.onEdit,
    required this.onToggle,
  });

  final AccessPoint access;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        (access.configured ? AppColors.blue : AppColors.muted)
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.door_front_door_rounded,
                    color: access.configured ? AppColors.blue : AppColors.muted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        access.name,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontSize: 13.5),
                      ),
                      Text(
                        '${access.type.label} · ${access.description}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 19,
                    color: AppColors.muted,
                  ),
                ),
                Switch(value: access.configured, onChanged: onToggle),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final reader in access.readerIds)
                  StatusPill(
                    label: reader,
                    color: AppColors.teal,
                    compact: true,
                    icon: Icons.settings_input_antenna_rounded,
                  ),
                if (access.readerIds.isEmpty)
                  const StatusPill(
                    label: 'Sin lectores asociados',
                    color: AppColors.muted,
                    compact: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessFormSheet extends ConsumerStatefulWidget {
  const _AccessFormSheet({required this.access, required this.ref});

  final AccessPoint? access;
  final WidgetRef ref;

  @override
  ConsumerState<_AccessFormSheet> createState() => _AccessFormSheetState();
}

class _AccessFormSheetState extends ConsumerState<_AccessFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _readers;
  late AccessType _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.access?.name ?? '');
    _description = TextEditingController(
      text: widget.access?.description ?? '',
    );
    _readers = TextEditingController(
      text: widget.access?.readerIds.join(', ') ?? '',
    );
    _type = widget.access?.type ?? AccessType.other;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _readers.dispose();
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
                  widget.access == null ? 'Nuevo acceso' : 'Editar acceso',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    hintText: 'Ej. Acceso de ambulancias',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'El nombre es obligatorio'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AccessType>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de acceso',
                  ),
                  items: [
                    for (final type in AccessType.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _type = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación descriptiva',
                    hintText: 'Sector, piso o referencia',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _readers,
                  decoration: const InputDecoration(
                    labelText: 'Lectores asociados',
                    hintText: 'LEC-01, LEC-02',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _saving = true);
                          final readers = _readers.text
                              .split(',')
                              .map((item) => item.trim())
                              .where((item) => item.isNotEmpty)
                              .toList();
                          final controller = widget.ref.read(
                            appControllerProvider.notifier,
                          );
                          final result = widget.access == null
                              ? await controller.addAccess(
                                  name: _name.text,
                                  type: _type,
                                  description: _description.text,
                                  readerIds: readers,
                                )
                              : await controller.updateAccess(
                                  widget.access!.copyWith(
                                    name: _name.text.trim(),
                                    type: _type,
                                    description: _description.text.trim(),
                                    readerIds: readers,
                                  ),
                                );
                          if (!context.mounted) return;
                          setState(() => _saving = false);
                          Navigator.pop(context, result);
                        },
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Guardando...' : 'Guardar acceso'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
