import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ids.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../widgets/common.dart';

class ReadersScreen extends ConsumerStatefulWidget {
  const ReadersScreen({super.key});

  @override
  ConsumerState<ReadersScreen> createState() => _ReadersScreenState();
}

class _ReadersScreenState extends ConsumerState<ReadersScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    return Scaffold(
      appBar: AppBar(title: const Text('Sensores y lectores')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo lector'),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
          child: PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ReadersInfoCard(),
                const SizedBox(height: 14),
                for (final reader in state.readers) ...[
                  _ReaderCard(
                    reader: reader,
                    onEdit: () => _openForm(context, reader),
                    onStatus: (status) =>
                        _changeStatus(context, reader, status),
                    onDelete: () => _removeReader(context, reader),
                  ),
                  const SizedBox(height: 10),
                ],
                if (state.readers.isEmpty) const _EmptyCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, [Reader? reader]) async {
    final result = await showModalBottomSheet<ActionResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReaderFormSheet(reader: reader),
    );
    if (result != null && context.mounted) showResultMessage(context, result);
  }

  Future<void> _changeStatus(
    BuildContext context,
    Reader reader,
    ReaderStatus status,
  ) async {
    final result = await ref
        .read(appControllerProvider.notifier)
        .updateReaderStatus(reader.id, status);
    if (context.mounted) showResultMessage(context, result);
  }

  Future<void> _removeReader(BuildContext context, Reader reader) async {
    final confirmed = await confirmAction(
      context,
      title: 'Dar de baja el lector',
      message:
          'El lector ${reader.id} quedará inactivo y no recibirá lecturas. '
          'Los eventos ya registrados se conservan.',
      confirmLabel: 'Dar de baja',
      destructive: true,
    );
    if (confirmed) {
      final result = await ref
          .read(appControllerProvider.notifier)
          .deleteReader(reader.id);
      if (context.mounted) showResultMessage(context, result);
    }
  }
}

class _ReadersInfoCard extends StatelessWidget {
  const _ReadersInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.settings_input_antenna_rounded,
            color: AppColors.blue,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Un lector pertenece a un acceso o a una habitación. Los sensores '
              'de habitación disparan detección dentro de su zona.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 11, color: AppColors.navy),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navyDark.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Todavía no hay lectores registrados.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(fontSize: 12, color: AppColors.muted),
      ),
    );
  }
}

class _ReaderCard extends StatelessWidget {
  const _ReaderCard({
    required this.reader,
    required this.onEdit,
    required this.onStatus,
    required this.onDelete,
  });

  final Reader reader;
  final VoidCallback onEdit;
  final ValueChanged<ReaderStatus> onStatus;
  final VoidCallback onDelete;

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
                    color: reader.status == ReaderStatus.active
                        ? AppColors.teal.withValues(alpha: 0.1)
                        : AppColors.muted.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.radar_rounded,
                    color: reader.status == ReaderStatus.active
                        ? AppColors.teal
                        : AppColors.muted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reader.name,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontSize: 13.5),
                      ),
                      Text(
                        '${reader.id} · ${reader.type.label}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: reader.status.label,
                  color: reader.status == ReaderStatus.active
                      ? AppColors.teal
                      : AppColors.warning,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Antenas: ${reader.antennaCount}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 10.5, color: AppColors.muted),
            ),
            if (reader.accessId != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Acceso: ${reader.accessId}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 10.5, color: AppColors.muted),
                ),
              ),
            if (reader.zoneId != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Habitación: ${reader.zoneId}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 10.5, color: AppColors.muted),
                ),
              ),
            if (reader.lastSeenAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Último contacto: ${_format(reader.lastSeenAt)}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 10.5, color: AppColors.muted),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 19),
                ),
                IconButton(
                  onPressed: () => onStatus(ReaderStatus.active),
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 19,
                  ),
                ),
                IconButton(
                  onPressed: () => onStatus(ReaderStatus.inactive),
                  icon: const Icon(Icons.block_rounded, size: 19),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 19),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _format(DateTime? value) {
    if (value == null) return '—';
    return value.toIso8601String();
  }
}

