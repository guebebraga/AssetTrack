"""Enumeraciones compartidas por la API.

Los valores coinciden exactamente con los nombres usados por Flutter para
mantener compatibilidad con el snapshot existente.
"""

from enum import StrEnum


class UserRole(StrEnum):
    admin = "admin"
    operator = "operator"
    viewer = "viewer"


class AssetLocation(StrEnum):
    inside = "inside"
    outside = "outside"
    unknown = "unknown"
    pendingVerification = "pendingVerification"


class AssetSituation(StrEnum):
    available = "available"
    inUse = "inUse"
    onLoan = "onLoan"
    atSupplier = "atSupplier"
    pendingReturn = "pendingReturn"
    maintenance = "maintenance"


class OperationalStatus(StrEnum):
    operational = "operational"
    needsInspection = "needsInspection"
    outOfService = "outOfService"


class MovementType(StrEnum):
    entry = "entry"
    exit = "exit"
    loan = "loan"
    loanReturn = "loanReturn"
    supplierDelivery = "supplierDelivery"
    supplierReceipt = "supplierReceipt"
    sendForRefill = "sendForRefill"
    receiveAfterRefill = "receiveAfterRefill"
    unitExchange = "unitExchange"
    roomEntry = "roomEntry"
    roomExit = "roomExit"
    roomTransfer = "roomTransfer"
    adminAdjustment = "adminAdjustment"
    ambiguousRead = "ambiguousRead"
    inventoryCorrection = "inventoryCorrection"


class MovementStatus(StrEnum):
    confirmed = "confirmed"
    pendingReview = "pendingReview"
    rejected = "rejected"


class EventOrigin(StrEnum):
    rfidRead = "rfidRead"
    manual = "manual"
    simulator = "simulator"
    system = "system"
    correction = "correction"


class LoanStatus(StrEnum):
    active = "active"
    returned = "returned"
    overdue = "overdue"
    pendingVerification = "pendingVerification"


class SupplierOperationStatus(StrEnum):
    prepared = "prepared"
    delivered = "delivered"
    partiallyReceived = "partiallyReceived"
    completed = "completed"
    pendingReview = "pendingReview"


class AlertSeverity(StrEnum):
    info = "info"
    warning = "warning"
    critical = "critical"


class AlertType(StrEnum):
    outsideTooLong = "outsideTooLong"
    loanOverdue = "loanOverdue"
    supplierPending = "supplierPending"
    incompleteReturn = "incompleteReturn"
    ambiguousRead = "ambiguousRead"
    noRecentDetection = "noRecentDetection"
    incompatibleMovement = "incompatibleMovement"
    unknownReader = "unknownReader"


class AccessType(StrEnum):
    main = "main"
    ambulance = "ambulance"
    service = "service"
    supplier = "supplier"
    loading = "loading"
    other = "other"


class ReaderType(StrEnum):
    fixed_uhf = "fixed_uhf"
    handheld = "handheld"
    room_sensor = "room_sensor"
    virtual = "virtual"


class ReaderStatus(StrEnum):
    active = "active"
    inactive = "inactive"
    maintenance = "maintenance"


class ReaderProtocol(StrEnum):
    llrp = "llrp"
    mqtt = "mqtt"
    http = "http"
    sdk = "sdk"
    none = "none"
