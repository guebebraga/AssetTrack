import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';
import 'asset_detail_screen.dart';
import 'asset_form_screen.dart';

enum AssetSort { lastDetection, lastMovement, expectedReturn, code }

class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({
    super.key,
    this.initialQuery = '',
    this.initialLocation,
    this.initialSituation,
    this.initialCategoryId,
    this.initialRoomId,
  });

  final String initialQuery;
  final AssetLocation? initialLocation;
  final AssetSituation? initialSituation;
  final String? initialCategoryId;
  final String? initialRoomId;

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  late final TextEditingController _search;
  AssetLocation? _location;
  AssetSituation? _situation;
  String? _categoryId;
  String? _roomId;
  AssetSort _sort = AssetSort.lastMovement;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery)
      ..addListener(() => setState(() {}));
    _location = widget.initialLocation;
    _situation = widget.initialSituation;
    _categoryId = widget.initialCategoryId;
    _roomId = widget.initialRoomId;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Asset> _filtered(AppState state) {
    final query = _search.text.trim().toLowerCase();
    final result = state.assets.where((asset) {
      if (_location != null && asset.location != _location) return false;
      if (_situation != null && asset.situation != _situation) return false;
      if (_categoryId != null && asset.categoryId != _categoryId) return false;
      if (_roomId != null && asset.roomId != _roomId) return false;
      if (query.isEmpty) return true;
      return asset.code.toLowerCase().contains(query) ||
          asset.name.toLowerCase().contains(query) ||
          asset.rfidEpc.toLowerCase().contains(query) ||
          (asset.responsible?.toLowerCase().contains(query) ?? false);
    }).toList();

    result.sort((a, b) {
      switch (_sort) {
        case AssetSort.lastDetection:
          final av = a.lastDetectionAt;
          final bv = b.lastDetectionAt;
          if (av == null && bv == null) return a.code.compareTo(b.code);
          if (av == null) return 1;
          if (bv == null) return -1;
          return bv.compareTo(av);
        case AssetSort.lastMovement:
          final av = a.lastMovementAt;
          final bv = b.lastMovementAt;
          if (av == null && bv == null) return a.code.compareTo(b.code);
          if (av == null) return 1;
          if (bv == null) return -1;
          return bv.compareTo(av);
        case AssetSort.expectedReturn:
          final av = a.expectedReturnAt;
          final bv = b.expectedReturnAt;
          if (av == null && bv == null) return a.code.compareTo(b.code);
          if (av == null) return 1;
          if (bv == null) return -1;
          return av.compareTo(bv);
        case AssetSort.code:
          return a.code.compareTo(b.code);
      }
    });
    return result;
  }

  bool get _hasFilters =>
      _location != null ||
      _situation != null ||
      _categoryId != null ||
      _roomId != null ||
      _search.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    final assets = _filtered(state);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activos'),
        actions: [
          IconButton(
            tooltip: 'Nuevo activo',
            onPressed: _openForm,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo activo'),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
          child: PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SearchInput(
                  controller: _search,
                  hint: 'Buscar por nombre, código o identificador RFID',
                  onChanged: (_) => setState(() {}),
                  onClear: () => setState(_search.clear),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterButton(
                      label: _categoryId == null
                          ? 'Categoría'
                          : (state.categoryById(_categoryId)?.name ??
                                'Categoría'),
                      active: _categoryId != null,
                      onTap: () => _pickCategory(state),
                    ),
                    _FilterButton(
                      label: _location?.shortLabel ?? 'Ubicación',
                      active: _location != null,
                      onTap: _pickLocation,
                    ),
                    _FilterButton(
                      label: _roomId == null
                          ? 'Habitación'
                          : (state.zoneById(_roomId)?.name ?? 'Habitación'),
                      active: _roomId != null,
                      onTap: () => _pickRoom(state),
                    ),
                    _FilterButton(
                      label: _situation?.label ?? 'Situación',
                      active: _situation != null,
                      onTap: _pickSituation,
                    ),
                    _FilterButton(
                      label: _sortLabel,
                      active: _sort != AssetSort.lastMovement,
                      icon: Icons.sort_rounded,
                      onTap: _pickSort,
                    ),
                    if (_hasFilters)
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(
                          Icons.filter_alt_off_rounded,
                          size: 16,
                        ),
                        label: const Text('Limpiar'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '${assets.length} activo(s)',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      _sortLabel,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SectionCard(
                  padding: EdgeInsets.zero,
                  child: assets.isEmpty
                      ? const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'Sin activos para mostrar',
                          message:
                              'Ajustá los filtros o registrá un nuevo activo.',
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < assets.length; i++) ...[
                              if (i > 0) const Divider(),
                              AssetListTile(
                                asset: assets[i],
                                categoryName:
                                    state
                                        .categoryById(assets[i].categoryId)
                                        ?.name ??
                                    'Sin categoría',
                                roomName: state
                                    .zoneById(assets[i].roomId)
                                    ?.name,
                                onTap: () => _openDetail(assets[i]),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _sortLabel => switch (_sort) {
    AssetSort.lastDetection => 'Última detección',
    AssetSort.lastMovement => 'Último movimiento',
    AssetSort.expectedReturn => 'Devolución prevista',
    AssetSort.code => 'Código interno',
  };

  void _clearFilters() {
    setState(() {
      _location = null;
      _situation = null;
      _categoryId = null;
      _roomId = null;
      _search.clear();
    });
  }

  Future<void> _pickCategory(AppState state) async {
    final selected = await _showOptions<String?>(
      title: 'Categoría',
      options: [
        (null, 'Todas las categorías'),
        for (final category in state.categories) (category.id, category.name),
      ],
      selected: _categoryId,
    );
    if (selected == null) return;
    setState(() => _categoryId = selected.value);
  }

  Future<void> _pickLocation() async {
    final selected = await _showOptions<AssetLocation?>(
      title: 'Ubicación física',
      options: [
        (null, 'Todas las ubicaciones'),
        for (final value in AssetLocation.values) (value, value.label),
      ],
      selected: _location,
    );
    if (selected == null) return;
    setState(() => _location = selected.value);
  }

  Future<void> _pickRoom(AppState state) async {
    final selected = await _showOptions<String?>(
      title: 'Habitación',
      options: [
        (null, 'Todas las habitaciones'),
        for (final zone in state.zones) (zone.id, zone.name),
      ],
      selected: _roomId,
    );
    if (selected == null) return;
    setState(() => _roomId = selected.value);
  }

  Future<void> _pickSituation() async {
    final selected = await _showOptions<AssetSituation?>(
      title: 'Situación administrativa',
      options: [
        (null, 'Todas las situaciones'),
        for (final value in AssetSituation.values) (value, value.label),
      ],
      selected: _situation,
    );
    if (selected == null) return;
    setState(() => _situation = selected.value);
  }

  Future<void> _pickSort() async {
    final selected = await _showOptions<AssetSort>(
      title: 'Ordenar por',
      options: [
        for (final value in AssetSort.values) (value, _labelForSort(value)),
      ],
      selected: _sort,
      allowNull: false,
    );
    if (selected == null) return;
    setState(() => _sort = selected.value);
  }

  String _labelForSort(AssetSort value) => switch (value) {
    AssetSort.lastDetection => 'Última detección',
    AssetSort.lastMovement => 'Último movimiento',
    AssetSort.expectedReturn => 'Devolución prevista',
    AssetSort.code => 'Código interno',
  };

  Future<_Option<T>?> _showOptions<T>({
    required String title,
    required List<(T, String)> options,
    required T selected,
    bool allowNull = true,
  }) async {
    return showModalBottomSheet<_Option<T>>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final option in options)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(option.$2),
                        trailing: option.$1 == selected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.blue,
                              )
                            : null,
                        onTap: () =>
                            Navigator.pop(context, _Option<T>(option.$1)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openForm() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AssetFormScreen()),
    );
  }

  void _openDetail(Asset asset) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AssetDetailScreen(assetId: asset.id)),
    );
  }
}

class _Option<T> {
  const _Option(this.value);
  final T value;
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon = Icons.expand_more_rounded,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).colorScheme.secondaryContainer
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: active
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              icon,
              size: 16,
              color: active
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
