import '../../services/alert_service.dart';
import '../enums.dart';
import '../models.dart';

class DemoSeed {
  const DemoSeed._();

  static AppState buildState({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final builder = _SeedBuilder(reference);
    return builder.build();
  }

  static AppSnapshot buildSnapshot({DateTime? now}) =>
      buildState(now: now).toSnapshot();
}

class _SeedBuilder {
  _SeedBuilder(this.now);

  final DateTime now;
  final List<Asset> assets = [];
  final List<AssetCategory> categories = const [
    AssetCategory(
      id: 'cat-o2',
      name: 'Balones de oxígeno medicinal',
      codePrefix: 'O2',
      description: 'Cilindros de oxígeno medicinal para uso asistencial.',
    ),
    AssetCategory(
      id: 'cat-camilla',
      name: 'Camillas',
      codePrefix: 'CMB',
      description: 'Camillas de traslado y exploración.',
    ),
    AssetCategory(
      id: 'cat-silla',
      name: 'Sillas de ruedas',
      codePrefix: 'SRD',
      description: 'Sillas de ruedas manuales y de traslado.',
    ),
    AssetCategory(
      id: 'cat-bomba',
      name: 'Bombas de infusión',
      codePrefix: 'BMI',
      description: 'Bombas volumétricas y de jeringa.',
    ),
    AssetCategory(
      id: 'cat-equipo',
      name: 'Equipamiento médico',
      codePrefix: 'EQM',
      description: 'Monitorización y equipamiento de apoyo.',
    ),
    AssetCategory(
      id: 'cat-herramienta',
      name: 'Herramientas',
      codePrefix: 'HRR',
      description: 'Herramientas y equipamiento logístico.',
    ),
  ];
  final List<AccessPoint> accesses = const [
    AccessPoint(
      id: 'acc-principal',
      name: 'Entrada principal',
      type: AccessType.main,
      description: 'Hall de acceso sobre Av. Central.',
      readerIds: ['LEC-PRINCIPAL-01', 'LEC-PRINCIPAL-02'],
    ),
    AccessPoint(
      id: 'acc-ambulancias',
      name: 'Acceso de ambulancias',
      type: AccessType.ambulance,
      description: 'Rampa de urgencias, sector norte.',
      readerIds: ['LEC-AMB-01'],
    ),
    AccessPoint(
      id: 'acc-servicio',
      name: 'Acceso de servicio',
      type: AccessType.service,
      description: 'Pasillo logístico y depósito.',
      readerIds: ['LEC-SERV-01'],
    ),
    AccessPoint(
      id: 'acc-proveedores',
      name: 'Entrada de proveedores',
      type: AccessType.supplier,
      description: 'Recepción de insumos y gases medicinales.',
      readerIds: ['LEC-PROV-01', 'LEC-PROV-02'],
    ),
    AccessPoint(
      id: 'acc-carga',
      name: 'Carga y descarga',
      type: AccessType.loading,
      description: 'Doca exterior, pendiente de puesta en marcha.',
      readerIds: ['LEC-CARGA-01'],
      configured: false,
    ),
  ];
  final List<Zone> zones = const [
    Zone(
      id: 'zon-uti',
      name: 'Unidad de Terapia Intensiva',
      description: 'Camas críticas, sector norte, piso 2.',
      readerIds: ['LEC-UTI-01', 'LEC-UTI-02'],
    ),
    Zone(
      id: 'zon-guardia',
      name: 'Guardia y urgencias',
      description: 'Sala de guardia y shock room.',
      readerIds: ['LEC-GUARDIA-01'],
    ),
    Zone(
      id: 'zon-quirofano',
      name: 'Quirófanos',
      description: 'Pasillo quirúrgico, piso 1.',
      readerIds: ['LEC-QUIROFANO-01', 'LEC-QUIROFANO-02'],
    ),
    Zone(
      id: 'zon-deposito',
      name: 'Depósito de oxígeno',
      description: 'Almacén de cilindros y recarga interna.',
      readerIds: ['LEC-DEPOSITO-01'],
    ),
    Zone(
      id: 'zon-imagenes',
      name: 'Diagnóstico por imágenes',
      description: 'Tomografía, resonancia y rayos.',
      readerIds: ['LEC-IMAGENES-01'],
    ),
    Zone(
      id: 'zon-internacion',
      name: 'Internación general',
      description: 'Habitaciones de internación, piso 3.',
      readerIds: ['LEC-INTERNACION-01', 'LEC-INTERNACION-02'],
    ),
  ];
  final List<Supplier> suppliers = const [
    Supplier(
      id: 'sup-linde',
      name: 'Linde',
      serviceType: 'Recarga de gases medicinales',
      contact: 'operaciones@proveedor.demo',
      notes: 'Proveedor de demostración. El nombre es configurable.',
    ),
    Supplier(
      id: 'sup-logistica',
      name: 'Logística Sanitaria del Sur',
      serviceType: 'Traslados y logística externa',
      contact: 'logistica@proveedor.demo',
    ),
    Supplier(
      id: 'sup-biomedico',
      name: 'Servicio Técnico Biomédico',
      serviceType: 'Mantenimiento y calibración',
      contact: 'taller@proveedor.demo',
    ),
  ];
  final List<MovementEvent> movements = [];
  final List<Loan> loans = [];
  final List<SupplierOperation> operations = [];
  int _movementCounter = 0;

