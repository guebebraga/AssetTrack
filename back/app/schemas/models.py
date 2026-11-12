"""Esquemas Pydantic de entrada y salida.

La API expone camelCase para que el frontend Flutter pueda reutilizar sus
modelos actuales sin reescribir todos los fromJson.
"""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel

from app.schemas.enums import (
    AccessType,
    AlertSeverity,
    AlertType,
    AssetLocation,
    AssetSituation,
    EventOrigin,
    LoanStatus,
    MovementStatus,
    MovementType,
    OperationalStatus,
    ReaderProtocol,
    ReaderStatus,
    ReaderType,
    SupplierOperationStatus,
    UserRole,
)


class CamelModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True,
    )


class AssetCategory(CamelModel):
    id: str
    name: str
    code_prefix: str = ""
    description: str = ""


class AccessPoint(CamelModel):
    id: str
    name: str
    type: AccessType = AccessType.other
    description: str = ""
    reader_ids: list[str] = Field(default_factory=list)
    configured: bool = True


class Zone(CamelModel):
    id: str
    name: str
    description: str = ""
    reader_ids: list[str] = Field(default_factory=list)
    active: bool = True


class Reader(CamelModel):
    id: str
    name: str
    type: ReaderType = ReaderType.virtual
    status: ReaderStatus = ReaderStatus.active
    access_id: str | None = None
    zone_id: str | None = None
    antenna_count: int = 1
    protocol: ReaderProtocol = ReaderProtocol.none
    host: str = ""
    port: int | None = None
    topic: str = ""
    model: str = ""
    firmware: str = ""
    notes: str = ""
    last_seen_at: datetime | None = None
    created_at: datetime | None = None


class Supplier(CamelModel):
    id: str
    name: str
    service_type: str = ""
    contact: str = ""
    notes: str = ""
    active: bool = True


class Asset(CamelModel):
    id: str
    code: str
    name: str
    category_id: str
    description: str = ""
    rfid_epc: str = ""
    location: AssetLocation = AssetLocation.unknown
    situation: AssetSituation = AssetSituation.available
    operational_status: OperationalStatus = OperationalStatus.operational
    last_detection_at: datetime | None = None
    last_entry_at: datetime | None = None
    last_exit_at: datetime | None = None
    last_movement_at: datetime | None = None
    responsible: str | None = None
    supplier_id: str | None = None
    expected_return_at: datetime | None = None
    created_at: datetime
    last_access_id: str | None = None
    last_reader_id: str | None = None
    room_id: str | None = None
    last_room_entry_at: datetime | None = None
    last_room_exit_at: datetime | None = None
    last_room_detection_at: datetime | None = None
    notes: str = ""


class MovementEvent(CamelModel):
    id: str
    asset_id: str
    type: MovementType
    timestamp: datetime
    origin: EventOrigin
    status: MovementStatus
    access_id: str | None = None
    reader_id: str | None = None
    room_id: str | None = None
    responsible: str | None = None
    supplier_id: str | None = None
    reason: str = ""
    notes: str = ""
    related_operation_id: str | None = None
    alert_message: str | None = None


class Loan(CamelModel):
    id: str
    asset_id: str
    borrower: str
    delivered_at: datetime
    due_at: datetime | None = None
    reason: str = ""
    notes: str = ""
    status: LoanStatus = LoanStatus.active
    returned_at: datetime | None = None
    return_confirmed_inside: bool = False


class SupplierOperation(CamelModel):
    id: str
    supplier_id: str
    delivered_asset_ids: list[str] = Field(default_factory=list)
    received_asset_ids: list[str] = Field(default_factory=list)
    created_at: datetime
    delivered_at: datetime | None = None
    due_at: datetime | None = None
    reason: str = ""
    notes: str = ""
    status: SupplierOperationStatus = SupplierOperationStatus.prepared
    received_at: datetime | None = None


class Alert(CamelModel):
    id: str
    type: AlertType
    severity: AlertSeverity
    title: str
    message: str
    created_at: datetime
    asset_id: str | None = None
    simulated: bool = True
    resolved_at: datetime | None = None


class AppSettings(CamelModel):
    organization_name: str = "Sanatorio Modelo"
    app_name: str = "AssetTrack"
    outside_threshold_hours: int = 72
    dedupe_window_seconds: int = 30
    alert_detection_hours: int = 72
    rfid_source_name: str = "Lector RFID UHF simulado"
    rfid_source_status: str = "Simulada"
    rfid_connected: bool = False
    demo_mode: bool = False
    reader_antenna_count: int = 2
    theme_mode_name: str = "system"


