"""Carga del snapshot completo y datos iniciales mínimos."""

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.db.models import (
    AccessPoint,
    Alert,
    AppSettings,
    Asset,
    AssetCategory,
    Loan,
    MovementEvent,
    Organization,
    Reader,
    Supplier,
    SupplierOperation,
    Zone,
)
from app.schemas.models import (
    AccessPoint as AccessPointSchema,
)
from app.schemas.models import (
    Alert as AlertSchema,
)
from app.schemas.models import (
    AppSettings as AppSettingsSchema,
)
from app.schemas.models import (
    AppSnapshot,
)
from app.schemas.models import (
    Asset as AssetSchema,
)
from app.schemas.models import (
    AssetCategory as AssetCategorySchema,
)
from app.schemas.models import (
    Loan as LoanSchema,
)
from app.schemas.models import (
    MovementEvent as MovementEventSchema,
)
from app.schemas.models import (
    Reader as ReaderSchema,
)
from app.schemas.models import (
    Supplier as SupplierSchema,
)
from app.schemas.models import (
    SupplierOperation as SupplierOperationSchema,
)
from app.schemas.models import (
    Zone as ZoneSchema,
)


async def get_settings_row(session: AsyncSession, organization_id: str) -> AppSettings:
    """Devuelve la configuración de la organización, creándola si no existe."""
    settings = await session.get(AppSettings, organization_id)
    if settings is not None:
        return settings
    settings = AppSettings(
        organization_id=organization_id,
        organization_name=get_settings().default_organization_name,
        demo_mode=False,
    )
    session.add(settings)
    await session.flush()
    return settings


async def load_snapshot(session: AsyncSession, organization_id: str) -> AppSnapshot:
    """Construye el snapshot que consume el frontend."""
    categories = (
        (
            await session.execute(
                select(AssetCategory)
                .where(AssetCategory.organization_id == organization_id)
                .order_by(AssetCategory.name)
            )
        )
        .scalars()
        .all()
    )
    accesses = (
        (
            await session.execute(
                select(AccessPoint)
                .where(AccessPoint.organization_id == organization_id)
                .order_by(AccessPoint.name)
            )
        )
        .scalars()
        .all()
    )
    zones = (
        (
            await session.execute(
                select(Zone).where(Zone.organization_id == organization_id).order_by(Zone.name)
            )
        )
        .scalars()
        .all()
    )
    readers = (
        (
            await session.execute(
                select(Reader)
                .where(
                    Reader.organization_id == organization_id,
                    Reader.deleted_at.is_(None),
                )
                .order_by(Reader.name)
            )
        )
        .scalars()
        .all()
    )
    suppliers = (
        (
            await session.execute(
                select(Supplier)
                .where(Supplier.organization_id == organization_id)
                .order_by(Supplier.name)
            )
        )
        .scalars()
        .all()
    )
    assets = (
        (
            await session.execute(
                select(Asset).where(Asset.organization_id == organization_id).order_by(Asset.code)
            )
        )
        .scalars()
        .all()
    )
    movements = (
        (
            await session.execute(
                select(MovementEvent)
                .where(MovementEvent.organization_id == organization_id)
                .order_by(MovementEvent.timestamp.desc())
            )
        )
        .scalars()
        .all()
    )
    loans = (
        (
            await session.execute(
                select(Loan)
                .where(Loan.organization_id == organization_id)
                .order_by(Loan.delivered_at.desc())
            )
        )
        .scalars()
        .all()
    )
    operations = (
        (
            await session.execute(
                select(SupplierOperation)
                .where(SupplierOperation.organization_id == organization_id)
                .order_by(SupplierOperation.created_at.desc())
            )
        )
        .scalars()
        .all()
    )
    alerts = (
        (
            await session.execute(
                select(Alert)
                .where(Alert.organization_id == organization_id)
                .order_by(Alert.created_at.desc())
            )
        )
        .scalars()
        .all()
    )
    settings = await get_settings_row(session, organization_id)

    readers_by_access: dict[str, list[str]] = {}
    readers_by_zone: dict[str, list[str]] = {}
    for reader in readers:
        if reader.access_id is not None:
            readers_by_access.setdefault(reader.access_id, []).append(reader.id)
        if reader.zone_id is not None:
            readers_by_zone.setdefault(reader.zone_id, []).append(reader.id)

    return AppSnapshot(
        version=1,
        assets=[AssetSchema.model_validate(asset) for asset in assets],
        categories=[AssetCategorySchema.model_validate(category) for category in categories],
        accesses=[
            AccessPointSchema(
                id=access.id,
                name=access.name,
                type=access.type,
                description=access.description,
                reader_ids=readers_by_access.get(access.id, []),
                configured=access.configured,
            )
            for access in accesses
        ],
        zones=[
            ZoneSchema(
                id=zone.id,
                name=zone.name,
                description=zone.description,
                reader_ids=readers_by_zone.get(zone.id, []),
                active=zone.active,
            )
            for zone in zones
        ],
        readers=[ReaderSchema.model_validate(reader) for reader in readers],
        suppliers=[SupplierSchema.model_validate(supplier) for supplier in suppliers],
        movements=[MovementEventSchema.model_validate(movement) for movement in movements],
        loans=[LoanSchema.model_validate(loan) for loan in loans],
        supplier_operations=[
            SupplierOperationSchema.model_validate(operation) for operation in operations
        ],
        alerts=[AlertSchema.model_validate(alert) for alert in alerts],
        settings=AppSettingsSchema.model_validate(settings),
        saved_at=datetime.now(timezone.utc),
    )