  final Map<int, DateTime> _todayExit = {};
  final Map<int, DateTime> _todayEntry = {};
  final Map<int, DateTime> _lastEntry = {};
  final Map<int, DateTime?> _lastExit = {};
  final Map<int, DateTime?> _lastMovement = {};

  final Map<int, String?> _responsible = {};
  final Map<int, String?> _supplier = {};
  final Map<int, DateTime?> _expectedReturn = {};

  AppState build() {
    _buildTodayWindow();
    _buildCollections();
    _buildBaseHistory();
    _buildTodayMovements();
    _buildLoans();
    _buildSupplierOperations();
    _buildPendingReads();
    _finalizeAssets();

    final state = AppState(
      assets: assets,
      categories: categories,
      accesses: accesses,
      zones: zones,
      suppliers: suppliers,
      movements: movements,
      loans: loans,
      supplierOperations: operations,
      alerts: const [],
      settings: const AppSettings(),
    );
    movements.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    state.alerts = const AlertService().rebuild(state, now: now);
    return state;
  }

  void _buildTodayWindow() {
    final start = DateTime(now.year, now.month, now.day);
    var base = now.subtract(const Duration(hours: 8));
    if (base.isBefore(start)) base = start;
    final span = now.difference(base);
    for (var i = 0; i < 14; i++) {
      final exitOffset = span * ((2 * i + 1) / 29);
      final entryOffset = span * ((2 * i + 2) / 29);
      _todayExit[i + 1] = base.add(exitOffset);
      _todayEntry[i + 1] = base.add(entryOffset);
    }
  }

