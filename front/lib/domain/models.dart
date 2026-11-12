import 'enums.dart';

DateTime? _date(dynamic value) =>
    value is String && value.isNotEmpty ? DateTime.parse(value) : null;

String? _iso(DateTime? value) => value?.toIso8601String();

T _enumByName<T extends Enum>(List<T> values, dynamic raw, T fallback) {
  if (raw is! String) return fallback;
  return values.firstWhere(
    (value) => value.name == raw,
    orElse: () => fallback,
  );
}

class AssetCategory {
  const AssetCategory({
    required this.id,
    required this.name,
    required this.codePrefix,
    this.description = '',
  });

  final String id;
  final String name;
  final String codePrefix;
  final String description;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'codePrefix': codePrefix,
    'description': description,
  };

  factory AssetCategory.fromJson(Map<String, dynamic> json) => AssetCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    codePrefix: json['codePrefix'] as String? ?? '',
    description: json['description'] as String? ?? '',
  );
}

class Zone {
  const Zone({
    required this.id,
    required this.name,
    required this.description,
    required this.readerIds,
    this.active = true,
  });

  final String id;
  final String name;
  final String description;
  final List<String> readerIds;
  final bool active;

  Zone copyWith({
    String? name,
    String? description,
    List<String>? readerIds,
    bool? active,
  }) => Zone(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    readerIds: readerIds ?? this.readerIds,
    active: active ?? this.active,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'readerIds': readerIds,
    'active': active,
  };

