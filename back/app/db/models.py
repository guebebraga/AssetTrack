"""Modelos SQLAlchemy.

Las columnas usan snake_case y los esquemas de la API usan camelCase.
Así la base queda prolija y el frontend mantiene el contrato actual.
"""

from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    """Base declarativa de todos los modelos."""


class Organization(Base):
    __tablename__ = "organizations"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class Profile(Base):
    """Perfil de aplicación asociado a un usuario de Supabase Auth."""

    __tablename__ = "profiles"
    __table_args__ = (
        CheckConstraint("role IN ('admin','operator','viewer')", name="profiles_role_check"),
    )

    user_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    organization_id: Mapped[str] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False
    )
    role: Mapped[str] = mapped_column(String(16), nullable=False, default="viewer")
    full_name: Mapped[str | None] = mapped_column(String(160))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class AssetCategory(Base):
    __tablename__ = "asset_categories"
    __table_args__ = (
        UniqueConstraint("organization_id", "name", name="asset_categories_org_name_key"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    organization_id: Mapped[str] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    code_prefix: Mapped[str] = mapped_column(String(16), nullable=False, default="")
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")


class AccessPoint(Base):
    __tablename__ = "access_points"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    organization_id: Mapped[str] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    type: Mapped[str] = mapped_column(String(24), nullable=False, default="other")
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    configured: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class Zone(Base):
    __tablename__ = "zones"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    organization_id: Mapped[str] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class Reader(Base):
    """Lector o sensor RFID registrado.

    Un lector puede pertenecer a un acceso o a una habitación, nunca a ambos.
    Puede quedar sin asignar mientras está en inventario o pendiente de alta.
    """

    __tablename__ = "readers"
    __table_args__ = (
        UniqueConstraint("organization_id", "id", name="readers_org_id_key"),
        CheckConstraint(
            "NOT (access_id IS NOT NULL AND zone_id IS NOT NULL)",
            name="readers_single_location_check",
        ),
        CheckConstraint("antenna_count >= 1", name="readers_antenna_count_check"),
        CheckConstraint(
            "type IN ('fixed_uhf','handheld','room_sensor','virtual')",
            name="readers_type_check",
        ),
        CheckConstraint(
            "status IN ('active','inactive','maintenance')",
            name="readers_status_check",
        ),
        CheckConstraint(
            "protocol IN ('llrp','mqtt','http','sdk','none')",
            name="readers_protocol_check",
        ),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    organization_id: Mapped[str] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    type: Mapped[str] = mapped_column(String(24), nullable=False, default="virtual")
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="active")
    access_id: Mapped[str | None] = mapped_column(
        ForeignKey("access_points.id", ondelete="SET NULL")
    )
    zone_id: Mapped[str | None] = mapped_column(ForeignKey("zones.id", ondelete="SET NULL"))
    antenna_count: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    protocol: Mapped[str] = mapped_column(String(16), nullable=False, default="none")
    host: Mapped[str] = mapped_column(String(160), nullable=False, default="")
    port: Mapped[int | None] = mapped_column(Integer)
    topic: Mapped[str] = mapped_column(String(160), nullable=False, default="")
    model: Mapped[str] = mapped_column(String(120), nullable=False, default="")
    firmware: Mapped[str] = mapped_column(String(80), nullable=False, default="")
    notes: Mapped[str] = mapped_column(Text, nullable=False, default="")
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Supplier(Base):
    __tablename__ = "suppliers"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    organization_id: Mapped[str] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    service_type: Mapped[str] = mapped_column(String(120), nullable=False, default="")
    contact: Mapped[str] = mapped_column(String(160), nullable=False, default="")
    notes: Mapped[str] = mapped_column(Text, nullable=False, default="")
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)


class Asset(Base):
    __tablename__ = "assets"
    __table_args__ = (
        UniqueConstraint("organization_id", "code", name="assets_org_code_key"),
        UniqueConstraint("organization_id", "rfid_epc", name="assets_org_epc_key"),
        CheckConstraint(
            "location IN ('inside','outside','unknown','pendingVerification')",
            name="assets_location_check",
        ),
        CheckConstraint(
            "situation IN ("
            "'available','inUse','onLoan','atSupplier','pendingReturn','maintenance'"
            ")",
            name="assets_situation_check",
        ),
        CheckConstraint(
            "operational_status IN ('operational','needsInspection','outOfService')",
            name="assets_operational_status_check",
        ),
        Index("assets_org_location_idx", "organization_id", "location"),
        Index("assets_org_situation_idx", "organization_id", "situation"),
        Index("assets_org_epc_idx", "organization_id", "rfid_epc"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    organization_id: Mapped[str] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False
    )
    code: Mapped[str] = mapped_column(String(64), nullable=False)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    category_id: Mapped[str] = mapped_column(
        ForeignKey("asset_categories.id", ondelete="RESTRICT"), nullable=False
    )
    description: Mapped[str] = mapped_column(Text, nullable=False, default="")
    rfid_epc: Mapped[str] = mapped_column(String(128), nullable=False)
    location: Mapped[str] = mapped_column(String(24), nullable=False, default="unknown")
    situation: Mapped[str] = mapped_column(String(24), nullable=False, default="available")
    operational_status: Mapped[str] = mapped_column(
        String(24), nullable=False, default="operational"
    )
    last_detection_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_entry_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_exit_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_movement_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    responsible: Mapped[str | None] = mapped_column(String(160))
    supplier_id: Mapped[str | None] = mapped_column(ForeignKey("suppliers.id", ondelete="SET NULL"))
    expected_return_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    last_access_id: Mapped[str | None] = mapped_column(
        ForeignKey("access_points.id", ondelete="SET NULL")
    )
    last_reader_id: Mapped[str | None] = mapped_column(
        ForeignKey("readers.id", ondelete="SET NULL")
    )
    room_id: Mapped[str | None] = mapped_column(ForeignKey("zones.id", ondelete="SET NULL"))
    last_room_entry_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_room_exit_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_room_detection_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    notes: Mapped[str] = mapped_column(Text, nullable=False, default="")


class MovementEvent(Base):
    __tablename__ = "movement_events"
    __table_args__ = (
        CheckConstraint(
            "type IN ('entry','exit','loan','loanReturn','supplierDelivery',"
            "'supplierReceipt','sendForRefill','receiveAfterRefill','unitExchange',"
            "'roomEntry','roomExit','roomTransfer','adminAdjustment','ambiguousRead',"
            "'inventoryCorrection')",
            name="movement_events_type_check",
        ),
        CheckConstraint(
            "status IN ('confirmed','pendingReview','rejected')",
            name="movement_events_status_check",
        ),
        CheckConstraint(
            "origin IN ('rfidRead','manual','simulator','system','correction')",
            name="movement_events_origin_check",
        ),
        Index("movement_events_asset_ts_idx", "asset_id", "timestamp"),
        Index("movement_events_org_status_idx", "organization_id", "status"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    organization_id: Mapped[str] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False
    )
    asset_id: Mapped[str] = mapped_column(
        ForeignKey("assets.id", ondelete="CASCADE"), nullable=False
    )
    type: Mapped[str] = mapped_column(String(32), nullable=False)
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    origin: Mapped[str] = mapped_column(String(24), nullable=False, default="manual")
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="confirmed")
    access_id: Mapped[str | None] = mapped_column(String(64))
    reader_id: Mapped[str | None] = mapped_column(String(64))
    room_id: Mapped[str | None] = mapped_column(String(64))
    responsible: Mapped[str | None] = mapped_column(String(160))
    supplier_id: Mapped[str | None] = mapped_column(String(64))
    reason: Mapped[str] = mapped_column(Text, nullable=False, default="")
    notes: Mapped[str] = mapped_column(Text, nullable=False, default="")
    related_operation_id: Mapped[str | None] = mapped_column(String(64))
    alert_message: Mapped[str | None] = mapped_column(Text)


class Loan(Base):
    __tablename__ = "loans"
    __table_args__ = (
        CheckConstraint(
            "status IN ('active','returned','overdue','pendingVerification')",
            name="loans_status_check",
        ),
        Index("loans_asset_idx", "asset_id"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    organization_id: Mapped[str] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False
    )
    asset_id: Mapped[str] = mapped_column(
        ForeignKey("assets.id", ondelete="CASCADE"), nullable=False
    )
    borrower: Mapped[str] = mapped_column(String(160), nullable=False)
    delivered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    due_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    reason: Mapped[str] = mapped_column(Text, nullable=False, default="")
    notes: Mapped[str] = mapped_column(Text, nullable=False, default="")
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="active")
    returned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    return_confirmed_inside: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)


class SupplierOperation(Base):
    __tablename__ = "supplier_operations"
    __table_args__ = (
        CheckConstraint(
            "status IN ('prepared','delivered','partiallyReceived','completed','pendingReview')",
            name="supplier_operations_status_check",
        ),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    organization_id: Mapped[str] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False
    )
    supplier_id: Mapped[str] = mapped_column(
        ForeignKey("suppliers.id", ondelete="RESTRICT"), nullable=False
    )
    delivered_asset_ids: Mapped[list[str]] = mapped_column(
        ARRAY(Text), nullable=False, default=list, server_default=text("'{}'::text[]")
    )
    received_asset_ids: Mapped[list[str]] = mapped_column(
        ARRAY(Text), nullable=False, default=list, server_default=text("'{}'::text[]")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    delivered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    due_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    reason: Mapped[str] = mapped_column(Text, nullable=False, default="")
    notes: Mapped[str] = mapped_column(Text, nullable=False, default="")
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="prepared")
    received_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Alert(Base):
    __tablename__ = "alerts"
    __table_args__ = (
        CheckConstraint("severity IN ('info','warning','critical')", name="alerts_severity_check"),
        CheckConstraint(
            "type IN ('outsideTooLong','loanOverdue','supplierPending',"
            "'incompleteReturn','ambiguousRead','noRecentDetection',"
            "'incompatibleMovement','unknownReader')",
            name="alerts_type_check",
        ),
        Index("alerts_org_open_idx", "organization_id", "resolved_at"),
    )

    id: Mapped[str] = mapped_column(String(160), primary_key=True)
    organization_id: Mapped[str] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False
    )
    type: Mapped[str] = mapped_column(String(32), nullable=False)
    severity: Mapped[str] = mapped_column(String(16), nullable=False, default="info")
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    asset_id: Mapped[str | None] = mapped_column(String(64))
    simulated: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    source: Mapped[str] = mapped_column(String(16), nullable=False, default="system")