  void _buildCollections() {
    for (var n = 1; n <= 50; n++) {
      final code = 'O2-${n.toString().padLeft(3, '0')}';
      var location = AssetLocation.inside;
      var situation = AssetSituation.available;
      String? responsible;
      String? supplierId;
      DateTime? expectedReturn;
      DateTime? lastEntry = now.subtract(Duration(days: 4 + (n % 18)));
      DateTime? lastExit;
      DateTime? lastMovement = lastEntry;

      if (n >= 29 && n <= 32) {
        location = AssetLocation.outside;
        situation = AssetSituation.onLoan;
        final delivered = switch (n) {
          29 => now.subtract(const Duration(days: 6)),
          30 => now.subtract(const Duration(days: 9)),
          31 => now.subtract(const Duration(days: 2)),
          _ => now.subtract(const Duration(days: 1)),
        };
        final due = switch (n) {
          29 => now.add(const Duration(days: 1)),
          30 => now.subtract(const Duration(days: 2)),
          31 => now.add(const Duration(days: 2)),
          _ => now.add(const Duration(hours: 5)),
        };
        responsible = switch (n) {
          29 => 'Camillero turno mañana',
          30 => 'Responsable de guardia',
          31 => 'Traslado asistencial externo',
          _ => 'Sector de imágenes',
        };
        lastEntry = now.subtract(const Duration(days: 20));
        lastExit = delivered;
        lastMovement = delivered;
        expectedReturn = due;
        _responsible[n] = responsible;
      } else if (n >= 33 && n <= 35) {
        location = AssetLocation.outside;
        situation = AssetSituation.atSupplier;
        supplierId = 'sup-linde';
        expectedReturn = now.subtract(const Duration(days: 1));
        lastEntry = now.subtract(const Duration(days: 20));
        lastExit = now.subtract(const Duration(days: 4));
        lastMovement = lastExit;
        _supplier[n] = supplierId;
      } else if (n >= 36 && n <= 39) {
        location = AssetLocation.outside;
        situation = AssetSituation.inUse;
        final days = switch (n) {
          36 => 2,
          37 => 4,
          38 => 5,
          _ => 6,
        };
        lastEntry = now.subtract(const Duration(days: 20));
        lastExit = now.subtract(Duration(days: days));
        lastMovement = lastExit;
      } else if (n == 40 || n == 41) {
        location = AssetLocation.outside;
        situation = AssetSituation.pendingReturn;
        lastEntry = now.subtract(const Duration(days: 20));
        lastExit = now.subtract(Duration(days: n == 40 ? 6 : 8));
        lastMovement = lastExit;
        expectedReturn = now.subtract(Duration(days: n == 40 ? 1 : 2));
      } else if (n == 27 || n == 50) {
        situation = AssetSituation.maintenance;
        lastMovement = now.subtract(const Duration(days: 3));
      } else if (n == 25 || n == 26 || n == 49) {
        situation = AssetSituation.inUse;
      } else if (n >= 15 && n <= 16) {
        lastEntry = now.subtract(const Duration(days: 10));
        lastExit = now.subtract(const Duration(days: 12));
        lastMovement = lastEntry;
      } else if (n >= 17 && n <= 18) {
        lastEntry = now.subtract(const Duration(days: 27));
        lastExit = now.subtract(const Duration(days: 30));
        lastMovement = lastEntry;
      } else if (n == 45 || n == 46) {
        lastEntry = now.subtract(const Duration(days: 2));
        lastExit = now.subtract(const Duration(days: 20));
        lastMovement = lastEntry;
      } else if (n >= 42 && n <= 44) {
        lastEntry = now.subtract(Duration(days: 18 + n % 5));
        lastMovement = lastEntry;
      }

      if (n >= 1 && n <= 14) {
        lastEntry = _todayEntry[n];
        lastExit = _todayExit[n];
        lastMovement = lastEntry;
      }

      _lastEntry[n] = lastEntry!;
      _lastExit[n] = lastExit;
      _lastMovement[n] = lastMovement;
      _responsible[n] = n >= 29 && n <= 32 ? responsible : null;
      _supplier[n] = supplierId;
      _expectedReturn[n] = expectedReturn;

      final detection = _detectionFor(n);
      String? roomId;
      DateTime? roomEntryAt;
      DateTime? roomDetectionAt;
      if (location == AssetLocation.inside) {
        final zone = zones[(n - 1) % zones.length];
        roomId = zone.id;
        roomEntryAt = lastEntry;
        roomDetectionAt = detection;
      }
      assets.add(
        Asset(
          id: 'ast-${n.toString().padLeft(3, '0')}',
          code: code,
          name: 'Balón de oxígeno medicinal ${n.toString().padLeft(2, '0')}',
          categoryId: 'cat-o2',
          description:
              'Cilindro de oxígeno medicinal de 10 m³ con valvulería y '
              'etiqueta RFID para montaje sobre metal.',
          rfidEpc: 'E28011700000020${n.toString().padLeft(3, '0')}',
          location: location,
          situation: situation,
          operationalStatus: n == 50
              ? OperationalStatus.outOfService
              : (n == 27
                    ? OperationalStatus.needsInspection
                    : OperationalStatus.operational),
          lastDetectionAt: detection,
          lastEntryAt: lastEntry,
          lastExitAt: lastExit,
          lastMovementAt: lastMovement,
          responsible: responsible,
          supplierId: supplierId,
          expectedReturnAt: expectedReturn,
          createdAt: now.subtract(Duration(days: 120 - n)),
          lastAccessId: null,
          lastReaderId: null,
          roomId: roomId,
          lastRoomEntryAt: roomEntryAt,
          lastRoomDetectionAt: roomDetectionAt,
          notes: n == 27
              ? 'Retirado de circulación para inspección de válvula.'
              : '',
        ),
      );
    }
  }

