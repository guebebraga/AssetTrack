import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';

class ZonesScreen extends ConsumerWidget {
  const ZonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).requireValue;
    return Scaffold(
      appBar: AppBar(title: const Text('Habitaciones y sensores')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva habitación'),
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
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.meeting_room_rounded,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 19,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Cada habitación agrupa uno o más sensores internos. '
                          'Las puertas de salida de la institución se siguen '
                          'configurando en Accesos y lectores.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (final zone in state.zones)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ZoneCard(
                      zone: zone,
                      onEdit: () => _openForm(context, ref, zone),
                      onToggle: (value) async {
                        final result = await ref
                            .read(appControllerProvider.notifier)
                            .updateZoneConfiguration(zone.id, value);
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
    Zone? zone,
  ]) async {
    final result = await showModalBottomSheet<ActionResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ZoneFormSheet(zone: zone, ref: ref),
    );
    if (result != null && context.mounted) showResultMessage(context, result);
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({
    required this.zone,
    required this.onEdit,
    required this.onToggle,
  });

  final Zone zone;
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
                    color: (zone.active ? AppColors.teal : AppColors.muted)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.meeting_room_rounded,
                    color: zone.active ? AppColors.teal : AppColors.muted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.name,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontSize: 13.5),
                      ),
                      Text(
                        zone.description,
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
                Switch(value: zone.active, onChanged: onToggle),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final reader in zone.readerIds)
                  StatusPill(
                    label: reader,
                    color: AppColors.teal,
                    compact: true,
                    icon: Icons.settings_input_antenna_rounded,
                  ),
                if (zone.readerIds.isEmpty)
                  const StatusPill(
                    label: 'Sin sensores asociados',
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

class _ZoneFormSheet extends ConsumerStatefulWidget {
  const _ZoneFormSheet({required this.zone, required this.ref});

  final Zone? zone;
  final WidgetRef ref;

  @override
  ConsumerState<_ZoneFormSheet> createState() => _ZoneFormSheetState();
}

class _ZoneFormSheetState extends ConsumerState<_ZoneFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _readers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.zone?.name ?? '');
    _description = TextEditingController(text: widget.zone?.description ?? '');
    _readers = TextEditingController(
      text: widget.zone?.readerIds.join(', ') ?? '',
    );
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
                  widget.zone == null
                      ? 'Nueva habitación'
                      : 'Editar habitación',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    hintText: 'Ej. Unidad de Terapia Intensiva',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'El nombre es obligatorio'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Piso, sector o referencia',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _readers,
                  decoration: const InputDecoration(
                    labelText: 'Sensores / lectores asociados',
                    hintText: 'LEC-UTI-01, LEC-UTI-02',
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
                          final result = widget.zone == null
                              ? await controller.addZone(
                                  name: _name.text,
                                  description: _description.text,
                                  readerIds: readers,
                                )
                              : await controller.updateZone(
                                  widget.zone!.copyWith(
                                    name: _name.text.trim(),
                                    description: _description.text.trim(),
                                    readerIds: readers,
                                  ),
                                );
                          if (!context.mounted) return;
                          setState(() => _saving = false);
                          Navigator.pop(context, result);
                        },
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Guardando...' : 'Guardar habitación'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
