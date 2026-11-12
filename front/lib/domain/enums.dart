enum UserRole { admin, operator, viewer }

enum ReaderType {
  // ignore: constant_identifier_names
  fixed_uhf,
  // ignore: constant_identifier_names
  handheld,
  // ignore: constant_identifier_names
  room_sensor,
  // ignore: constant_identifier_names
  virtual,
}

enum ReaderStatus { active, inactive, maintenance }

enum ReaderProtocol { llrp, mqtt, http, sdk, none }

enum AssetLocation { inside, outside, unknown, pendingVerification }

enum AssetSituation {
  available,
  inUse,
  onLoan,
  atSupplier,
  pendingReturn,
  maintenance,
}

enum OperationalStatus { operational, needsInspection, outOfService }

enum MovementType {
  entry,
  exit,
  loan,
  loanReturn,
  supplierDelivery,
  supplierReceipt,
  sendForRefill,
  receiveAfterRefill,
  unitExchange,
  roomEntry,
  roomExit,
  roomTransfer,
  adminAdjustment,
  ambiguousRead,
  inventoryCorrection,
}

enum MovementStatus { confirmed, pendingReview, rejected }

enum EventOrigin { rfidRead, manual, simulator, system, correction }

enum LoanStatus { active, returned, overdue, pendingVerification }

enum SupplierOperationStatus {
  prepared,
  delivered,
  partiallyReceived,
  completed,
  pendingReview,
}

enum AlertSeverity { info, warning, critical }

enum AlertType {
  outsideTooLong,
  loanOverdue,
  supplierPending,
  incompleteReturn,
  ambiguousRead,
  noRecentDetection,
  incompatibleMovement,
  unknownReader,
}

enum AccessType { main, ambulance, service, supplier, loading, other }

extension UserRoleX on UserRole {
  String get label => switch (this) {
    UserRole.admin => 'Administrador',
    UserRole.operator => 'Operador',
    UserRole.viewer => 'Consulta',
  };

  bool get canOperate => this == UserRole.admin || this == UserRole.operator;

  bool get isAdmin => this == UserRole.admin;
}

extension ReaderTypeX on ReaderType {
  String get label => switch (this) {
    ReaderType.fixed_uhf => 'Lector fijo UHF',
    ReaderType.handheld => 'Lector portátil',
    ReaderType.room_sensor => 'Sensor de habitación',
    ReaderType.virtual => 'Lector virtual',
  };
}

extension ReaderStatusX on ReaderStatus {
  String get label => switch (this) {
    ReaderStatus.active => 'Activo',
    ReaderStatus.inactive => 'Inactivo',
    ReaderStatus.maintenance => 'En mantenimiento',
  };
}

extension ReaderProtocolX on ReaderProtocol {
  String get label => switch (this) {
    ReaderProtocol.llrp => 'LLRP',
    ReaderProtocol.mqtt => 'MQTT',
    ReaderProtocol.http => 'HTTP',
    ReaderProtocol.sdk => 'SDK del fabricante',
    ReaderProtocol.none => 'Sin protocolo',
  };
}

extension AssetLocationX on AssetLocation {
  String get label => switch (this) {
    AssetLocation.inside => 'Dentro de las instalaciones',
    AssetLocation.outside => 'Fuera de las instalaciones',
    AssetLocation.unknown => 'Ubicación desconocida',
    AssetLocation.pendingVerification => 'Pendiente de verificación',
  };

  String get shortLabel => switch (this) {
    AssetLocation.inside => 'Dentro',
    AssetLocation.outside => 'Fuera',
    AssetLocation.unknown => 'Desconocida',
    AssetLocation.pendingVerification => 'A verificar',
  };
}

extension AssetSituationX on AssetSituation {
  String get label => switch (this) {
    AssetSituation.available => 'Disponible',
    AssetSituation.inUse => 'En uso',
    AssetSituation.onLoan => 'Prestado',
    AssetSituation.atSupplier => 'Enviado a proveedor',
    AssetSituation.pendingReturn => 'Pendiente de devolución',
    AssetSituation.maintenance => 'En mantenimiento',
  };
}

extension OperationalStatusX on OperationalStatus {
  String get label => switch (this) {
    OperationalStatus.operational => 'Operativo',
    OperationalStatus.needsInspection => 'Requiere inspección',
    OperationalStatus.outOfService => 'Fuera de servicio',
  };
}