  DateTime _detectionFor(int n) {
    DateTime value;
    if (n >= 20 && n <= 24) {
      value = now.subtract(Duration(hours: 82 + n));
    } else if (n >= 42 && n <= 44) {
      value = now.subtract(Duration(hours: 78 + n));
    } else if (n >= 1 && n <= 14) {
      value = now.subtract(Duration(minutes: n * 3));
    } else if (n >= 33 && n <= 35) {
      value = now.subtract(const Duration(days: 2));
    } else if (n == 40 || n == 41) {
      value = now.subtract(const Duration(days: 3));
    } else {
      value = now.subtract(Duration(hours: 2 + n % 20));
    }
    final movement = _lastMovement[n];
    if (movement != null && movement.isAfter(value)) return movement;
    return value;
  }

  void _buildBaseHistory() {
    for (var n = 1; n <= 50; n++) {
      final seedEntry = switch (n) {
        >= 1 && <= 14 => now.subtract(const Duration(days: 15)),
        >= 15 && <= 16 => now.subtract(const Duration(days: 35)),
        >= 17 && <= 18 => now.subtract(const Duration(days: 45)),
        >= 29 && <= 46 => now.subtract(const Duration(days: 20)),
        _ => _lastEntry[n]!,
      };
      _movement(
        n,
        MovementType.entry,
        seedEntry,
        reason: 'Ingreso de unidad al inventario',
        accessId: 'acc-principal',
        readerId: 'LEC-PRINCIPAL-01',
      );

      if (n >= 19 && n <= 20) {
        _movement(
          n,
          MovementType.adminAdjustment,
          now.subtract(const Duration(days: 5)),
          reason: 'Ajuste administrativo de inventario',
          notes: 'Verificación manual de código interno.',
        );
        _lastMovement[n] = now.subtract(const Duration(days: 5));
      }
      if (n == 27) {
        _movement(
          n,
          MovementType.adminAdjustment,
          now.subtract(const Duration(days: 3)),
          reason: 'Envío a mantenimiento',
          notes: 'Inspección de válvula y prueba de estanqueidad.',
        );
      }
    }

    for (final n in [19, 20, 21, 22, 23, 24]) {
      final zone = zones[(n - 1) % zones.length];
      final roomMoment = now.subtract(Duration(days: 2, hours: n));
      _movement(
        n,
        MovementType.roomEntry,
        roomMoment,
        roomId: zone.id,
        readerId: zone.readerIds.first,
        reason: 'Ingreso a ${zone.name}',
      );
      _lastMovement[n] = roomMoment;
    }

    _movement(
      15,
      MovementType.loan,
      now.subtract(const Duration(days: 12)),
      responsible: 'Camillero turno tarde',
      reason: 'Préstamo para traslado interno',
      accessId: 'acc-principal',
      readerId: 'LEC-PRINCIPAL-02',
    );
    _movement(
      15,
      MovementType.loanReturn,
      now.subtract(const Duration(days: 10)),
      responsible: 'Camillero turno tarde',
      reason: 'Devolución de préstamo',
      accessId: 'acc-principal',
      readerId: 'LEC-PRINCIPAL-02',
    );
    _movement(
      16,
      MovementType.loan,
      now.subtract(const Duration(days: 12)),
      responsible: 'Sector de imágenes',
      reason: 'Préstamo para estudio',
      accessId: 'acc-principal',
      readerId: 'LEC-PRINCIPAL-01',
    );
    _movement(
      16,
      MovementType.loanReturn,
      now.subtract(const Duration(days: 10)),
      responsible: 'Sector de imágenes',
      reason: 'Devolución de préstamo',
      accessId: 'acc-principal',
      readerId: 'LEC-PRINCIPAL-01',
    );
    loans.add(
      Loan(
        id: 'pre-demo-015',
        assetId: 'ast-015',
        borrower: 'Camillero turno tarde',
        deliveredAt: now.subtract(const Duration(days: 12)),
        dueAt: now.subtract(const Duration(days: 11)),
        reason: 'Préstamo para traslado interno',
        status: LoanStatus.returned,
        returnedAt: now.subtract(const Duration(days: 10)),
        returnConfirmedInside: true,
      ),
    );
    loans.add(
      Loan(
        id: 'pre-demo-016',
        assetId: 'ast-016',
        borrower: 'Sector de imágenes',
        deliveredAt: now.subtract(const Duration(days: 12)),
        dueAt: now.subtract(const Duration(days: 11)),
        reason: 'Préstamo para estudio',
        status: LoanStatus.returned,
        returnedAt: now.subtract(const Duration(days: 10)),
        returnConfirmedInside: true,
      ),
    );

    for (final n in [17, 18]) {
      _movement(
        n,
        MovementType.supplierDelivery,
        now.subtract(const Duration(days: 30)),
        supplierId: 'sup-linde',
        reason: 'Recarga de oxígeno medicinal',
        accessId: 'acc-proveedores',
        readerId: 'LEC-PROV-01',
        relatedOperationId: 'opr-demo-hist',
      );
      _movement(
        n,
        MovementType.supplierReceipt,
        now.subtract(const Duration(days: 27)),
        supplierId: 'sup-linde',
        reason: 'Recepción después de recarga',
        accessId: 'acc-proveedores',
        readerId: 'LEC-PROV-02',
        relatedOperationId: 'opr-demo-hist',
      );
    }
    operations.add(
      SupplierOperation(
        id: 'opr-demo-hist',
        supplierId: 'sup-linde',
        deliveredAssetIds: const ['ast-017', 'ast-018'],
        receivedAssetIds: const ['ast-017', 'ast-018'],
        createdAt: now.subtract(const Duration(days: 30)),
        deliveredAt: now.subtract(const Duration(days: 30)),
        dueAt: now.subtract(const Duration(days: 20)),
        reason: 'Recarga de oxígeno medicinal',
        status: SupplierOperationStatus.completed,
        receivedAt: now.subtract(const Duration(days: 27)),
      ),
    );

    for (final n in [29, 30, 31, 32]) {
      final delivered = _lastExit[n]!;
      _movement(
        n,
        MovementType.loan,
        delivered,
        responsible: _responsible[n],
        reason: 'Préstamo de unidad',
        accessId: 'acc-principal',
        readerId: 'LEC-PRINCIPAL-01',
      );
    }

    for (final n in [33, 34, 35]) {
      _movement(
        n,
        MovementType.supplierDelivery,
        _lastExit[n]!,
        supplierId: 'sup-linde',
        reason: 'Entrega para recarga',
        accessId: 'acc-proveedores',
        readerId: 'LEC-PROV-01',
        relatedOperationId: 'opr-demo-current',
      );
    }

    for (final n in [36, 37, 38, 39]) {
      _movement(
        n,
        MovementType.exit,
        _lastExit[n]!,
        reason: 'Salida por traslado asistencial',
        accessId: 'acc-ambulancias',
        readerId: 'LEC-AMB-01',
      );
    }
    for (final n in [40, 41]) {
      _movement(
        n,
        MovementType.exit,
        _lastExit[n]!,
        reason: 'Entrega temporal a tercero',
        accessId: 'acc-servicio',
        readerId: 'LEC-SERV-01',
      );
    }
    for (final n in [45, 46]) {
      _movement(
        n,
        MovementType.unitExchange,
        now.subtract(const Duration(days: 2)),
        supplierId: 'sup-linde',
        reason: 'Unidad recibida en intercambio',
        notes: 'El EPC recibido no coincide con las unidades entregadas.',
        accessId: 'acc-proveedores',
        readerId: 'LEC-PROV-02',
        relatedOperationId: 'opr-demo-current',
      );
    }
  }

