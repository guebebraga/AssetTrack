import 'dart:async';

import '../../services/movement_service.dart';
import '../enums.dart';
import '../models.dart';

enum RfidDirectionHint { inbound, outbound }

class RfidEvent {
  const RfidEvent({
    required this.epc,
    required this.readerId,
    required this.accessId,
    required this.timestamp,
    this.directionHint,
    this.antenna = 1,
    this.rssi = -55,
  });

  final String epc;
  final String readerId;
  final String accessId;
  final DateTime timestamp;
  final RfidDirectionHint? directionHint;
  final int antenna;
  final double rssi;

  Map<String, dynamic> toJson() => {
    'epc': epc,
    'readerId': readerId,
    'accessId': accessId,
    'timestamp': timestamp.toIso8601String(),
    'directionHint': directionHint?.name,
    'antenna': antenna,
    'rssi': rssi,
  };
}

abstract class RfidReader {
  String get id;
  String get name;
  String get accessId;
  bool get isConnected;
  Stream<RfidEvent> get events;
  Future<void> connect();
  Future<void> disconnect();
  Future<void> dispose();
}

abstract class RfidEventSource {
  Future<List<RfidEvent>> pendingEvents();
  void acknowledge(Iterable<RfidEvent> events);
}

class MockRfidReader implements RfidReader, RfidEventSource {
  MockRfidReader({
    required this.id,
    required this.name,
    required this.accessId,
  });

  @override
  final String id;

  @override
  final String name;

  @override
  final String accessId;

  final StreamController<RfidEvent> _controller =
      StreamController<RfidEvent>.broadcast();
  final List<RfidEvent> _pending = [];
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Stream<RfidEvent> get events => _controller.stream;

  @override
  Future<void> connect() async {
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<void> dispose() async {
    if (_connected) await disconnect();
    await _controller.close();
  }

  void emit(RfidEvent event) {
    if (!_connected) return;
    _pending.add(event);
    _controller.add(event);
  }

  @override
  Future<List<RfidEvent>> pendingEvents() async {
    final copy = List<RfidEvent>.unmodifiable(_pending);
    return copy;
  }

  @override
  void acknowledge(Iterable<RfidEvent> events) {
    final ids = events.map((event) => event.timestamp.microsecondsSinceEpoch);
    _pending.removeWhere(
      (event) => ids.contains(event.timestamp.microsecondsSinceEpoch),
    );
  }
}

class ProcessedRead {
  const ProcessedRead({
    required this.message,
    required this.recognised,
    this.duplicate = false,
    this.ambiguous = false,
    this.asset,
    this.event,
  });

  final String message;
  final bool recognised;
  final bool duplicate;
  final bool ambiguous;
  final Asset? asset;
  final MovementEvent? event;
}

class RfidEventProcessor {
  RfidEventProcessor(this.state, {required this.movementService});

  final AppState state;
  final MovementService movementService;

  ProcessedRead process(
    RfidEvent event, {
    EventOrigin origin = EventOrigin.simulator,
  }) {
    final asset = state.assetByEpc(event.epc);
    if (asset == null) {
      return ProcessedRead(
        message:
            'EPC ${event.epc} no está asociado a ningún activo registrado. '
            'Se requiere un flujo de alta controlado.',
        recognised: false,
      );
    }

    if (event.directionHint == null) {
      movementService.registerDetection(
        assetId: asset.id,
        timestamp: event.timestamp,
        accessId: event.accessId,
        readerId: event.readerId,
      );
      final result = movementService.record(
        assetId: asset.id,
        type: MovementType.ambiguousRead,
        timestamp: event.timestamp,
        origin: origin,
        status: MovementStatus.pendingReview,
        accessId: event.accessId,
        readerId: event.readerId,
        reason: 'Lectura sin sentido de movimiento confirmado',
        alertMessage:
            'La antena ${event.antenna} recibió el EPC ${event.epc} sin '
            'información suficiente para determinar el sentido.',
      );
      return ProcessedRead(
        message:
            '${asset.code}: lectura ambigua guardada para revisión. No se '
            'modificó la ubicación.',
        recognised: true,
        ambiguous: true,
        asset: state.assetById(asset.id),
        event: result.event,
      );
    }

    final type = event.directionHint == RfidDirectionHint.inbound
        ? MovementType.entry
        : MovementType.exit;
    final result = movementService.record(
      assetId: asset.id,
      type: type,
      timestamp: event.timestamp,
      origin: origin,
      accessId: event.accessId,
      readerId: event.readerId,
      reason: 'Evento generado por lector RFID simulado',
      checkDuplicate: true,
    );
    return ProcessedRead(
      message: '${asset.code}: ${result.message}',
      recognised: true,
      duplicate: result.duplicate,
      asset: state.assetById(asset.id),
      event: result.event,
    );
  }
}