class AppSettings(Base):
    __tablename__ = "app_settings"

    organization_id: Mapped[str] = mapped_column(
        ForeignKey("organizations.id", ondelete="CASCADE"), primary_key=True
    )
    organization_name: Mapped[str] = mapped_column(
        String(160), nullable=False, default="Sanatorio Modelo"
    )
    app_name: Mapped[str] = mapped_column(String(80), nullable=False, default="AssetTrack")
    outside_threshold_hours: Mapped[int] = mapped_column(Integer, nullable=False, default=72)
    dedupe_window_seconds: Mapped[int] = mapped_column(Integer, nullable=False, default=30)
    alert_detection_hours: Mapped[int] = mapped_column(Integer, nullable=False, default=72)
    rfid_source_name: Mapped[str] = mapped_column(
        String(120), nullable=False, default="Lector RFID UHF simulado"
    )
    rfid_source_status: Mapped[str] = mapped_column(String(40), nullable=False, default="Simulada")
    rfid_connected: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    demo_mode: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    reader_antenna_count: Mapped[int] = mapped_column(Integer, nullable=False, default=2)
    theme_mode_name: Mapped[str] = mapped_column(String(16), nullable=False, default="system")


class IdempotencyKey(Base):
    """Registro de mutaciones ya procesadas para soportar reintentos offline."""

    __tablename__ = "idempotency_keys"

    key: Mapped[str] = mapped_column(String(120), primary_key=True)
    endpoint: Mapped[str] = mapped_column(String(200), nullable=False)
    response_json: Mapped[dict] = mapped_column(
        JSONB, nullable=False, default=dict, server_default=text("'{}'::jsonb")
    )
    status_code: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default=text("0")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