  factory Zone.fromJson(Map<String, dynamic> json) => Zone(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    readerIds: (json['readerIds'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
    active: json['active'] as bool? ?? true,
  );
}

class AccessPoint {
  const AccessPoint({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.readerIds,
    this.configured = true,
  });

  final String id;
  final String name;
  final AccessType type;
  final String description;
  final List<String> readerIds;
  final bool configured;

  AccessPoint copyWith({
    String? name,
    AccessType? type,
    String? description,
    List<String>? readerIds,
    bool? configured,
  }) => AccessPoint(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    description: description ?? this.description,
    readerIds: readerIds ?? this.readerIds,
    configured: configured ?? this.configured,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'description': description,
    'readerIds': readerIds,
    'configured': configured,
  };

  factory AccessPoint.fromJson(Map<String, dynamic> json) => AccessPoint(
    id: json['id'] as String,
    name: json['name'] as String,
    type: _enumByName(AccessType.values, json['type'], AccessType.other),
    description: json['description'] as String? ?? '',
    readerIds: (json['readerIds'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
    configured: json['configured'] as bool? ?? true,
  );
}

class Reader {
  const Reader({
    required this.id,
    required this.name,
    this.type = ReaderType.virtual,
    this.status = ReaderStatus.active,
    this.accessId,
    this.zoneId,
    this.antennaCount = 1,
    this.protocol = ReaderProtocol.none,
    this.host = '',
    this.port,
    this.topic = '',
    this.model = '',
    this.firmware = '',
    this.notes = '',
    this.lastSeenAt,
    this.createdAt,
  });

  final String id;
  final String name;
  final ReaderType type;
  final ReaderStatus status;
  final String? accessId;
  final String? zoneId;
  final int antennaCount;
  final ReaderProtocol protocol;
  final String host;
  final int? port;
  final String topic;
  final String model;
  final String firmware;
  final String notes;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;

  Reader copyWith({
    String? name,
    ReaderType? type,
    ReaderStatus? status,
    String? accessId,
    String? zoneId,
    int? antennaCount,
    ReaderProtocol? protocol,
    String? host,
    int? port,
    String? topic,
    String? model,
    String? firmware,
    String? notes,
    DateTime? lastSeenAt,
    bool clearAccess = false,
    bool clearZone = false,
    bool clearPort = false,
  }) => Reader(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    status: status ?? this.status,
    accessId: clearAccess ? null : (accessId ?? this.accessId),
    zoneId: clearZone ? null : (zoneId ?? this.zoneId),
    antennaCount: antennaCount ?? this.antennaCount,
    protocol: protocol ?? this.protocol,
    host: host ?? this.host,
    port: clearPort ? null : (port ?? this.port),
    topic: topic ?? this.topic,
    model: model ?? this.model,
    firmware: firmware ?? this.firmware,
    notes: notes ?? this.notes,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'status': status.name,
    'accessId': accessId,
    'zoneId': zoneId,
    'antennaCount': antennaCount,
    'protocol': protocol.name,
    'host': host,
    'port': port,
    'topic': topic,
    'model': model,
    'firmware': firmware,
    'notes': notes,
    'lastSeenAt': _iso(lastSeenAt),
    'createdAt': _iso(createdAt),
  };

  factory Reader.fromJson(Map<String, dynamic> json) => Reader(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    type: _enumByName(ReaderType.values, json['type'], ReaderType.virtual),
    status: _enumByName(
      ReaderStatus.values,
      json['status'],
      ReaderStatus.active,
    ),
    accessId: json['accessId'] as String?,
    zoneId: json['zoneId'] as String?,
    antennaCount: json['antennaCount'] as int? ?? 1,
    protocol: _enumByName(
      ReaderProtocol.values,
      json['protocol'],
      ReaderProtocol.none,
    ),
    host: json['host'] as String? ?? '',
    port: json['port'] as int?,
    topic: json['topic'] as String? ?? '',
    model: json['model'] as String? ?? '',
    firmware: json['firmware'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    lastSeenAt: _date(json['lastSeenAt']),
    createdAt: _date(json['createdAt']),
  );
}

class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    required this.serviceType,
    this.contact = '',
    this.notes = '',
    this.active = true,
  });

  final String id;
  final String name;
  final String serviceType;
  final String contact;
  final String notes;
  final bool active;

  Supplier copyWith({
    String? name,
    String? serviceType,
    String? contact,
    String? notes,
    bool? active,
  }) => Supplier(
    id: id,
    name: name ?? this.name,
    serviceType: serviceType ?? this.serviceType,
    contact: contact ?? this.contact,
    notes: notes ?? this.notes,
    active: active ?? this.active,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'serviceType': serviceType,
    'contact': contact,
    'notes': notes,
    'active': active,
  };

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
    id: json['id'] as String,
    name: json['name'] as String,
    serviceType: json['serviceType'] as String? ?? '',
    contact: json['contact'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    active: json['active'] as bool? ?? true,
  );
}

class Asset {
  const Asset({
    required this.id,
    required this.code,
    required this.name,
    required this.categoryId,
    required this.rfidEpc,
    required this.location,
    required this.situation,
    required this.operationalStatus,
    required this.createdAt,
    this.description = '',
    this.lastDetectionAt,
    this.lastEntryAt,
    this.lastExitAt,
    this.lastMovementAt,
    this.responsible,
    this.supplierId,
    this.expectedReturnAt,
    this.lastAccessId,
    this.lastReaderId,
    this.roomId,
    this.lastRoomEntryAt,
    this.lastRoomExitAt,
    this.lastRoomDetectionAt,
    this.notes = '',
  });

  final String id;
  final String code;
  final String name;
  final String categoryId;
  final String description;
  final String rfidEpc;
  final AssetLocation location;
  final AssetSituation situation;
  final OperationalStatus operationalStatus;
  final DateTime? lastDetectionAt;
  final DateTime? lastEntryAt;
  final DateTime? lastExitAt;
  final DateTime? lastMovementAt;
  final String? responsible;
  final String? supplierId;
  final DateTime? expectedReturnAt;
  final DateTime createdAt;
  final String? lastAccessId;
  final String? lastReaderId;
  final String? roomId;
  final DateTime? lastRoomEntryAt;
  final DateTime? lastRoomExitAt;
  final DateTime? lastRoomDetectionAt;
  final String notes;

  bool get isInside => location == AssetLocation.inside;
  bool get isOutside => location == AssetLocation.outside;
  bool get isInRoom => location == AssetLocation.inside && roomId != null;
  bool get isLoan => situation == AssetSituation.onLoan;
  bool get isAtSupplier => situation == AssetSituation.atSupplier;

  Asset copyWith({
    String? code,
    String? name,
    String? categoryId,
    String? description,
    String? rfidEpc,
    AssetLocation? location,
    AssetSituation? situation,
    OperationalStatus? operationalStatus,
    DateTime? lastDetectionAt,
    DateTime? lastEntryAt,
    DateTime? lastExitAt,
    DateTime? lastMovementAt,
    String? responsible,
    String? supplierId,
    DateTime? expectedReturnAt,
    String? lastAccessId,
    String? lastReaderId,
    String? roomId,
    DateTime? lastRoomEntryAt,
    DateTime? lastRoomExitAt,
    DateTime? lastRoomDetectionAt,
    String? notes,
    bool clearResponsible = false,
    bool clearSupplier = false,
    bool clearExpectedReturn = false,
    bool clearLastAccess = false,
    bool clearLastReader = false,
    bool clearRoom = false,
  }) => Asset(
    id: id,
    code: code ?? this.code,
    name: name ?? this.name,
    categoryId: categoryId ?? this.categoryId,
    description: description ?? this.description,
    rfidEpc: rfidEpc ?? this.rfidEpc,
    location: location ?? this.location,
    situation: situation ?? this.situation,
    operationalStatus: operationalStatus ?? this.operationalStatus,
    lastDetectionAt: lastDetectionAt ?? this.lastDetectionAt,
    lastEntryAt: lastEntryAt ?? this.lastEntryAt,
    lastExitAt: lastExitAt ?? this.lastExitAt,
    lastMovementAt: lastMovementAt ?? this.lastMovementAt,
    responsible: clearResponsible ? null : (responsible ?? this.responsible),
    supplierId: clearSupplier ? null : (supplierId ?? this.supplierId),
    expectedReturnAt: clearExpectedReturn
        ? null
        : (expectedReturnAt ?? this.expectedReturnAt),
    createdAt: createdAt,
    lastAccessId: clearLastAccess ? null : (lastAccessId ?? this.lastAccessId),
    lastReaderId: clearLastReader ? null : (lastReaderId ?? this.lastReaderId),
    roomId: clearRoom ? null : (roomId ?? this.roomId),
    lastRoomEntryAt: lastRoomEntryAt ?? this.lastRoomEntryAt,
    lastRoomExitAt: lastRoomExitAt ?? this.lastRoomExitAt,
    lastRoomDetectionAt: lastRoomDetectionAt ?? this.lastRoomDetectionAt,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'categoryId': categoryId,
    'description': description,
    'rfidEpc': rfidEpc,
    'location': location.name,
    'situation': situation.name,
    'operationalStatus': operationalStatus.name,
    'lastDetectionAt': _iso(lastDetectionAt),
    'lastEntryAt': _iso(lastEntryAt),
    'lastExitAt': _iso(lastExitAt),
    'lastMovementAt': _iso(lastMovementAt),
    'responsible': responsible,
    'supplierId': supplierId,
    'expectedReturnAt': _iso(expectedReturnAt),
    'createdAt': createdAt.toIso8601String(),
    'lastAccessId': lastAccessId,
    'lastReaderId': lastReaderId,
    'roomId': roomId,
    'lastRoomEntryAt': _iso(lastRoomEntryAt),
    'lastRoomExitAt': _iso(lastRoomExitAt),
    'lastRoomDetectionAt': _iso(lastRoomDetectionAt),
    'notes': notes,
  };

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    categoryId: json['categoryId'] as String,
    description: json['description'] as String? ?? '',
    rfidEpc: json['rfidEpc'] as String? ?? '',
    location: _enumByName(
      AssetLocation.values,
      json['location'],
      AssetLocation.unknown,
    ),
    situation: _enumByName(
      AssetSituation.values,
      json['situation'],
      AssetSituation.available,
    ),
    operationalStatus: _enumByName(
      OperationalStatus.values,
      json['operationalStatus'],
      OperationalStatus.operational,
    ),
    lastDetectionAt: _date(json['lastDetectionAt']),
    lastEntryAt: _date(json['lastEntryAt']),
    lastExitAt: _date(json['lastExitAt']),
    lastMovementAt: _date(json['lastMovementAt']),
    responsible: json['responsible'] as String?,
    supplierId: json['supplierId'] as String?,
    expectedReturnAt: _date(json['expectedReturnAt']),
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    lastAccessId: json['lastAccessId'] as String?,
    lastReaderId: json['lastReaderId'] as String?,
    roomId: json['roomId'] as String?,
    lastRoomEntryAt: _date(json['lastRoomEntryAt']),
    lastRoomExitAt: _date(json['lastRoomExitAt']),
    lastRoomDetectionAt: _date(json['lastRoomDetectionAt']),
    notes: json['notes'] as String? ?? '',
  );
}

class MovementEvent {
  const MovementEvent({
    required this.id,
    required this.assetId,
    required this.type,
    required this.timestamp,
    required this.origin,
    required this.status,
    this.accessId,
    this.readerId,
    this.roomId,
    this.responsible,
    this.supplierId,
    this.reason = '',
    this.notes = '',
    this.relatedOperationId,
    this.alertMessage,
  });

