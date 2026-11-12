import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';
import '../loans/loan_form_screen.dart';
import '../loans/return_loan_dialog.dart';
import '../rfid/rfid_simulator_screen.dart';
import 'asset_form_screen.dart';

class AssetDetailScreen extends ConsumerWidget {
  const AssetDetailScreen({super.key, required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).requireValue;
    final asset = state.assetById(assetId);
    if (asset == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activo')),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Activo no encontrado',
          message: 'El activo pudo haber sido eliminado del inventario.',
        ),
      );
    }
    final category = state.categoryById(asset.categoryId);
    final movements = state.movementsForAsset(asset.id);
    final loan = state.openLoanForAsset(asset.id);
    final supplier = state.supplierById(asset.supplierId);
    final access = state.accessById(asset.lastAccessId);
    final reader = asset.lastReaderId;
    final room = state.zoneById(asset.roomId);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ficha del activo'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AssetFormScreen(asset: asset)),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          child: PageBody(
            maxWidth: 820,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _IdentityCard(
                  asset: asset,
                  categoryName: category?.name ?? 'Sin categoría',
                  onSimulate: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RfidSimulatorScreen(initialAssetId: asset.id),
                    ),
                  ),
                  onLoan:
                      asset.isInside &&
                          asset.situation != AssetSituation.onLoan &&
                          asset.situation != AssetSituation.atSupplier
                      ? () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  LoanFormScreen(initialAssetId: asset.id),
                            ),
                          );
                          if (result == true && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Préstamo registrado.'),
                              ),
                            );
                          }
                        }
                      : null,
                  onCorrection: () => _openCorrection(context, ref, asset),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Estado actual',
                  subtitle:
                      'La última detección se mantiene separada del último '
                      'movimiento confirmado',
                  child: Column(
                    children: [
                      InfoRow(
                        label: 'Ubicación',
                        value: asset.location.label,
                        icon: Icons.place_outlined,
                        valueColor: locationColor(asset.location),
                      ),
                      InfoRow(
                        label: 'Habitación',
                        value: room == null
                            ? (asset.isInside
                                  ? 'Dentro, sin habitación asignada'
                                  : 'Sin habitación')
                            : '${room.name} · ${room.description}',
                        icon: Icons.meeting_room_outlined,
                        valueColor: room == null
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : AppColors.teal,
                      ),
                      InfoRow(
                        label: 'Situación',
                        value: asset.situation.label,
                        icon: Icons.assignment_outlined,
                        valueColor: situationColor(asset.situation),
                      ),
                      InfoRow(
                        label: 'Estado operativo',
                        value: asset.operationalStatus.label,
                        icon: Icons.build_circle_outlined,
                      ),
                      const Divider(height: 18),
                      InfoRow(
                        label: 'Última detección',
                        value: asset.lastDetectionAt == null
                            ? 'Sin registros'
                            : '${formatDateTime(asset.lastDetectionAt)} · '
                                  '${relativeTime(asset.lastDetectionAt, now: now)}',
                        icon: Icons.sensors_rounded,
                      ),
                      InfoRow(
                        label: 'Última entrada',
                        value: formatDateTime(asset.lastEntryAt),
                        icon: Icons.login_rounded,
                      ),
                      InfoRow(
                        label: 'Último egreso',
                        value: formatDateTime(asset.lastExitAt),
                        icon: Icons.logout_rounded,
                      ),
                      InfoRow(
                        label: 'Último movimiento',
                        value: formatDateTime(asset.lastMovementAt),
                        icon: Icons.route_rounded,
                      ),
                      InfoRow(
                        label: 'Últ. ingreso habitación',
                        value: formatDateTime(asset.lastRoomEntryAt),
                        icon: Icons.login_rounded,
                      ),
                      InfoRow(
                        label: 'Últ. salida habitación',
                        value: formatDateTime(asset.lastRoomExitAt),
                        icon: Icons.logout_rounded,
                      ),
                      InfoRow(
                        label: 'Últ. detección interna',
                        value: formatDateTime(asset.lastRoomDetectionAt),
                        icon: Icons.sensors_rounded,
                      ),
                      InfoRow(
                        label: 'Último acceso',
                        value: access == null
                            ? 'Sin registros'
                            : '${access.name} · ${access.description}',
                        icon: Icons.door_front_door_outlined,
                      ),
                      InfoRow(
                        label: 'Último lector',
                        value: reader ?? 'Sin registros',
                        icon: Icons.settings_input_antenna_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _AssignmentCard(
                  state: state,
                  asset: asset,
                  loan: loan,
                  supplier: supplier,
                  onReturn: loan == null
                      ? null
                      : () async {
                          final result = await showReturnLoanDialog(
                            context,
                            ref,
                            loan,
                            asset.code,
                          );
                          if (result != null && context.mounted) {
                            showResultMessage(context, result);
                          }
                        },
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Historial de movimientos',
                  subtitle:
                      '${movements.length} evento(s) · el historial no se '
                      'sobrescribe',
                  padding: EdgeInsets.zero,
                  child: movements.isEmpty
                      ? const EmptyState(
                          icon: Icons.history_rounded,
                          title: 'Sin registros',
                          message:
                              'Este activo todavía no tiene movimientos '
                              'registrados.',
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < movements.length; i++) ...[
                              if (i > 0) const Divider(),
                              MovementTile(
                                movement: movements[i],
                                assetCode: asset.code,
                                accessName: state
                                    .accessById(movements[i].accessId)
                                    ?.name,
                                roomName: state
                                    .zoneById(movements[i].roomId)
                                    ?.name,
                                supplierName: state
                                    .supplierById(movements[i].supplierId)
                                    ?.name,
                                onTap: () => _showEventDetails(
                                  context,
                                  ref,
                                  movements[i],
                                  asset,
                                  state,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AssetFormScreen(asset: asset),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar datos'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _openCorrection(context, ref, asset),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Corrección'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCorrection(
    BuildContext context,
    WidgetRef ref,
    Asset asset,
  ) async {
    final result = await showModalBottomSheet<ActionResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CorrectionSheet(asset: asset, ref: ref),
    );
    if (result != null && context.mounted) showResultMessage(context, result);
  }

  Future<void> _showEventDetails(
    BuildContext context,
    WidgetRef ref,
    MovementEvent movement,
    Asset asset,
    AppState state,
  ) async {
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
              const SizedBox(height: 4),
              Text(
                '${asset.code} · ${formatDateTime(movement.timestamp)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              InfoRow(
                label: 'ID del evento',
                value: movement.id,
                icon: Icons.tag_rounded,
              ),
              InfoRow(
                label: 'Origen',
                value: movement.origin.label,
                icon: Icons.input_rounded,
              ),
              InfoRow(
                label: 'Estado',
                value: movement.status.label,
                icon: Icons.verified_outlined,
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
                label: 'Habitación',
                value: state.zoneById(movement.roomId)?.name ?? 'Sin registros',
                icon: Icons.meeting_room_outlined,
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
              if (movement.alertMessage != null)
                InfoRow(
                  label: 'Observación',
                  value: movement.alertMessage!,
                  icon: Icons.warning_amber_rounded,
                  valueColor: AppColors.warning,
                ),
              if (movement.notes.isNotEmpty)
                InfoRow(
                  label: 'Notas',
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
                              .resolvePendingEvent(movement.id, approve: false);
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
                                notes: 'Evento aprobado desde la ficha del activo.',
                              );
                          if (context.mounted) {
                            Navigator.pop(context);
                            showResultMessage(context, result);
                          }
                        },
                        child: const Text('Aprobar evento'),
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

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.asset,
    required this.categoryName,
    required this.onSimulate,
    required this.onLoan,
    required this.onCorrection,
  });

  final Asset asset;
  final String categoryName;
  final VoidCallback onSimulate;
  final VoidCallback? onLoan;
  final VoidCallback onCorrection;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navyMid, AppColors.navyDark],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2506152F),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  asset.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              const AppMark(size: 34, light: true),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            asset.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            categoryName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              LocationBadge(location: asset.location),
              const SizedBox(width: 8),
              SituationBadge(situation: asset.situation),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.wifi_tethering_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    asset.rfidEpc,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Text(
                  'EPC',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.sensors_rounded,
                  label: 'Simular lectura',
                  onTap: onSimulate,
                ),
              ),
              if (onLoan != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.handshake_rounded,
                    label: 'Prestar',
                    onTap: onLoan!,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.fact_check_outlined,
                  label: 'Corrección',
                  onTap: onCorrection,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 19),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.state,
    required this.asset,
    required this.loan,
    required this.supplier,
    required this.onReturn,
  });

  final AppState state;
  final Asset asset;
  final Loan? loan;
  final Supplier? supplier;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    if (loan == null &&
        supplier == null &&
        asset.responsible == null &&
        asset.expectedReturnAt == null) {
      return SectionCard(
        title: 'Préstamos y proveedores',
        child: Text(
          'Sin asignaciones activas ni fechas de devolución previstas.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final activeLoan = loan;
    final loanStatus = activeLoan?.effectiveStatus(DateTime.now());
    return SectionCard(
      title: 'Préstamos y proveedores',
      subtitle: 'Responsables, motivos y devoluciones',
      child: Column(
        children: [
          if (activeLoan != null) ...[
            Row(
              children: [
                const Icon(
                  Icons.handshake_rounded,
                  size: 18,
                  color: AppColors.purple,
                ),
                const SizedBox(width: 8),
                Text(
                  'Préstamo activo',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontSize: 13),
                ),
                const Spacer(),
                StatusPill(
                  label: loanStatus?.label ?? 'Activo',
                  color: loanStatus == LoanStatus.overdue
                      ? AppColors.danger
                      : AppColors.purple,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 8),
            InfoRow(
              label: 'Responsable',
              value: activeLoan.borrower,
              icon: Icons.person_outline_rounded,
            ),
            InfoRow(
              label: 'Fecha de entrega',
              value: formatDateTime(activeLoan.deliveredAt),
              icon: Icons.outbox_rounded,
            ),
            InfoRow(
              label: 'Devolución prevista',
              value: formatDateTime(activeLoan.dueAt),
              icon: Icons.event_rounded,
              valueColor: loanStatus == LoanStatus.overdue
                  ? AppColors.danger
                  : null,
            ),
            InfoRow(
              label: 'Motivo',
              value: activeLoan.reason.isEmpty
                  ? 'Sin registros'
                  : activeLoan.reason,
              icon: Icons.notes_rounded,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onReturn,
                icon: const Icon(Icons.assignment_return_rounded),
                label: const Text('Registrar devolución'),
              ),
            ),
          ] else ...[
            if (supplier != null) ...[
              InfoRow(
                label: 'Proveedor',
                value: supplier!.name,
                icon: Icons.local_shipping_outlined,
                valueColor: AppColors.warning,
              ),
              InfoRow(
                label: 'Servicio',
                value: supplier!.serviceType,
                icon: Icons.build_outlined,
              ),
            ],
            if (asset.responsible != null)
              InfoRow(
                label: 'Responsable',
                value: asset.responsible!,
                icon: Icons.person_outline_rounded,
              ),
            if (asset.expectedReturnAt != null)
              InfoRow(
                label: 'Devolución prevista',
                value: formatDateTime(asset.expectedReturnAt),
                icon: Icons.event_rounded,
                valueColor: asset.expectedReturnAt!.isBefore(DateTime.now())
                    ? AppColors.danger
                    : null,
              ),
            if (supplier != null)
              InfoRow(
                label: 'Operaciones',
                value:
                    '${state.supplierOperations.where((op) => op.supplierId == supplier!.id).length} '
                    'registrada(s)',
                icon: Icons.receipt_long_outlined,
              ),
          ],
        ],
      ),
    );
  }
}

class _CorrectionSheet extends StatefulWidget {
  const _CorrectionSheet({required this.asset, required this.ref});

  final Asset asset;
  final WidgetRef ref;

  @override
  State<_CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends State<_CorrectionSheet> {
  late AssetLocation _location;
  late AssetSituation _situation;
  late OperationalStatus _operational;
  String? _roomId;
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _location = widget.asset.location;
    _situation = widget.asset.situation;
    _operational = widget.asset.operationalStatus;
    _roomId = widget.asset.roomId;
  }

  @override
  void dispose() {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Corrección administrativa',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.asset.code} · queda registrada en el historial',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AssetLocation>(
                initialValue: _location,
                decoration: const InputDecoration(
                  labelText: 'Ubicación física',
                ),
                items: [
                  for (final value in AssetLocation.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _location = value;
                      if (value != AssetLocation.inside) _roomId = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _roomId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Habitación',
                  helperText: 'Solo aplica dentro de las instalaciones',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sin habitación asignada'),
                  ),
                  for (final zone
                      in widget.ref
                          .read(appControllerProvider)
                          .requireValue
                          .zones)
                    DropdownMenuItem<String?>(
                      value: zone.id,
                      child: Text(zone.name),
                    ),
                ],
                onChanged: _location == AssetLocation.inside
                    ? (value) => setState(() => _roomId = value)
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AssetSituation>(
                initialValue: _situation,
                decoration: const InputDecoration(
                  labelText: 'Situación administrativa',
                ),
                items: [
                  for (final value in AssetSituation.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _situation = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<OperationalStatus>(
                initialValue: _operational,
                decoration: const InputDecoration(
                  labelText: 'Estado operativo',
                ),
                items: [
                  for (final value in OperationalStatus.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _operational = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Justificación *',
                  hintText: 'Explicá por qué se corrige el estado',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        if (_notes.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.danger,
                              content: Text(
                                'La corrección requiere una justificación.',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() => _saving = true);
                        final result = await widget.ref
                            .read(appControllerProvider.notifier)
                            .applyCorrection(
                              assetId: widget.asset.id,
                              location: _location,
                              situation: _situation,
                              operationalStatus: _operational,
                              roomId: _location == AssetLocation.inside
                                  ? _roomId
                                  : null,
                              notes: _notes.text.trim(),
                            );
                        if (!context.mounted) return;
                        setState(() => _saving = false);
                        Navigator.pop(context, result);
                      },
                icon: const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Guardando...' : 'Guardar corrección'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