class _ReaderFormSheet extends ConsumerStatefulWidget {
  const _ReaderFormSheet({required this.reader});

  final Reader? reader;

  @override
  ConsumerState<_ReaderFormSheet> createState() => _ReaderFormSheetState();
}

class _ReaderFormSheetState extends ConsumerState<_ReaderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late ReaderType _type;
  late int _antennaCount;
  late String? _accessId;
  late String? _zoneId;
  late ReaderProtocol _protocol;
  late ReaderStatus _status;
  late final TextEditingController _host;
  late final TextEditingController _topic;
  late final TextEditingController _model;
  late final TextEditingController _firmware;
  late final TextEditingController _notes;
  late final TextEditingController _port;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final reader = widget.reader;
    _name = TextEditingController(text: reader?.name ?? '');
    _type = reader?.type ?? ReaderType.fixed_uhf;
    _antennaCount = reader?.antennaCount ?? 1;
    _accessId = reader?.accessId;
    _zoneId = reader?.zoneId;
    _protocol = reader?.protocol ?? ReaderProtocol.llrp;
    _status = reader?.status ?? ReaderStatus.active;
    _host = TextEditingController(text: reader?.host ?? '');
    _topic = TextEditingController(text: reader?.topic ?? '');
    _model = TextEditingController(text: reader?.model ?? '');
    _firmware = TextEditingController(text: reader?.firmware ?? '');
    _notes = TextEditingController(text: reader?.notes ?? '');
    _port = TextEditingController(text: reader?.port?.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _topic.dispose();
    _model.dispose();
    _firmware.dispose();
    _notes.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    final controller = ref.read(appControllerProvider.notifier);
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
                  widget.reader == null ? 'Nuevo lector' : 'Editar lector',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'El nombre es obligatorio'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ReaderType>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: [
                    for (final type in ReaderType.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _type = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ReaderStatus>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: [
                    for (final status in ReaderStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ReaderProtocol>(
                  initialValue: _protocol,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Protocolo'),
                  items: [
                    for (final protocol in ReaderProtocol.values)
                      DropdownMenuItem(
                        value: protocol,
                        child: Text(protocol.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _protocol = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _antennaCount.toString(),
                  decoration: const InputDecoration(labelText: 'Antenas *'),
                  keyboardType: TextInputType.number,
                  onSaved: (value) =>
                      _antennaCount = int.tryParse(value ?? '') ?? 1,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _accessId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Acceso'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sin acceso'),
                    ),
                    for (final access in state.accesses)
                      DropdownMenuItem(
                        value: access.id,
                        child: Text(access.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _accessId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _zoneId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Habitación'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sin habitación'),
                    ),
                    for (final zone in state.zones)
                      DropdownMenuItem(value: zone.id, child: Text(zone.name)),
                  ],
                  onChanged: (value) => setState(() => _zoneId = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _host,
                  decoration: const InputDecoration(labelText: 'Host'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _port,
                  decoration: const InputDecoration(labelText: 'Puerto'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _topic,
                  decoration: const InputDecoration(labelText: 'Topic MQTT'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _model,
                  decoration: const InputDecoration(labelText: 'Modelo'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _firmware,
                  decoration: const InputDecoration(labelText: 'Firmware'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'Notas'),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _saving = true);
                          final reader = Reader(
                            id: widget.reader?.id ?? newId('LEC'),
                            name: _name.text.trim(),
                            type: _type,
                            status: _status,
                            accessId: _accessId,
                            zoneId: _zoneId,
                            antennaCount: _antennaCount,
                            protocol: _protocol,
                            host: _host.text.trim(),
                            port: int.tryParse(_port.text.trim()),
                            topic: _topic.text.trim(),
                            model: _model.text.trim(),
                            firmware: _firmware.text.trim(),
                            notes: _notes.text.trim(),
                          );
                          final result = widget.reader == null
                              ? await controller.addReader(reader)
                              : await controller.updateReader(reader);
                          if (!context.mounted) return;
                          setState(() => _saving = false);
                          Navigator.pop(context, result);
                        },
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Guardando...' : 'Guardar lector'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
