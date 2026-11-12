import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';
import '../loans/return_loan_dialog.dart';
import '../suppliers/supplier_delivery_screen.dart';
import '../suppliers/supplier_operation_screen.dart';

class RfidSimulatorScreen extends ConsumerStatefulWidget {
  const RfidSimulatorScreen({super.key, this.initialAssetId});

  final String? initialAssetId;

  @override
  ConsumerState<RfidSimulatorScreen> createState() =>
      _RfidSimulatorScreenState();
}

class _RfidSimulatorScreenState extends ConsumerState<RfidSimulatorScreen> {
  String? _assetId;
  String? _accessId;
  String? _readerId;
  String? _zoneId;
  String? _zoneReaderId;
  String? _lastMessage;
  bool _lastSuccess = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(appControllerProvider).requireValue;
    _assetId =
        state.assetById(widget.initialAssetId)?.id ??
        (state.assets.isNotEmpty ? state.assets.first.id : null);
    final access = state.accesses.where((item) => item.configured).toList();
    if (access.isNotEmpty) {
      _accessId = access.first.id;
      _readerId = access.first.readerIds.isNotEmpty
          ? access.first.readerIds.first
          : null;
    }
    final zones = state.zones.where((zone) => zone.active).toList();
    if (zones.isNotEmpty) {
      _zoneId = zones.first.id;
      _zoneReaderId = zones.first.readerIds.isNotEmpty
          ? zones.first.readerIds.first
          : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    final asset = state.assetById(_assetId);
    final access = state.accessById(_accessId);
    final readers = access?.readerIds ?? const <String>[];
    final recent =
        state.movements
            .where((movement) => movement.origin == EventOrigin.simulator)
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      appBar: AppBar(title: const Text('Simulador RFID')),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          child: PageBody(
            maxWidth: 820,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DemoBanner(),
                const SizedBox(height: 14),
                _SourceCard(settings: state.settings, onReset: _resetDemo),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Configurar lectura',
                  subtitle:
                      'El simulador usa el mismo procesador y las mismas reglas '
                      'que una fuente RFID real',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _assetId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Activo'),
                        items: [
                          for (final item in state.assets)
                            DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                '${item.code} · ${item.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() => _assetId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _accessId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Acceso'),
                        items: [
                          for (final item in state.accesses)
                            DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                item.configured
                                    ? item.name
                                    : '${item.name} (sin configurar)',
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _accessId = value;
                          final selected = state.accessById(value);
                          _readerId =
                              selected != null && selected.readerIds.isNotEmpty
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
                            labelText: 'Lector / antena',
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
                      if (asset != null) ...[
                        const SizedBox(height: 14),
                        _SelectedAssetCard(asset: asset, access: access),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Lecturas simuladas',
                  subtitle:
                      'Una lectura repetida no genera un movimiento adicional',
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cross = constraints.maxWidth >= 560 ? 4 : 2;
                      return GridView.count(
                        crossAxisCount: cross,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 9,
                        crossAxisSpacing: 9,
                        childAspectRatio: 1.45,
                        children: [
                          _SimAction(
                            icon: Icons.login_rounded,
                            label: 'Entrada',
                            color: AppColors.success,
                            onTap: _busy ? null : () => _runRead(inbound: true),
                          ),
                          _SimAction(
                            icon: Icons.logout_rounded,
                            label: 'Salida',
                            color: AppColors.warning,
                            onTap: _busy
                                ? null
                                : () => _runRead(inbound: false),
                          ),
                          _SimAction(
                            icon: Icons.repeat_rounded,
                            label: 'Lectura repetida',
                            color: AppColors.blue,
                            onTap: _busy ? null : _runRepeated,
                          ),
                          _SimAction(
                            icon: Icons.help_outline_rounded,
                            label: 'Lectura ambigua',
                            color: AppColors.danger,
                            onTap: _busy ? null : _runAmbiguous,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Sensores internos de habitación',
                  subtitle:
                      'Los sensores de puerta siguen controlando el ingreso y '
                      'egreso de la institución',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _zoneId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Habitación',
                        ),
                        items: [
                          for (final zone in state.zones)
                            DropdownMenuItem(
                              value: zone.id,
                              child: Text(
                                zone.active
                                    ? zone.name
                                    : '${zone.name} (inactiva)',
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _zoneId = value;
                          final zone = state.zoneById(value);
                          _zoneReaderId =
                              zone != null && zone.readerIds.isNotEmpty
                              ? zone.readerIds.first
                              : null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cross = constraints.maxWidth >= 560 ? 3 : 2;
                          return GridView.count(
                            crossAxisCount: cross,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 9,
                            crossAxisSpacing: 9,
                            childAspectRatio: 1.45,
                            children: [
                              _SimAction(
                                icon: Icons.meeting_room_rounded,
                                label: 'Entró a habitación',
                                color: AppColors.teal,
                                onTap: _busy
                                    ? null
                                    : () => _runRoomRead(inbound: true),
                              ),
                              _SimAction(
                                icon: Icons.sensor_door_rounded,
                                label: 'Salió de habitación',
                                color: AppColors.warning,
                                onTap: _busy
                                    ? null
                                    : () => _runRoomRead(inbound: false),
                              ),
                              _SimAction(
                                icon: Icons.help_outline_rounded,
                                label: 'Lectura ambigua interna',
                                color: AppColors.danger,
                                onTap: _busy ? null : _runRoomAmbiguous,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (_lastMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _lastSuccess
                          ? AppColors.successSoft
                          : AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _lastSuccess
                              ? Icons.check_circle_rounded
                              : Icons.info_rounded,
                          color: _lastSuccess
                              ? AppColors.success
                              : AppColors.warning,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _lastMessage!,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: _lastSuccess
                                  ? AppColors.success
                                  : AppColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Operaciones asistidas',
                  subtitle: 'Entrega a proveedor, devolución e intercambio de unidades',
                  child: Column(
                    children: [
                      _OperationRow(
                        icon: Icons.local_shipping_rounded,
                        title: 'Entrega a proveedor',
                        subtitle:
                            'Registra la salida de la unidad seleccionada',
                        onTap: _busy ? null : _supplierDelivery,
                      ),
                      const Divider(height: 18),
                      _OperationRow(
                        icon: Icons.assignment_return_rounded,
                        title: 'Devolución de préstamo',
                        subtitle: 'Cierra un préstamo activo con confirmación',
                        onTap: _busy ? null : _returnLoan,
                      ),
                      const Divider(height: 18),
                      _OperationRow(
                        icon: Icons.swap_horiz_rounded,
                        title: 'Intercambio de unidades',
                        subtitle: 'Recibe unidades distintas a las entregadas',
                        onTap: _busy ? null : _exchange,
                      ),
                      const Divider(height: 18),
                      _OperationRow(
                        icon: Icons.bolt_rounded,
                        title: 'Generar lote de 6 eventos',
                        subtitle:
                            'Alterna salidas y entradas para tres activos',
                        onTap: _busy ? null : _batch,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Últimos eventos simulados',
                  subtitle: '${recent.length} evento(s) de origen simulador',
                  padding: EdgeInsets.zero,
                  child: recent.isEmpty
                      ? const EmptyState(
                          icon: Icons.sensors_off_rounded,
                          title: 'Sin eventos simulados',
                          message:
                              'Usá las acciones de lectura para generar '
                              'movimientos.',
                        )
                      : Column(
                          children: [
                            for (
                              var i = 0;
                              i < recent.length.clamp(0, 6);
                              i++
                            ) ...[
                              if (i > 0) const Divider(),
                              MovementTile(
                                movement: recent[i],
                                assetCode:
                                    state.assetById(recent[i].assetId)?.code ??
                                    recent[i].assetId,
                                accessName: state
                                    .accessById(recent[i].accessId)
                                    ?.name,
                                roomName: state
                                    .zoneById(recent[i].roomId)
                                    ?.name,
                              ),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _resetDemo,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Restablecer datos de demostración'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _runRead({required bool inbound}) async {
    if (_assetId == null) return;
    setState(() => _busy = true);
    final controller = ref.read(appControllerProvider.notifier);
    final result = inbound
        ? await controller.simulateEntry(
            assetId: _assetId!,
            accessId: _accessId ?? '',
            readerId: _readerId ?? '',
          )
        : await controller.simulateExit(
            assetId: _assetId!,
            accessId: _accessId ?? '',
            readerId: _readerId ?? '',
          );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastMessage = result.message;
      _lastSuccess = result.success;
    });
  }

  Future<void> _runRepeated() async {
    if (_assetId == null) return;
    final state = ref.read(appControllerProvider).requireValue;
    final asset = state.assetById(_assetId);
    if (asset == null) return;
    setState(() => _busy = true);
    final result = await ref
        .read(appControllerProvider.notifier)
        .simulateRepeatedRead(
          assetId: _assetId!,
          accessId: _accessId ?? '',
          readerId: _readerId ?? '',
          inbound: !asset.isInside,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastMessage = result.message;
      _lastSuccess = result.success;
    });
  }

  Future<void> _runAmbiguous() async {
    if (_assetId == null) return;
    setState(() => _busy = true);
    final result = await ref
        .read(appControllerProvider.notifier)
        .simulateAmbiguousRead(
          assetId: _assetId!,
          accessId: _accessId ?? '',
          readerId: _readerId ?? '',
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastMessage = result.message;
      _lastSuccess = false;
    });
  }

  Future<void> _runRoomRead({required bool inbound}) async {
    if (_assetId == null) return;
    if (_zoneId == null) {
      setState(() {
        _lastMessage = 'Seleccioná una habitación para simular la lectura.';
        _lastSuccess = false;
      });
      return;
    }
    setState(() => _busy = true);
    final controller = ref.read(appControllerProvider.notifier);
    final result = inbound
        ? await controller.simulateRoomEntry(
            assetId: _assetId!,
            zoneId: _zoneId!,
            readerId: _zoneReaderId ?? '',
          )
        : await controller.simulateRoomExit(
            assetId: _assetId!,
            zoneId: _zoneId!,
            readerId: _zoneReaderId ?? '',
          );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastMessage = result.message;
      _lastSuccess = result.success;
    });
  }

  Future<void> _runRoomAmbiguous() async {
    if (_assetId == null || _zoneId == null) return;
    setState(() => _busy = true);
    final result = await ref
        .read(appControllerProvider.notifier)
        .simulateRoomAmbiguousRead(
          assetId: _assetId!,
          zoneId: _zoneId!,
          readerId: _zoneReaderId ?? '',
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastMessage = result.message;
      _lastSuccess = false;
    });
  }

  Future<void> _supplierDelivery() async {
    if (_assetId == null) return;
    final state = ref.read(appControllerProvider).requireValue;
    final active = state.suppliers.where((item) => item.active).toList();
    if (active.isEmpty) {
      setState(() {
        _lastMessage = 'No hay proveedores activos configurados.';
        _lastSuccess = false;
      });
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierDeliveryScreen(
          initialSupplierId: active.first.id,
          initialAssetIds: [_assetId!],
        ),
      ),
    );
    if (result == true && mounted) {
      setState(() {
        _lastMessage = 'Entrega a proveedor registrada desde el simulador.';
        _lastSuccess = true;
      });
    }
  }

  Future<void> _returnLoan() async {
    final state = ref.read(appControllerProvider).requireValue;
    final loans = state.loans.where((loan) => loan.isOpen).toList();
    if (loans.isEmpty) {
      setState(() {
        _lastMessage = 'No hay préstamos activos para devolver.';
        _lastSuccess = false;
      });
      return;
    }
    final loan = await showModalBottomSheet<Loan>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Seleccionar préstamo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in loans)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          state.assetById(item.assetId)?.code ?? item.assetId,
                        ),
                        subtitle: Text(
                          '${item.borrower} · ${formatDate(item.dueAt)}',
                        ),
                        onTap: () => Navigator.pop(context, item),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (loan == null || !mounted) return;
    final result = await showReturnLoanDialog(
      context,
      ref,
      loan,
      state.assetById(loan.assetId)?.code ?? '',
    );
    if (result != null && mounted) {
      setState(() {
        _lastMessage = result.message;
        _lastSuccess = result.success;
      });
    }
  }

  Future<void> _exchange() async {
    final state = ref.read(appControllerProvider).requireValue;
    final options = state.supplierOperations
        .where(
          (operation) =>
              operation.deliveredAt != null &&
              operation.status != SupplierOperationStatus.completed,
        )
        .toList();
    if (options.isEmpty) {
      setState(() {
        _lastMessage =
            'No hay operaciones de proveedor abiertas para intercambiar.';
        _lastSuccess = false;
      });
      return;
    }
    final operation = await showModalBottomSheet<SupplierOperation>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Operación a completar',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final item in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    state.supplierById(item.supplierId)?.name ?? 'Proveedor',
                  ),
                  subtitle: Text(
                    '${item.pendingAssetIds.length} pendiente(s) · '
                    '${item.reason}',
                  ),
                  onTap: () => Navigator.pop(context, item),
                ),
            ],
          ),
        ),
      ),
    );
    if (operation == null || !mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiveSupplierScreen(operationId: operation.id),
      ),
    );
    if (result == true && mounted) {
      setState(() {
        _lastMessage = 'Recepción o intercambio registrado.';
        _lastSuccess = true;
      });
    }
  }

