import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).requireValue;
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva categoría'),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
          child: PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Las categorías agrupan activos y definen el prefijo de sus '
                  'códigos. El tipo clínico/asistencial no almacena datos de '
                  'pacientes.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 14),
                for (final category in state.categories)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Center(
                                child: Text(
                                  category.codePrefix,
                                  style: const TextStyle(
                                    color: AppColors.teal,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontSize: 13.5),
                                  ),
                                  Text(
                                    category.description.isEmpty
                                        ? '${state.assets.where((asset) => asset.categoryId == category.id).length} activo(s)'
                                        : '${state.assets.where((asset) => asset.categoryId == category.id).length} activo(s) · ${category.description}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontSize: 10.5),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${state.assets.where((asset) => asset.categoryId == category.id).length}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: AppColors.navy),
                            ),
                          ],
                        ),
                      ),
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

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<ActionResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CategoryFormSheet(ref: ref),
    );
    if (result != null && context.mounted) showResultMessage(context, result);
  }
}

class _CategoryFormSheet extends ConsumerStatefulWidget {
  const _CategoryFormSheet({required this.ref});

  final WidgetRef ref;

  @override
  ConsumerState<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _prefix = TextEditingController();
  final _description = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _prefix.dispose();
    _description.dispose();
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
                  'Nueva categoría',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    hintText: 'Ej. Bombas de infusión',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'El nombre es obligatorio'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _prefix,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: 'Prefijo de código *',
                    hintText: 'O2',
                    counterText: '',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'El prefijo es obligatorio';
                    if (text.length > 4) return 'Máximo 4 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Uso previsto de la categoría',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _saving = true);
                          final result = await widget.ref
                              .read(appControllerProvider.notifier)
                              .addCategory(
                                name: _name.text,
                                prefix: _prefix.text.toUpperCase(),
                                description: _description.text,
                              );
                          if (!context.mounted) return;
                          setState(() => _saving = false);
                          Navigator.pop(context, result);
                        },
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Guardando...' : 'Guardar categoría'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