  final String id;
  final String assetId;
  final MovementType type;
  final DateTime timestamp;
  final EventOrigin origin;
  final MovementStatus status;
  final String? accessId;
  final String? readerId;
  final String? roomId;
  final String? responsible;
  final String? supplierId;
  final String reason;
  final String notes;
  final String? relatedOperationId;
  final String? alertMessage;

  MovementEvent copyWith({
    MovementStatus? status,
    String? notes,
    String? alertMessage,
  }) => MovementEvent(
    id: id,
    assetId: assetId,
    type: type,
    timestamp: timestamp,
    origin: origin,
    status: status ?? this.status,
    accessId: accessId,
    readerId: readerId,
    roomId: roomId,
    responsible: responsible,
    supplierId: supplierId,
    reason: reason,
    notes: notes ?? this.notes,
    relatedOperationId: relatedOperationId,
    alertMessage: alertMessage ?? this.alertMessage,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'assetId': assetId,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    'origin': origin.name,
    'status': status.name,
    'accessId': accessId,
    'readerId': readerId,
    'roomId': roomId,
    'responsible': responsible,
    'supplierId': supplierId,
    'reason': reason,
    'notes': notes,
    'relatedOperationId': relatedOperationId,
    'alertMessage': alertMessage,
  };

  factory MovementEvent.fromJson(Map<String, dynamic> json) => MovementEvent(
    id: json['id'] as String,
    assetId: json['assetId'] as String,
    type: _enumByName(
      MovementType.values,
      json['type'],
      MovementType.adminAdjustment,
    ),
    timestamp: _date(json['timestamp']) ?? DateTime.now(),
    origin: _enumByName(EventOrigin.values, json['origin'], EventOrigin.system),
    status: _enumByName(
      MovementStatus.values,
      json['status'],
      MovementStatus.confirmed,
    ),
    accessId: json['accessId'] as String?,
    readerId: json['readerId'] as String?,
    roomId: json['roomId'] as String?,
    responsible: json['responsible'] as String?,
    supplierId: json['supplierId'] as String?,
    reason: json['reason'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    relatedOperationId: json['relatedOperationId'] as String?,
    alertMessage: json['alertMessage'] as String?,
  );
}

class Loan {
  const Loan({
    required this.id,
    required this.assetId,
    required this.borrower,
    required this.deliveredAt,
    required this.status,
    this.dueAt,
    this.reason = '',
    this.notes = '',
    this.returnedAt,
    this.returnConfirmedInside = false,
  });

