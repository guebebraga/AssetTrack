import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ids.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';
import '../assets/asset_detail_screen.dart';

class SupplierOperationScreen extends ConsumerWidget {
  const SupplierOperationScreen({super.key, required this.operationId});

  final String operationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).requireValue;
    final operation = state.operationById(operationId);
    if (operation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Operación')),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Operación no encontrada',
        ),
      );
    }
    final supplier = state.supplierById(operation.supplierId);
    final color = operationColor(operation.status);
    final pending = operation.pendingAssetIds;

    return Scaffold(
      appBar: AppBar(title: const Text('Operación de proveedor')),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          child: PageBody(
            maxWidth: 820,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: color,
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supplier?.name ?? 'Proveedor',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontSize: 18),
                                ),
                                Text(
                                  operation.reason.isEmpty
                                      ? 'Operación sin motivo especificado'
                                      : operation.reason,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          StatusPill(
                            label: operation.status.label,
                            color: color,
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      InfoRow(
                        label: 'ID operación',
                        value: operation.id,
                        icon: Icons.tag_rounded,
                      ),
                      InfoRow(
                        label: 'Creada',
                        value: formatDateTime(operation.createdAt),
                        icon: Icons.schedule_rounded,
                      ),
                      InfoRow(
                        label: 'Entregada',
                        value: formatDateTime(operation.deliveredAt),
                        icon: Icons.local_shipping_outlined,
                      ),
                      InfoRow(
                        label: 'Retorno previsto',
                        value: formatDateTime(operation.dueAt),
                        icon: Icons.event_rounded,
                        valueColor:
                            operation.dueAt != null &&
                                operation.dueAt!.isBefore(DateTime.now()) &&
                                operation.status !=
                                    SupplierOperationStatus.completed
                            ? AppColors.danger
                            : null,
                      ),
                      InfoRow(
                        label: 'Última recepción',
                        value: formatDateTime(operation.receivedAt),
                        icon: Icons.inventory_rounded,
                      ),
                      if (operation.notes.isNotEmpty)
                        InfoRow(
                          label: 'Observaciones',
                          value: operation.notes,
                          icon: Icons.description_outlined,
                        ),
                      if (operation.isExchange)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: StatusPill(
                            label: 'Intercambio de unidades',
                            color: AppColors.purple,
                            icon: Icons.swap_horiz_rounded,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Activos entregados',
                  subtitle:
                      '${operation.deliveredAssetIds.length} unidad(es) · '
                      '${pending.length} pendiente(s) de retorno',
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (
                        var i = 0;
                        i < operation.deliveredAssetIds.length;
                        i++
                      ) ...[
                        if (i > 0) const Divider(),
                        _OperationAssetRow(
                          asset: state.assetById(
                            operation.deliveredAssetIds[i],
                          ),
                          received: operation.receivedAssetIds.contains(
                            operation.deliveredAssetIds[i],
                          ),
                          onTap: () => _openAsset(
                            context,
                            operation.deliveredAssetIds[i],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (operation.isExchange) ...[
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Unidades recibidas en intercambio',
                    subtitle:
                        'No coinciden con las unidades entregadas y mantienen '
                        'su propia trazabilidad',
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (
                          var i = 0;
                          i < operation.receivedAssetIds.length;
                          i++
                        ) ...[
                          if (i > 0) const Divider(),
                          _OperationAssetRow(
                            asset: state.assetById(
                              operation.receivedAssetIds[i],
                            ),
                            received: true,
                            isExchange: !operation.deliveredAssetIds.contains(
                              operation.receivedAssetIds[i],
                            ),
                            onTap: () => _openAsset(
                              context,
                              operation.receivedAssetIds[i],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
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
                        Icons.info_outline_rounded,
                        color: AppColors.blue,
                        size: 18,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'El sistema no asume que la operación está completa '
                          'porque ingresó la misma cantidad de unidades. Las '
                          'unidades entregadas que no se reciban quedan '
                          'pendientes hasta registrar otro destino explícito.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 11,
                                color: AppColors.navy,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (operation.deliveredAt == null)
                  FilledButton.icon(
                    onPressed: () async {
                      final result = await ref
                          .read(appControllerProvider.notifier)
                          .deliverSupplierOperation(operation.id);
                      if (context.mounted) {
                        showResultMessage(context, result);
                      }
                    },
                    icon: const Icon(Icons.local_shipping_rounded),
                    label: const Text('Registrar salida de la operación'),
                  ),
                if (operation.deliveredAt != null &&
                    operation.status != SupplierOperationStatus.completed)
                  FilledButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReceiveSupplierScreen(
                            operationId: operation.id,
                          ),
                        ),
                      );
                      if (result == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Recepción registrada.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.move_to_inbox_rounded),
                    label: Text(
                      pending.isEmpty
                          ? 'Registrar otras unidades recibidas'
                          : 'Registrar recepción (${pending.length} pendientes)',
                    ),
                  ),
                if (operation.deliveredAt != null &&
                    operation.status != SupplierOperationStatus.completed &&
                    pending.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await confirmAction(
                        context,
                        title: 'Cerrar operación con pendientes',
                        message:
                            'Las ${pending.length} unidades no recibidas '
                            'mantendrán su estado en poder del proveedor y su '
                            'trazabilidad. La operación se cerrará '
                            'explícitamente.\n\n¿Continuar?',
                        confirmLabel: 'Cerrar operación',
                      );
                      if (!confirmed || !context.mounted) return;
                      final result = await ref
                          .read(appControllerProvider.notifier)
                          .completeSupplierOperation(
                            operation.id,
                            notes:
                                'Cierre explícito con unidades no retornadas. '
                                'Las unidades permanecen trazadas en poder del '
                                'proveedor.',
                          );
                      if (context.mounted) {
                        showResultMessage(context, result);
                      }
                    },
                    icon: const Icon(Icons.lock_clock_rounded),
                    label: const Text('Cerrar con pendientes'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAsset(BuildContext context, String assetId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssetDetailScreen(assetId: assetId),
      ),
    );
  }
}

class _OperationAssetRow extends StatelessWidget {
  const _OperationAssetRow({
    required this.asset,
    required this.received,
    required this.onTap,
    this.isExchange = false,
  });

  final Asset? asset;
  final bool received;
  final VoidCallback onTap;
  final bool isExchange;

  @override
  Widget build(BuildContext context) {
    final color = received ? AppColors.success : AppColors.warning;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                received ? Icons.check_rounded : Icons.schedule_rounded,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset?.code ?? 'Activo no disponible',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    asset?.name ?? 'Sin datos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (isExchange)
              const StatusPill(
                label: 'Intercambio',
                color: AppColors.purple,
                compact: true,
              )
            else
              StatusPill(
                label: received ? 'Recibido' : 'Pendiente',
                color: color,
                compact: true,
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class ReceiveSupplierScreen extends ConsumerStatefulWidget {
  const ReceiveSupplierScreen({super.key, required this.operationId});

  final String operationId;

  @override
  ConsumerState<ReceiveSupplierScreen> createState() =>
      _ReceiveSupplierScreenState();
}

class _ReceiveSupplierScreenState extends ConsumerState<ReceiveSupplierScreen> {
  final _search = TextEditingController();
  final Set<String> _selected = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    final operation = state.operationById(widget.operationId);
    if (operation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recepción')),
        body: const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Operación no encontrada',
        ),
      );
    }
    final supplier = state.supplierById(operation.supplierId);
    final pending = operation.pendingAssetIds
        .map((id) => state.assetById(id))
        .whereType<Asset>()
        .toList();
    final exchangeCandidates = state.assets
        .where(
          (asset) =>
              asset.location != AssetLocation.inside &&
              asset.situation != AssetSituation.atSupplier &&
              !operation.deliveredAssetIds.contains(asset.id) &&
              !operation.receivedAssetIds.contains(asset.id),
        )
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final query = _search.text.trim().toLowerCase();

    bool matches(Asset asset) =>
        query.isEmpty ||
        asset.code.toLowerCase().contains(query) ||
        asset.name.toLowerCase().contains(query) ||
        asset.rfidEpc.toLowerCase().contains(query);

    final pendingFiltered = pending.where(matches).toList();
    final exchangeFiltered = exchangeCandidates.where(matches).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Recepción de proveedor')),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          child: PageBody(
            maxWidth: 820,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.swap_horiz_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '${supplier?.name ?? 'Proveedor'}: podés recibir las '
                          'unidades entregadas, unidades distintas en '
                          'intercambio o ambas. El sistema registra cada EPC '
                          'por separado y admite recepciones parciales.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.text,
                                fontSize: 11.5,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SearchInput(
                  controller: _search,
                  hint: 'Buscar por código o EPC',
                  onChanged: (_) => setState(() {}),
                  onClear: () => setState(_search.clear),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Unidades entregadas pendientes',
                  subtitle:
                      '${pending.length} unidad(es) de esta operación sin retorno',
                  padding: EdgeInsets.zero,
                  child: pending.isEmpty
                      ? const EmptyState(
                          icon: Icons.verified_rounded,
                          title: 'Sin pendientes de esta operación',
                          message:
                              'Todas las unidades entregadas ya fueron '
                              'recibidas.',
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < pendingFiltered.length; i++) ...[
                              if (i > 0) const Divider(),
                              CheckboxListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                value: _selected.contains(
                                  pendingFiltered[i].id,
                                ),
                                onChanged: (value) => setState(() {
                                  if (value == true) {
                                    _selected.add(pendingFiltered[i].id);
                                  } else {
                                    _selected.remove(pendingFiltered[i].id);
                                  }
                                }),
                                title: Text(
                                  '${pendingFiltered[i].code} · '
                                  '${pendingFiltered[i].name}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${pendingFiltered[i].situation.label} · '
                                  '${pendingFiltered[i].rfidEpc}',
                                  style: const TextStyle(fontSize: 10.5),
                                ),
                              ),
                            ],
                            if (pendingFiltered.isNotEmpty)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => setState(() {
                                    _selected.addAll(
                                      pendingFiltered.map((asset) => asset.id),
                                    );
                                  }),
                                  child: const Text('Seleccionar todas'),
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Otras unidades registradas',
                  subtitle:
                      '${exchangeCandidates.length} unidad(es) fuera del '
                      'inventario interno para posible intercambio',
                  padding: EdgeInsets.zero,
                  child: exchangeCandidates.isEmpty
                      ? const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'Sin otras unidades fuera',
                          message:
                              'Podés incorporar una unidad no registrada con '
                              'el botón inferior.',
                        )
                      : Column(
                          children: [
                            for (
                              var i = 0;
                              i < exchangeFiltered.length;
                              i++
                            ) ...[
                              if (i > 0) const Divider(),
                              CheckboxListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                value: _selected.contains(
                                  exchangeFiltered[i].id,
                                ),
                                onChanged: (value) => setState(() {
                                  if (value == true) {
                                    _selected.add(exchangeFiltered[i].id);
                                  } else {
                                    _selected.remove(exchangeFiltered[i].id);
                                  }
                                }),
                                title: Text(
                                  '${exchangeFiltered[i].code} · '
                                  '${exchangeFiltered[i].name}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${exchangeFiltered[i].location.shortLabel} · '
                                  '${exchangeFiltered[i].situation.label} · '
                                  '${exchangeFiltered[i].rfidEpc}',
                                  style: const TextStyle(fontSize: 10.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openNewAssetDialog,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Incorporar unidad no registrada'),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _selected.isEmpty || _saving ? null : _receive,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.move_to_inbox_rounded),
                  label: Text(
                    _saving
                        ? 'Guardando...'
                        : 'Recibir ${_selected.length} unidad(es)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _receive() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    final result = await ref
        .read(appControllerProvider.notifier)
        .receiveSupplierAssets(
          operationId: widget.operationId,
          assetIds: _selected.toList(),
          notes: 'Recepción registrada desde la operación.',
          accessId: 'acc-proveedores',
          readerId: 'LEC-PROV-01',
        );
    if (!mounted) return;
    setState(() => _saving = false);
    showResultMessage(context, result);
    if (result.success) Navigator.pop(context, true);
  }

  Future<void> _openNewAssetDialog() async {
    final result = await showDialog<ActionResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NewReceivedAssetDialog(
        operationId: widget.operationId,
        ref: ref,
      ),
    );
    if (result != null && mounted) showResultMessage(context, result);
  }
}

class _NewReceivedAssetDialog extends ConsumerStatefulWidget {
  const _NewReceivedAssetDialog({
    required this.operationId,
    required this.ref,
  });

  final String operationId;
  final WidgetRef ref;

  @override
  ConsumerState<_NewReceivedAssetDialog> createState() =>
      _NewReceivedAssetDialogState();
}

class _NewReceivedAssetDialogState
    extends ConsumerState<_NewReceivedAssetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  final _name = TextEditingController();
  final _rfid = TextEditingController();
  late String _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(appControllerProvider).requireValue;
    _categoryId = state.categories.first.id;
    _code = TextEditingController(
      text: nextAssetCode(
        state.categories.first.codePrefix,
        state.assets.map((item) => item.code),
      ),
    );
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _rfid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    return AlertDialog(
      title: const Text('Unidad no registrada'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'La unidad se incorpora al inventario mediante un flujo '
                'controlado y se registra como recibida del proveedor.',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Código *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Obligatorio'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Obligatorio'
                    : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  for (final category in state.categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _categoryId = value);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _rfid,
                decoration: InputDecoration(
                  labelText: 'EPC / RFID *',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() {
                      _rfid.text =
                          'E2801170000002${(DateTime.now().microsecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';
                    }),
                    icon: const Icon(Icons.autorenew_rounded),
                  ),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Obligatorio'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _saving = true);
                  final result = await ref
                      .read(appControllerProvider.notifier)
                      .receiveNewSupplierAsset(
                        operationId: widget.operationId,
                        code: _code.text,
                        name: _name.text,
                        categoryId: _categoryId,
                        rfidEpc: _rfid.text,
                      );
                  if (!context.mounted) return;
                  setState(() => _saving = false);
                  if (result.success) {
                    Navigator.pop(context, result);
                  } else {
                    showResultMessage(context, result);
                  }
                },
          child: Text(_saving ? 'Guardando...' : 'Incorporar y recibir'),
        ),
      ],
    );
  }
}