  Future<void> _batch() async {
    final state = ref.read(appControllerProvider).requireValue;
    final candidates = state.assets
        .where(
          (asset) =>
              asset.situation != AssetSituation.onLoan &&
              asset.situation != AssetSituation.atSupplier &&
              (asset.location == AssetLocation.inside ||
                  asset.location == AssetLocation.outside),
        )
        .take(3)
        .toList();
    if (candidates.isEmpty) return;
    setState(() => _busy = true);
    var generated = 0;
    var last = '';
    for (final asset in candidates) {
      final wasInside = asset.isInside;
      final controller = ref.read(appControllerProvider.notifier);
      final first = wasInside
          ? await controller.simulateExit(
              assetId: asset.id,
              accessId: _accessId ?? '',
              readerId: _readerId ?? '',
            )
          : await controller.simulateEntry(
              assetId: asset.id,
              accessId: _accessId ?? '',
              readerId: _readerId ?? '',
            );
      final second = wasInside
          ? await controller.simulateEntry(
              assetId: asset.id,
              accessId: _accessId ?? '',
              readerId: _readerId ?? '',
            )
          : await controller.simulateExit(
              assetId: asset.id,
              accessId: _accessId ?? '',
              readerId: _readerId ?? '',
            );
      if (first.success) generated += 1;
      if (second.success) generated += 1;
      last = second.message;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastMessage =
          'Lote generado: $generated movimiento(s) confirmado(s). $last';
      _lastSuccess = generated > 0;
    });
  }

  Future<void> _resetDemo() async {
    final confirmed = await confirmAction(
      context,
      title: 'Restablecer demostración',
      message:
          'Se eliminarán todos los cambios locales y se restaurará el '
          'conjunto inicial de 50 activos. Esta acción no se puede deshacer.',
      confirmLabel: 'Restablecer',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final result = await ref.read(appControllerProvider.notifier).resetDemo();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastMessage = result.message;
      _lastSuccess = result.success;
    });
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.settings, required this.onReset});

  final AppSettings settings;
  final Future<void> Function() onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.settings_input_antenna_rounded,
              color: AppColors.warning,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.rfidSourceName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Estado: ${settings.rfidSourceStatus} · Sin hardware '
                  'conectado · Agrupación ${settings.dedupeWindowSeconds}s',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          const StatusPill(
            label: 'SIMULADO',
            color: AppColors.warning,
            compact: true,
          ),
          IconButton(
            tooltip: 'Restablecer demostración',
            onPressed: () => onReset(),
            icon: const Icon(
              Icons.restart_alt_rounded,
              color: AppColors.muted,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedAssetCard extends StatelessWidget {
  const _SelectedAssetCard({required this.asset, required this.access});

  final Asset asset;
  final AccessPoint? access;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              LocationBadge(location: asset.location, compact: true),
              const SizedBox(width: 7),
              SituationBadge(situation: asset.situation, compact: true),
              const Spacer(),
              Text(
                asset.code,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.wifi_tethering_rounded,
                size: 14,
                color: AppColors.muted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  asset.rfidEpc,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppColors.muted,
              ),
              const SizedBox(width: 5),
              Text(
                'Última detección: ${relativeTime(asset.lastDetectionAt)}',
                style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
              if (access != null) ...[
                const Spacer(),
                Flexible(
                  child: Text(
                    access!.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SimAction extends StatelessWidget {
  const _SimAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.infoSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: AppColors.blue, size: 19),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontSize: 12.5),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