  final String id;
  final String assetId;
  final String borrower;
  final DateTime deliveredAt;
  final DateTime? dueAt;
  final String reason;
  final String notes;
  final LoanStatus status;
  final DateTime? returnedAt;
  final bool returnConfirmedInside;

  bool get isOpen => status != LoanStatus.returned;

  LoanStatus effectiveStatus(DateTime now) {
    if (status == LoanStatus.returned) return LoanStatus.returned;
    if (status == LoanStatus.pendingVerification) {
      return LoanStatus.pendingVerification;
    }
    if (dueAt != null && dueAt!.isBefore(now)) return LoanStatus.overdue;
    return LoanStatus.active;
  }

  Loan copyWith({
    LoanStatus? status,
    DateTime? returnedAt,
    bool? returnConfirmedInside,
    String? notes,
  }) => Loan(
    id: id,
    assetId: assetId,
    borrower: borrower,
    deliveredAt: deliveredAt,
    dueAt: dueAt,
    reason: reason,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    returnedAt: returnedAt ?? this.returnedAt,
    returnConfirmedInside: returnConfirmedInside ?? this.returnConfirmedInside,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'assetId': assetId,
    'borrower': borrower,
    'deliveredAt': deliveredAt.toIso8601String(),
    'dueAt': _iso(dueAt),
    'reason': reason,
    'notes': notes,
    'status': status.name,
    'returnedAt': _iso(returnedAt),
    'returnConfirmedInside': returnConfirmedInside,
  };