extension MovementTypeX on MovementType {
  String get label => switch (this) {
    MovementType.entry => 'Entrada',
    MovementType.exit => 'Salida',
    MovementType.loan => 'Préstamo',
    MovementType.loanReturn => 'Devolución de préstamo',
    MovementType.supplierDelivery => 'Entrega a proveedor',
    MovementType.supplierReceipt => 'Recepción de proveedor',
    MovementType.sendForRefill => 'Envío a recarga',
    MovementType.receiveAfterRefill => 'Recepción después de recarga',
    MovementType.unitExchange => 'Intercambio de unidad',
    MovementType.roomEntry => 'Ingreso a habitación',
    MovementType.roomExit => 'Salida de habitación',
    MovementType.roomTransfer => 'Traslado entre habitaciones',
    MovementType.adminAdjustment => 'Ajuste administrativo',
    MovementType.ambiguousRead => 'Lectura ambigua',
    MovementType.inventoryCorrection => 'Corrección de inventario',
  };

  bool get isEntryLike => switch (this) {
    MovementType.entry ||
    MovementType.loanReturn ||
    MovementType.supplierReceipt ||
    MovementType.receiveAfterRefill ||
    MovementType.unitExchange => true,
    _ => false,
  };

  bool get isExitLike => switch (this) {
    MovementType.exit ||
    MovementType.loan ||
    MovementType.supplierDelivery ||
    MovementType.sendForRefill => true,
    _ => false,
  };

  bool get isRoomMovement => switch (this) {
    MovementType.roomEntry ||
    MovementType.roomExit ||
    MovementType.roomTransfer => true,
    _ => false,
  };
}

extension MovementStatusX on MovementStatus {
  String get label => switch (this) {
    MovementStatus.confirmed => 'Confirmado',
    MovementStatus.pendingReview => 'Pendiente de revisión',
    MovementStatus.rejected => 'Rechazado',
  };
}

extension EventOriginX on EventOrigin {
  String get label => switch (this) {
    EventOrigin.rfidRead => 'Lectura RFID',
    EventOrigin.manual => 'Manual',
    EventOrigin.simulator => 'Simulador',
    EventOrigin.system => 'Sistema',
    EventOrigin.correction => 'Corrección',
  };
}

extension LoanStatusX on LoanStatus {
  String get label => switch (this) {
    LoanStatus.active => 'Activo',
    LoanStatus.returned => 'Devuelto',
    LoanStatus.overdue => 'Vencido',
    LoanStatus.pendingVerification => 'Pendiente de verificación',
  };
}

extension SupplierOperationStatusX on SupplierOperationStatus {
  String get label => switch (this) {
    SupplierOperationStatus.prepared => 'Preparada',
    SupplierOperationStatus.delivered => 'Entregada',
    SupplierOperationStatus.partiallyReceived => 'Parcialmente recibida',
    SupplierOperationStatus.completed => 'Completada',
    SupplierOperationStatus.pendingReview => 'Pendiente de revisión',
  };
}

extension AlertSeverityX on AlertSeverity {
  String get label => switch (this) {
    AlertSeverity.info => 'Información',
    AlertSeverity.warning => 'Advertencia',
    AlertSeverity.critical => 'Crítica',
  };
}

extension AlertTypeX on AlertType {
  String get label => switch (this) {
    AlertType.outsideTooLong => 'Activo fuera demasiado tiempo',
    AlertType.loanOverdue => 'Préstamo vencido',
    AlertType.supplierPending => 'Entrega a proveedor pendiente',
    AlertType.incompleteReturn => 'Devolución incompleta',
    AlertType.ambiguousRead => 'Lectura ambigua',
    AlertType.noRecentDetection => 'Sin detecciones recientes',
    AlertType.incompatibleMovement => 'Movimiento incompatible',
    AlertType.unknownReader => 'Lector no registrado',
  };
}

extension AccessTypeX on AccessType {
  String get label => switch (this) {
    AccessType.main => 'Entrada principal',
    AccessType.ambulance => 'Acceso de ambulancias',
    AccessType.service => 'Acceso de servicio',
    AccessType.supplier => 'Entrada de proveedores',
    AccessType.loading => 'Carga y descarga',
    AccessType.other => 'Otro',
  };
}

enum LoanDirection { outbound, returnConfirmed, administrativeCorrection }