async def ensure_bootstrap(session: AsyncSession, organization_id: str | None = None) -> None:
    """Crea organización, configuración y catálogos mínimos.

    No crea activos ficticios. Solo deja el sistema listo para operar y un
    lector virtual para pruebas desde el simulador.
    """
    app_settings = get_settings()
    org_id = organization_id or app_settings.default_organization_id

    organization = await session.get(Organization, org_id)
    if organization is None:
        session.add(Organization(id=org_id, name=app_settings.default_organization_name))
        await session.flush()

    await get_settings_row(session, org_id)

    categories = [
        ("cat-oxigeno", "Oxígeno", "O2", "Balones y contenedores de oxígeno."),
        ("cat-equipamiento", "Equipamiento", "EQP", "Equipos médicos y accesorios."),
        ("cat-mobiliario", "Mobiliario", "MOB", "Mobiliario clínico."),
    ]
    for category_id, name, prefix, description in categories:
        if await session.get(AssetCategory, category_id) is None:
            session.add(
                AssetCategory(
                    id=category_id,
                    organization_id=org_id,
                    name=name,
                    code_prefix=prefix,
                    description=description,
                )
            )

    accesses = [
        ("acc-principal", "Entrada principal", "main", "Acceso principal."),
        ("acc-proveedores", "Entrada de proveedores", "supplier", "Andén de proveedores."),
        ("acc-servicio", "Acceso de servicio", "service", "Acceso de personal."),
    ]
    for access_id, name, access_type, description in accesses:
        if await session.get(AccessPoint, access_id) is None:
            session.add(
                AccessPoint(
                    id=access_id,
                    organization_id=org_id,
                    name=name,
                    type=access_type,
                    description=description,
                    configured=True,
                )
            )

    zones = [
        ("zon-uti", "Unidad de Terapia Intensiva", "Área crítica."),
        ("zon-guardia", "Guardia", "Área de urgencias."),
    ]
    for zone_id, name, description in zones:
        if await session.get(Zone, zone_id) is None:
            session.add(
                Zone(
                    id=zone_id,
                    organization_id=org_id,
                    name=name,
                    description=description,
                    active=True,
                )
            )

    if await session.get(Reader, "LEC-VIRTUAL-01") is None:
        session.add(
            Reader(
                id="LEC-VIRTUAL-01",
                organization_id=org_id,
                name="Lector virtual de pruebas",
                type="virtual",
                status="active",
                access_id="acc-principal",
                antenna_count=1,
                protocol="none",
                notes="Lector virtual para probar el simulador sin hardware.",
            )
        )

    await session.flush()