  void _buildTodayMovements() {
    for (var n = 1; n <= 14; n++) {
      _movement(
        n,
        MovementType.exit,
        _todayExit[n]!,
        reason: 'Salida a traslado interno',
        accessId: 'acc-principal',
        readerId: 'LEC-PRINCIPAL-01',
      );
      _movement(
        n,
        MovementType.entry,
        _todayEntry[n]!,
        reason: 'Ingreso confirmado',
        accessId: 'acc-ambulancias',
        readerId: 'LEC-AMB-01',
      );
    }
  }

  void _buildLoans() {
    final data = <(int, String, DateTime, DateTime, String)>[
      (
        29,
        'Camillero turno mañana',
        now.subtract(const Duration(days: 6)),
        now.add(const Duration(days: 1)),
        'Traslado interno',
      ),
      (
        30,
        'Responsable de guardia',
        now.subtract(const Duration(days: 9)),
        now.subtract(const Duration(days: 2)),
        'Traslado asistencial externo',
      ),
      (
        31,
        'Traslado asistencial externo',
        now.subtract(const Duration(days: 2)),
        now.add(const Duration(days: 2)),
        'Apoyo en derivación',
      ),
      (
        32,
        'Sector de imágenes',
        now.subtract(const Duration(days: 1)),
        now.add(const Duration(hours: 5)),
        'Estudio con oxígeno',
      ),
    ];
    for (final item in data) {
      loans.add(
        Loan(
          id: 'pre-demo-${item.$1.toString().padLeft(3, '0')}',
          assetId: 'ast-${item.$1.toString().padLeft(3, '0')}',
          borrower: item.$2,
          deliveredAt: item.$3,
          dueAt: item.$4,
          reason: item.$5,
          status: LoanStatus.active,
        ),
      );
    }
  }