  factory Loan.fromJson(Map<String, dynamic> json) => Loan(
    id: json['id'] as String,
    assetId: json['assetId'] as String,
    borrower: json['borrower'] as String,
    deliveredAt: _date(json['deliveredAt']) ?? DateTime.now(),
    dueAt: _date(json['dueAt']),
    reason: json['reason'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    status: _enumByName(LoanStatus.values, json['status'], LoanStatus.active),
    returnedAt: _date(json['returnedAt']),
    returnConfirmedInside: json['returnConfirmedInside'] as bool? ?? false,
  );
}

class SupplierOperation {
  const SupplierOperation({
    required this.id,
    required this.supplierId,
    required this.deliveredAssetIds,
    required this.receivedAssetIds,
    required this.createdAt,
    required this.status,
    this.deliveredAt,
    this.dueAt,
    this.reason = '',
    this.notes = '',
    this.receivedAt,
  });

  final String id;
  final String supplierId;
  final List<String> deliveredAssetIds;
  final List<String> receivedAssetIds;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? dueAt;
  final String reason;
  final String notes;
  final SupplierOperationStatus status;
  final DateTime? receivedAt;

  List<String> get pendingAssetIds =>
      deliveredAssetIds.where((id) => !receivedAssetIds.contains(id)).toList();

  bool get isExchange =>
      receivedAssetIds.any((id) => !deliveredAssetIds.contains(id));

  SupplierOperation copyWith({
    List<String>? receivedAssetIds,
    SupplierOperationStatus? status,
    DateTime? deliveredAt,
    DateTime? receivedAt,
    String? notes,
    bool? delivered,
  }) => SupplierOperation(
    id: id,
    supplierId: supplierId,
    deliveredAssetIds: deliveredAssetIds,
    receivedAssetIds: receivedAssetIds ?? this.receivedAssetIds,
    createdAt: createdAt,
    deliveredAt: delivered == true
        ? (deliveredAt ?? this.deliveredAt)
        : this.deliveredAt,
    dueAt: dueAt,
    reason: reason,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    receivedAt: receivedAt ?? this.receivedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'supplierId': supplierId,
    'deliveredAssetIds': deliveredAssetIds,
    'receivedAssetIds': receivedAssetIds,
    'createdAt': createdAt.toIso8601String(),
    'deliveredAt': _iso(deliveredAt),
    'dueAt': _iso(dueAt),
    'reason': reason,
    'notes': notes,
    'status': status.name,
    'receivedAt': _iso(receivedAt),
  };

