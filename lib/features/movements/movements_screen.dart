import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';

enum _DateRange { today, week, month, all }

class MovementsScreen extends ConsumerStatefulWidget {
  const MovementsScreen({
    super.key,
    this.initialStatus,
    this.initialAssetId,
  });

  final MovementStatus? initialStatus;
  final String? initialAssetId;

  @override
  ConsumerState<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends ConsumerState<MovementsScreen> {
  late final TextEditingController _search;
  MovementType? _type;
  MovementStatus? _status;
  String? _supplierId;
  _DateRange _range = _DateRange.all;
  String? _assetId;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController()..addListener(() => setState(() {}));
    _status = widget.initialStatus;
    _assetId = widget.initialAssetId;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    final now = DateTime.now();
    final events = _filtered(state);
    final today = state.movements
        .where(
          (movement) =>
              movement.timestamp.year == now.year &&
              movement.timestamp.month == now.month &&
              movement.timestamp.day == now.day,
        )
        .length;
    final pending = state.movements
        .where((movement) => movement.status == MovementStatus.pendingReview)
        .length;
    final asset = state.assetById(_assetId);

    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos')),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          child: PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Summary(
                        label: 'Eventos',
                        value: '${state.movements.length}',
                        icon: Icons.route_rounded,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _Summary(
                        label: 'Hoy',
                        value: '$today',
                        icon: Icons.today_rounded,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _Summary(
                        label: 'Por revisar',
                        value: '$pending',
                        icon: Icons.fact_check_outlined,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (asset != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.infoSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.filter_alt_rounded,
                          size: 15,
                          color: AppColors.blue,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Filtrando ${asset.code} · ${asset.name}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _assetId = null),
                          icon: const Icon(Icons.close_rounded, size: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SearchInput(
                  controller: _search,
                  hint: 'Buscar por activo, responsable o motivo',
                  onChanged: (_) => setState(() {}),
                  onClear: () => setState(_search.clear),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterButton(
                      label: _type?.label ?? 'Tipo',
                      active: _type != null,
                      onTap: () async {
                        final option = await _pickOption<MovementType?>(
                          title: 'Tipo de movimiento',
                          options: [
                            (null, 'Todos los tipos'),
                            for (final value in MovementType.values)
                              (value, value.label),
                          ],
                          selected: _type,
                        );
                        if (option == null) return;
                        setState(() => _type = option.value);
                      },
                    ),
                    _FilterButton(
                      label: _status?.label ?? 'Estado',
                      active: _status != null,
                      onTap: () async {
                        final option = await _pickOption<MovementStatus?>(
                          title: 'Estado del evento',
                          options: [
                            (null, 'Todos los estados'),
                            for (final value in MovementStatus.values)
                              (value, value.label),
                          ],
                          selected: _status,
                        );
                        if (option == null) return;
                        setState(() => _status = option.value);
                      },
                    ),
                    _FilterButton(
                      label: _rangeLabel,
                      active: _range != _DateRange.all,
                      icon: Icons.date_range_rounded,
                      onTap: () async {
                        final option = await _pickOption<_DateRange>(
                          title: 'Rango de fechas',
                          options: [
                            (_DateRange.today, 'Hoy'),
                            (_DateRange.week, 'Últimos 7 días'),
                            (_DateRange.month, 'Últimos 30 días'),
                            (_DateRange.all, 'Todo el historial'),
                          ],
                          selected: _range,
                        );
                        if (option == null) return;
                        setState(() => _range = option.value);
                      },
                    ),
                    _FilterButton(
                      label: _supplierId == null
                          ? 'Proveedor'
                          : (state.supplierById(_supplierId)?.name ??
                                'Proveedor'),
                      active: _supplierId != null,
                      onTap: () async {
                        final option = await _pickOption<String?>(
                          title: 'Proveedor',
                          options: [
                            (null, 'Todos los proveedores'),
                            for (final supplier in state.suppliers)
                              (supplier.id, supplier.name),
                          ],
                          selected: _supplierId,
                        );
                        if (option == null) return;
                        setState(() => _supplierId = option.value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${events.length} evento(s) encontrados',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                if (events.isEmpty)
                  const SectionCard(
                    child: EmptyState(
                      icon: Icons.route_outlined,
                      title: 'Sin movimientos',
                      message:
                          'No hay eventos que coincidan con los filtros '
                          'seleccionados.',
                    ),
                  )
                else
                  _MovementList(
                    events: events,
                    state: state,
                    onTap: (movement) => _showDetails(context, state, movement),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<MovementEvent> _filtered(AppState state) {
    final query = _search.text.trim().toLowerCase();
    final now = DateTime.now();
    final start = switch (_range) {
      _DateRange.today => DateTime(now.year, now.month, now.day),
      _DateRange.week => now.subtract(const Duration(days: 7)),
      _DateRange.month => now.subtract(const Duration(days: 30)),
      _DateRange.all => null,
    };
    final result = state.movements.where((movement) {
      if (_assetId != null && movement.assetId != _assetId) return false;
      if (_type != null && movement.type != _type) return false;
      if (_status != null && movement.status != _status) return false;
      if (_supplierId != null && movement.supplierId != _supplierId) {
        return false;
      }
      if (start != null && movement.timestamp.isBefore(start)) return false;
      if (query.isEmpty) return true;
      final asset = state.assetById(movement.assetId);
      return (asset?.code.toLowerCase().contains(query) ?? false) ||
          (asset?.name.toLowerCase().contains(query) ?? false) ||
          movement.reason.toLowerCase().contains(query) ||
          movement.notes.toLowerCase().contains(query) ||
          (movement.responsible?.toLowerCase().contains(query) ?? false);
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }

  String get _rangeLabel => switch (_range) {
    _DateRange.today => 'Hoy',
    _DateRange.week => '7 días',
    _DateRange.month => '30 días',
    _DateRange.all => 'Fecha',
  };

  Future<_Option<T>?> _pickOption<T>({
    required String title,
    required List<(T, String)> options,
    required T selected,
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
                        onTap: () => Navigator.pop(
                          context,
                          _Option<T>(option.$1),
                        ),
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

  Future<void> _showDetails(
    BuildContext context,
    AppState state,
    MovementEvent movement,
  ) async {
    final asset = state.assetById(movement.assetId);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                movement.type.label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 3),
              Text(
                '${asset?.code ?? movement.assetId} · '
                '${formatDateTime(movement.timestamp)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              InfoRow(
                label: 'ID del evento',
                value: movement.id,
                icon: Icons.tag_rounded,
              ),
              InfoRow(
                label: 'Activo',
                value: asset == null
                    ? movement.assetId
                    : '${asset.code} · ${asset.name}',
                icon: Icons.inventory_2_outlined,
              ),
              InfoRow(
                label: 'Fecha y hora',
                value: formatDateTime(movement.timestamp),
                icon: Icons.schedule_rounded,
              ),
              InfoRow(
                label: 'Origen',
                value: movement.origin.label,
                icon: Icons.input_rounded,
              ),
              InfoRow(
                label: 'Acceso',
                value:
                    state.accessById(movement.accessId)?.name ??
                    'Sin registros',
                icon: Icons.door_front_door_outlined,
              ),
              InfoRow(
                label: 'Lector',
                value: movement.readerId ?? 'Sin registros',
                icon: Icons.settings_input_antenna_rounded,
              ),
              InfoRow(
                label: 'Responsable',
                value: movement.responsible ?? 'Sin registros',
                icon: Icons.person_outline_rounded,
              ),
              InfoRow(
                label: 'Proveedor',
                value:
                    state.supplierById(movement.supplierId)?.name ??
                    'Sin registros',
                icon: Icons.local_shipping_outlined,
              ),
              InfoRow(
                label: 'Motivo',
                value: movement.reason.isEmpty
                    ? 'Sin registros'
                    : movement.reason,
                icon: Icons.notes_rounded,
              ),
              InfoRow(
                label: 'Estado',
                value: movement.status.label,
                icon: Icons.verified_outlined,
                valueColor: movement.status == MovementStatus.confirmed
                    ? AppColors.success
                    : AppColors.warning,
              ),
              if (movement.alertMessage != null)
                InfoRow(
                  label: 'Alerta',
                  value: movement.alertMessage!,
                  icon: Icons.warning_amber_rounded,
                  valueColor: AppColors.warning,
                ),
              if (movement.notes.isNotEmpty)
                InfoRow(
                  label: 'Observaciones',
                  value: movement.notes,
                  icon: Icons.description_outlined,
                ),
              if (movement.status == MovementStatus.pendingReview) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final result = await ref
                              .read(appControllerProvider.notifier)
                              .resolvePendingEvent(
                                movement.id,
                                approve: false,
                              );
                          if (context.mounted) {
                            Navigator.pop(context);
                            showResultMessage(context, result);
                          }
                        },
                        child: const Text('Rechazar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final result = await ref
                              .read(appControllerProvider.notifier)
                              .resolvePendingEvent(
                                movement.id,
                                approve: true,
                                notes:
                                    'Evento aprobado desde el historial.',
                              );
                          if (context.mounted) {
                            Navigator.pop(context);
                            showResultMessage(context, result);
                          }
                        },
                        child: const Text('Aprobar'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementList extends StatelessWidget {
  const _MovementList({
    required this.events,
    required this.state,
    required this.onTap,
  });

  final List<MovementEvent> events;
  final AppState state;
  final ValueChanged<MovementEvent> onTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    String? currentDay;
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      final day = formatDate(event.timestamp);
      if (day != currentDay) {
        currentDay = day;
        if (i > 0) children.add(const SizedBox(height: 12));
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(
              day,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 12,
                color: AppColors.muted,
              ),
            ),
          ),
        );
      }
      final asset = state.assetById(event.assetId);
      children.add(
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: MovementTile(
            movement: event,
            assetCode: asset?.code ?? event.assetId,
            accessName: state.accessById(event.accessId)?.name,
            supplierName: state.supplierById(event.supplierId)?.name,
            onTap: () => onTap(event),
          ),
        ),
      );
    }
    return Column(children: children);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
          color: active ? AppColors.infoSoft : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.blue : AppColors.border,
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
                color: active ? AppColors.navy : AppColors.text,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              icon,
              size: 16,
              color: active ? AppColors.navy : AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _Option<T> {
  const _Option(this.value);
  final T value;
}