  void _buildSupplierOperations() {
    operations.add(
      SupplierOperation(
        id: 'opr-demo-current',
        supplierId: 'sup-linde',
        deliveredAssetIds: const ['ast-033', 'ast-034', 'ast-035'],
        receivedAssetIds: const ['ast-045', 'ast-046'],
        createdAt: now.subtract(const Duration(days: 4)),
        deliveredAt: now.subtract(const Duration(days: 4)),
        dueAt: now.subtract(const Duration(days: 1)),
        reason: 'Recarga programada con intercambio de unidades',
        notes:
            'Se recibieron unidades distintas a las entregadas. Quedan '
            'unidades originales pendientes de retorno.',
        status: SupplierOperationStatus.partiallyReceived,
        receivedAt: now.subtract(const Duration(days: 2)),
      ),
    );
    operations.add(
      SupplierOperation(
        id: 'opr-demo-prepared',
        supplierId: 'sup-linde',
        deliveredAssetIds: const ['ast-042'],
        receivedAssetIds: const [],
        createdAt: now.subtract(const Duration(days: 1)),
        dueAt: now.add(const Duration(days: 3)),
        reason: 'Recarga programada',
        status: SupplierOperationStatus.prepared,
      ),
    );
  }

  void _buildPendingReads() {
    _movement(
      8,
      MovementType.ambiguousRead,
      now.subtract(const Duration(days: 1)),
      status: MovementStatus.pendingReview,
      accessId: 'acc-servicio',
      readerId: 'LEC-SERV-01',
      reason: 'Lectura sin sentido confirmado',
      alertMessage:
          'La antena 2 recibió el EPC sin información suficiente para '
          'determinar el sentido del movimiento.',
    );
    _movement(
      29,
      MovementType.exit,
      now.subtract(const Duration(days: 1)),
      status: MovementStatus.pendingReview,
      accessId: 'acc-principal',
      readerId: 'LEC-PRINCIPAL-02',
      reason: 'Posible salida duplicada',
      alertMessage:
          'El activo ya figuraba fuera de las instalaciones. El movimiento '
          'requiere revisión manual.',
    );
  }

  void _finalizeAssets() {
    for (var i = 0; i < assets.length; i++) {
      final n = i + 1;
      final asset = assets[i];
      final detection = asset.lastDetectionAt;
      final entry = _lastEntry[n];
      final exit = _lastExit[n];
      final movement = _lastMovement[n];
      assets[i] = asset.copyWith(
        lastEntryAt: entry,
        lastExitAt: exit,
        lastMovementAt: movement,
        lastDetectionAt: detection,
        responsible: _responsible[n],
        supplierId: _supplier[n],
        expectedReturnAt: _expectedReturn[n],
        clearResponsible: _responsible[n] == null,
        clearSupplier: _supplier[n] == null,
        clearExpectedReturn: _expectedReturn[n] == null,
      );
    }
  }

  void _movement(
    int n,
    MovementType type,
    DateTime timestamp, {
    EventOrigin origin = EventOrigin.simulator,
    MovementStatus status = MovementStatus.confirmed,
    String? accessId,
    String? readerId,
    String? roomId,
    String? responsible,
    String? supplierId,
    String reason = '',
    String notes = '',
    String? relatedOperationId,
    String? alertMessage,
  }) {
    _movementCounter += 1;
    movements.add(
      MovementEvent(
        id: 'mov-demo-${_movementCounter.toString().padLeft(4, '0')}',
        assetId: 'ast-${n.toString().padLeft(3, '0')}',
        type: type,
        timestamp: timestamp,
        origin: origin,
        status: status,
        accessId: accessId,
        readerId: readerId,
        roomId: roomId,
        responsible: responsible,
        supplierId: supplierId,
        reason: reason,
        notes: notes,
        relatedOperationId: relatedOperationId,
        alertMessage: alertMessage,
      ),
    );
  }
}