  factory SupplierOperation.fromJson(
    Map<String, dynamic> json,
  ) => SupplierOperation(
    id: json['id'] as String,
    supplierId: json['supplierId'] as String,
    deliveredAssetIds: (json['deliveredAssetIds'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
    receivedAssetIds: (json['receivedAssetIds'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    deliveredAt: _date(json['deliveredAt']),
    dueAt: _date(json['dueAt']),
    reason: json['reason'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    status: _enumByName(
      SupplierOperationStatus.values,
      json['status'],
      SupplierOperationStatus.prepared,
    ),
    receivedAt: _date(json['receivedAt']),
  );
}

class Alert {
  const Alert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.createdAt,
    this.assetId,
    this.simulated = true,
    this.resolvedAt,
  });

  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String message;
  final DateTime createdAt;
  final String? assetId;
  final bool simulated;
  final DateTime? resolvedAt;

  bool get isOpen => resolvedAt == null;

  Alert copyWith({DateTime? resolvedAt, String? message, String? title}) =>
      Alert(
        id: id,
        type: type,
        severity: severity,
        title: title ?? this.title,
        message: message ?? this.message,
        createdAt: createdAt,
        assetId: assetId,
        simulated: simulated,
        resolvedAt: resolvedAt ?? this.resolvedAt,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'severity': severity.name,
    'title': title,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
    'assetId': assetId,
    'simulated': simulated,
    'resolvedAt': _iso(resolvedAt),
  };

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
    id: json['id'] as String,
    type: _enumByName(AlertType.values, json['type'], AlertType.ambiguousRead),
    severity: _enumByName(
      AlertSeverity.values,
      json['severity'],
      AlertSeverity.info,
    ),
    title: json['title'] as String,
    message: json['message'] as String,
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    assetId: json['assetId'] as String?,
    simulated: json['simulated'] as bool? ?? true,
    resolvedAt: _date(json['resolvedAt']),
  );
}

class AppSettings {
  const AppSettings({
    this.organizationName = 'Sanatorio Modelo',
    this.appName = 'AssetTrack',
    this.outsideThresholdHours = 72,
    this.dedupeWindowSeconds = 30,
    this.alertDetectionHours = 72,
    this.rfidSourceName = 'Lector RFID UHF simulado',
    this.rfidSourceStatus = 'Simulada',
    this.rfidConnected = false,
    this.demoMode = true,
    this.readerAntennaCount = 2,
    this.themeModeName = 'system',
  });

  final String organizationName;
  final String appName;
  final int outsideThresholdHours;
  final int dedupeWindowSeconds;
  final int alertDetectionHours;
  final String rfidSourceName;
  final String rfidSourceStatus;
  final bool rfidConnected;
  final bool demoMode;
  final int readerAntennaCount;
  final String themeModeName;

  AppSettings copyWith({
    String? organizationName,
    String? appName,
    int? outsideThresholdHours,
    int? dedupeWindowSeconds,
    int? alertDetectionHours,
    String? rfidSourceName,
    String? rfidSourceStatus,
    bool? rfidConnected,
    bool? demoMode,
    int? readerAntennaCount,
    String? themeModeName,
  }) => AppSettings(
    organizationName: organizationName ?? this.organizationName,
    appName: appName ?? this.appName,
    outsideThresholdHours: outsideThresholdHours ?? this.outsideThresholdHours,
    dedupeWindowSeconds: dedupeWindowSeconds ?? this.dedupeWindowSeconds,
    alertDetectionHours: alertDetectionHours ?? this.alertDetectionHours,
    rfidSourceName: rfidSourceName ?? this.rfidSourceName,
    rfidSourceStatus: rfidSourceStatus ?? this.rfidSourceStatus,
    rfidConnected: rfidConnected ?? this.rfidConnected,
    demoMode: demoMode ?? this.demoMode,
    readerAntennaCount: readerAntennaCount ?? this.readerAntennaCount,
    themeModeName: themeModeName ?? this.themeModeName,
  );

  Map<String, dynamic> toJson() => {
    'organizationName': organizationName,
    'appName': appName,
    'outsideThresholdHours': outsideThresholdHours,
    'dedupeWindowSeconds': dedupeWindowSeconds,
    'alertDetectionHours': alertDetectionHours,
    'rfidSourceName': rfidSourceName,
    'rfidSourceStatus': rfidSourceStatus,
    'rfidConnected': rfidConnected,
    'demoMode': demoMode,
    'readerAntennaCount': readerAntennaCount,
    'themeModeName': themeModeName,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    organizationName: json['organizationName'] as String? ?? 'Sanatorio Modelo',
    appName: json['appName'] as String? ?? 'AssetTrack',
    outsideThresholdHours: json['outsideThresholdHours'] as int? ?? 72,
    dedupeWindowSeconds: json['dedupeWindowSeconds'] as int? ?? 30,
    alertDetectionHours: json['alertDetectionHours'] as int? ?? 72,
    rfidSourceName:
        json['rfidSourceName'] as String? ?? 'Lector RFID UHF simulado',
    rfidSourceStatus: json['rfidSourceStatus'] as String? ?? 'Simulada',
    rfidConnected: json['rfidConnected'] as bool? ?? false,
    demoMode: json['demoMode'] as bool? ?? true,
    readerAntennaCount: json['readerAntennaCount'] as int? ?? 2,
    themeModeName: json['themeModeName'] as String? ?? 'system',
  );
}

class AppSnapshot {
  const AppSnapshot({
    required this.version,
    required this.assets,
    required this.categories,
    required this.accesses,
    required this.zones,
    required this.readers,
    required this.suppliers,
    required this.movements,
    required this.loans,
    required this.supplierOperations,
    required this.alerts,
    required this.settings,
    required this.savedAt,
  });

  final int version;
  final List<Asset> assets;
  final List<AssetCategory> categories;
  final List<AccessPoint> accesses;
  final List<Zone> zones;
  final List<Reader> readers;
  final List<Supplier> suppliers;
  final List<MovementEvent> movements;
  final List<Loan> loans;
  final List<SupplierOperation> supplierOperations;
  final List<Alert> alerts;
  final AppSettings settings;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'version': version,
    'assets': assets.map((e) => e.toJson()).toList(),
    'categories': categories.map((e) => e.toJson()).toList(),
    'accesses': accesses.map((e) => e.toJson()).toList(),
    'zones': zones.map((e) => e.toJson()).toList(),
    'readers': readers.map((e) => e.toJson()).toList(),
    'suppliers': suppliers.map((e) => e.toJson()).toList(),
    'movements': movements.map((e) => e.toJson()).toList(),
    'loans': loans.map((e) => e.toJson()).toList(),
    'supplierOperations': supplierOperations.map((e) => e.toJson()).toList(),
    'alerts': alerts.map((e) => e.toJson()).toList(),
    'settings': settings.toJson(),
    'savedAt': savedAt.toIso8601String(),
  };

  factory AppSnapshot.fromJson(Map<String, dynamic> json) => AppSnapshot(
    version: json['version'] as int? ?? 1,
    assets: (json['assets'] as List<dynamic>? ?? const [])
        .map((e) => Asset.fromJson(e as Map<String, dynamic>))
        .toList(),
    categories: (json['categories'] as List<dynamic>? ?? const [])
        .map((e) => AssetCategory.fromJson(e as Map<String, dynamic>))
        .toList(),
    accesses: (json['accesses'] as List<dynamic>? ?? const [])
        .map((e) => AccessPoint.fromJson(e as Map<String, dynamic>))
        .toList(),
    zones: (json['zones'] as List<dynamic>? ?? const [])
        .map((e) => Zone.fromJson(e as Map<String, dynamic>))
        .toList(),
    readers: (json['readers'] as List<dynamic>? ?? const [])
        .map((e) => Reader.fromJson(e as Map<String, dynamic>))
        .toList(),
    suppliers: (json['suppliers'] as List<dynamic>? ?? const [])
        .map((e) => Supplier.fromJson(e as Map<String, dynamic>))
        .toList(),
    movements: (json['movements'] as List<dynamic>? ?? const [])
        .map((e) => MovementEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
    loans: (json['loans'] as List<dynamic>? ?? const [])
        .map((e) => Loan.fromJson(e as Map<String, dynamic>))
        .toList(),
    supplierOperations:
        (json['supplierOperations'] as List<dynamic>? ?? const [])
            .map((e) => SupplierOperation.fromJson(e as Map<String, dynamic>))
            .toList(),
    alerts: (json['alerts'] as List<dynamic>? ?? const [])
        .map((e) => Alert.fromJson(e as Map<String, dynamic>))
        .toList(),
    settings: json['settings'] is Map<String, dynamic>
        ? AppSettings.fromJson(json['settings'] as Map<String, dynamic>)
        : const AppSettings(),
    savedAt: _date(json['savedAt']) ?? DateTime.now(),
  );
}

class AppState {
  AppState({
    required this.assets,
    required this.categories,
    required this.accesses,
    required this.zones,
    List<Reader>? readers,
    required this.suppliers,
    required this.movements,
    required this.loans,
    required this.supplierOperations,
    required this.alerts,
    required this.settings,
  }) : readers = readers ?? <Reader>[];

  List<Asset> assets;
  List<AssetCategory> categories;
  List<AccessPoint> accesses;
  List<Zone> zones;
  List<Reader> readers;
  List<Supplier> suppliers;
  List<MovementEvent> movements;
  List<Loan> loans;
  List<SupplierOperation> supplierOperations;
  List<Alert> alerts;
  AppSettings settings;

  Asset? assetById(String? id) {
    if (id == null) return null;
    for (final asset in assets) {
      if (asset.id == id) return asset;
    }
    return null;
  }

  Asset? assetByCode(String code) {
    final normalized = code.trim().toLowerCase();
    for (final asset in assets) {
      if (asset.code.toLowerCase() == normalized) return asset;
    }
    return null;
  }

  Asset? assetByEpc(String epc) {
    final normalized = epc.trim().toUpperCase();
    for (final asset in assets) {
      if (asset.rfidEpc.toUpperCase() == normalized) return asset;
    }
    return null;
  }

  AssetCategory? categoryById(String? id) {
    if (id == null) return null;
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  AccessPoint? accessById(String? id) {
    if (id == null) return null;
    for (final access in accesses) {
      if (access.id == id) return access;
    }
    return null;
  }

  Zone? zoneById(String? id) {
    if (id == null) return null;
    for (final zone in zones) {
      if (zone.id == id) return zone;
    }
    return null;
  }

  Zone? zoneByReaderId(String? readerId) {
    if (readerId == null) return null;
    for (final zone in zones) {
      if (zone.readerIds.contains(readerId)) return zone;
    }
    return null;
  }

  Reader? readerById(String? id) {
    if (id == null) return null;
    for (final reader in readers) {
      if (reader.id == id) return reader;
    }
    return null;
  }

  List<Reader> readersForAccess(String? accessId) =>
      readers.where((reader) => reader.accessId == accessId).toList();

  List<Reader> readersForZone(String? zoneId) =>
      readers.where((reader) => reader.zoneId == zoneId).toList();

  Supplier? supplierById(String? id) {
    if (id == null) return null;
    for (final supplier in suppliers) {
      if (supplier.id == id) return supplier;
    }
    return null;
  }

  Loan? loanById(String? id) {
    if (id == null) return null;
    for (final loan in loans) {
      if (loan.id == id) return loan;
    }
    return null;
  }

  SupplierOperation? operationById(String? id) {
    if (id == null) return null;
    for (final operation in supplierOperations) {
      if (operation.id == id) return operation;
    }
    return null;
  }

  Loan? openLoanForAsset(String assetId) {
    for (final loan in loans) {
      if (loan.assetId == assetId && loan.isOpen) return loan;
    }
    return null;
  }

  List<MovementEvent> movementsForAsset(String assetId) {
    final result = movements.where((m) => m.assetId == assetId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }

  AppSnapshot toSnapshot() => AppSnapshot(
    version: 1,
    assets: assets,
    categories: categories,
    accesses: accesses,
    zones: zones,
    readers: readers,
    suppliers: suppliers,
    movements: movements,
    loans: loans,
    supplierOperations: supplierOperations,
    alerts: alerts,
    settings: settings,
    savedAt: DateTime.now(),
  );

  factory AppState.fromSnapshot(AppSnapshot snapshot) => AppState(
    assets: snapshot.assets,
    categories: snapshot.categories,
    accesses: snapshot.accesses,
    zones: snapshot.zones,
    readers: snapshot.readers,
    suppliers: snapshot.suppliers,
    movements: snapshot.movements,
    loans: snapshot.loans,
    supplierOperations: snapshot.supplierOperations,
    alerts: snapshot.alerts,
    settings: snapshot.settings,
  );
}