class AppSnapshot(CamelModel):
    version: int = 1
    assets: list[Asset] = Field(default_factory=list)
    categories: list[AssetCategory] = Field(default_factory=list)
    accesses: list[AccessPoint] = Field(default_factory=list)
    zones: list[Zone] = Field(default_factory=list)
    readers: list[Reader] = Field(default_factory=list)
    suppliers: list[Supplier] = Field(default_factory=list)
    movements: list[MovementEvent] = Field(default_factory=list)
    loans: list[Loan] = Field(default_factory=list)
    supplier_operations: list[SupplierOperation] = Field(default_factory=list)
    alerts: list[Alert] = Field(default_factory=list)
    settings: AppSettings = Field(default_factory=AppSettings)
    saved_at: datetime


# ---------------------------------------------------------------------------
# Entradas de la API
# ---------------------------------------------------------------------------


class CategoryInput(CamelModel):
    name: str
    code_prefix: str
    description: str = ""


class AccessInput(CamelModel):
    name: str
    type: AccessType = AccessType.other
    description: str = ""
    reader_ids: list[str] = Field(default_factory=list)


class ZoneInput(CamelModel):
    name: str
    description: str = ""
    reader_ids: list[str] = Field(default_factory=list)


class ReaderInput(CamelModel):
    id: str | None = None
    name: str
    type: ReaderType = ReaderType.virtual
    status: ReaderStatus = ReaderStatus.active
    access_id: str | None = None
    zone_id: str | None = None
    antenna_count: int = 1
    protocol: ReaderProtocol = ReaderProtocol.none
    host: str = ""
    port: int | None = None
    topic: str = ""
    model: str = ""
    firmware: str = ""
    notes: str = ""


class SupplierInput(CamelModel):
    name: str
    service_type: str = ""
    contact: str = ""
    notes: str = ""


class AccessConfiguredInput(CamelModel):
    configured: bool


class ZoneActiveInput(CamelModel):
    active: bool


class ReaderStatusInput(CamelModel):
    status: ReaderStatus


class CorrectionInput(CamelModel):
    location: AssetLocation | None = None
    situation: AssetSituation | None = None
    operational_status: OperationalStatus | None = None
    room_id: str | None = None
    notes: str


class LoanCreateInput(CamelModel):
    asset_id: str
    borrower: str
    due_at: datetime | None = None
    reason: str = ""
    notes: str = ""
    access_id: str | None = None
    reader_id: str | None = None


class LoanReturnInput(CamelModel):
    confirmed_inside: bool = False
    administrative_correction: bool = False
    notes: str = ""


class SupplierOperationCreateInput(CamelModel):
    supplier_id: str
    asset_ids: list[str]
    due_at: datetime | None = None
    reason: str = ""
    notes: str = ""
    access_id: str | None = None
    reader_id: str | None = None
    origin: EventOrigin = EventOrigin.manual


class SupplierDeliverInput(CamelModel):
    access_id: str | None = None
    reader_id: str | None = None
    notes: str = ""


class SupplierReceiveInput(CamelModel):
    asset_ids: list[str]
    notes: str = ""
    access_id: str | None = None
    reader_id: str | None = None
    origin: EventOrigin = EventOrigin.manual


class SupplierNewAssetInput(CamelModel):
    code: str
    name: str
    category_id: str
    rfid_epc: str
    description: str = ""
    notes: str = ""


class SupplierCompleteInput(CamelModel):
    notes: str = ""


class RfidReadInput(CamelModel):
    epc: str
    reader_id: str
    access_id: str = ""
    timestamp: datetime
    direction_hint: str | None = None
    room_id: str | None = None
    antenna: int = 1
    rssi: float = -55
    origin: EventOrigin = EventOrigin.rfidRead


class PendingEventResolutionInput(CamelModel):
    approve: bool
    notes: str = ""


class ActionResult(CamelModel):
    success: bool
    message: str


class StateResponse(CamelModel):
    result: ActionResult
    state: AppSnapshot


class RfidReadResult(CamelModel):
    success: bool
    message: str
    recognised: bool = False
    duplicate: bool = False
    ambiguous: bool = False
    asset_id: str | None = None


class RfidReadsResponse(CamelModel):
    results: list[RfidReadResult]
    state: AppSnapshot


class MeResponse(CamelModel):
    user_id: str
    role: UserRole
    organization_id: str
    full_name: str | None = None
