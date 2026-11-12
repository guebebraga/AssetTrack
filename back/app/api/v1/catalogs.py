"""Endpoints de catálogos, configuración y sensores."""

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser, get_admin, get_current_user
from app.api.v1.common import finalize
from app.db.models import (
    AccessPoint,
    Asset,
    AssetCategory,
    Reader,
    Supplier,
    SupplierOperation,
    Zone,
)
from app.db.session import get_session
from app.schemas.models import (
    AccessConfiguredInput,
    AccessInput,
    CategoryInput,
    ReaderInput,
    ReaderStatusInput,
    StateResponse,
    SupplierInput,
    ZoneActiveInput,
    ZoneInput,
)
from app.schemas.models import (
    AppSettings as AppSettingsSchema,
)
from app.schemas.models import (
    Reader as ReaderSchema,
)
from app.services.ids import new_id
from app.services.readers import (
    ReaderValidationError,
    create_reader,
    delete_reader,
    set_reader_status,
    sync_access_readers,
    sync_zone_readers,
    update_reader,
    validate_reader_ids,
)
from app.services.state import get_settings_row

router = APIRouter(tags=["catálogos"])


@router.post("/categories", response_model=StateResponse)
async def add_category(
    payload: CategoryInput,
    user: CurrentUser = Depends(get_admin),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    if not payload.name.strip() or not payload.code_prefix.strip():
        return await finalize(
            session,
            user.organization_id,
            success=False,
            message="Nombre y prefijo son obligatorios.",
        )
    existing = await session.execute(
        select(AssetCategory).where(
            AssetCategory.organization_id == user.organization_id,
            AssetCategory.name.ilike(payload.name.strip()),
        )
    )
    if existing.scalar_one_or_none() is not None:
        return await finalize(
            session,
            user.organization_id,
            success=False,
            message="La categoría ya existe.",
        )
    session.add(
        AssetCategory(
            id=new_id("CAT"),
            organization_id=user.organization_id,
            name=payload.name.strip(),
            code_prefix=payload.code_prefix.strip().upper(),
            description=payload.description.strip(),
        )
    )
    await session.flush()
    return await finalize(session, user.organization_id, success=True, message="Categoría creada.")


@router.post("/accesses", response_model=StateResponse)
async def add_access(
    payload: AccessInput,
    user: CurrentUser = Depends(get_admin),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    if not payload.name.strip():
        return await finalize(
            session,
            user.organization_id,
            success=False,
            message="El nombre del acceso es obligatorio.",
        )
    try:
        await validate_reader_ids(session, user.organization_id, payload.reader_ids)
    except ReaderValidationError as exc:
        return await finalize(session, user.organization_id, success=False, message=str(exc))

    access = AccessPoint(
        id=new_id("ACC"),
        organization_id=user.organization_id,
        name=payload.name.strip(),
        type=payload.type.value,
        description=payload.description.strip(),
        configured=True,
    )
    session.add(access)
    await session.flush()
    await sync_access_readers(
        session,
        user.organization_id,
        access_id=access.id,
        reader_ids=payload.reader_ids,
    )
    return await finalize(session, user.organization_id, success=True, message="Acceso agregado.")


@router.put("/accesses/{access_id}", response_model=StateResponse)
async def update_access(
    access_id: str,
    payload: AccessInput,
    user: CurrentUser = Depends(get_admin),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    access = await session.get(AccessPoint, access_id)
    if access is None or access.organization_id != user.organization_id:
        return await finalize(
            session, user.organization_id, success=False, message="No se encontró el acceso."
        )
    if not payload.name.strip():
        return await finalize(
            session,
            user.organization_id,
            success=False,
            message="El nombre del acceso es obligatorio.",
        )
    try:
        await validate_reader_ids(session, user.organization_id, payload.reader_ids)
    except ReaderValidationError as exc:
        return await finalize(session, user.organization_id, success=False, message=str(exc))

    access.name = payload.name.strip()
    access.type = payload.type.value
    access.description = payload.description.strip()
    await sync_access_readers(
        session,
        user.organization_id,
        access_id=access.id,
        reader_ids=payload.reader_ids,
    )
    await session.flush()
    return await finalize(
        session, user.organization_id, success=True, message="Acceso actualizado."
    )


@router.patch("/accesses/{access_id}", response_model=StateResponse)
async def configure_access(
    access_id: str,
    payload: AccessConfiguredInput,
    user: CurrentUser = Depends(get_admin),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    access = await session.get(AccessPoint, access_id)
    if access is None or access.organization_id != user.organization_id:
        return await finalize(
            session, user.organization_id, success=False, message="No se encontró el acceso."
        )
    access.configured = payload.configured
    await session.flush()
    return await finalize(
        session,
        user.organization_id,
        success=True,
        message="Estado del acceso actualizado.",
    )


@router.post("/zones", response_model=StateResponse)
async def add_zone(
    payload: ZoneInput,
    user: CurrentUser = Depends(get_admin),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    if not payload.name.strip():
        return await finalize(
            session,
            user.organization_id,
            success=False,
            message="El nombre de la habitación es obligatorio.",
        )
    existing = await session.execute(
        select(Zone).where(
            Zone.organization_id == user.organization_id,
            Zone.name.ilike(payload.name.strip()),
        )
    )
    if existing.scalar_one_or_none() is not None:
        return await finalize(
            session,
            user.organization_id,
            success=False,
            message="La habitación ya existe.",
        )
    try:
        await validate_reader_ids(session, user.organization_id, payload.reader_ids)
    except ReaderValidationError as exc:
        return await finalize(session, user.organization_id, success=False, message=str(exc))

    zone = Zone(
        id=new_id("ZON"),
        organization_id=user.organization_id,
        name=payload.name.strip(),
        description=payload.description.strip(),
        active=True,
    )
    session.add(zone)
    await session.flush()
    await sync_zone_readers(
        session,
        user.organization_id,
        zone_id=zone.id,
        reader_ids=payload.reader_ids,
    )
    return await finalize(
        session, user.organization_id, success=True, message="Habitación agregada."
    )


@router.put("/zones/{zone_id}", response_model=StateResponse)
async def update_zone(
    zone_id: str,
    payload: ZoneInput,
    user: CurrentUser = Depends(get_admin),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    zone = await session.get(Zone, zone_id)
    if zone is None or zone.organization_id != user.organization_id:
        return await finalize(
            session, user.organization_id, success=False, message="No se encontró la habitación."
        )
    if not payload.name.strip():
        return await finalize(
            session,
            user.organization_id,
            success=False,
            message="El nombre de la habitación es obligatorio.",
        )
    try:
        await validate_reader_ids(session, user.organization_id, payload.reader_ids)
    except ReaderValidationError as exc:
        return await finalize(session, user.organization_id, success=False, message=str(exc))

    zone.name = payload.name.strip()
    zone.description = payload.description.strip()
    await sync_zone_readers(
        session,
        user.organization_id,
        zone_id=zone.id,
        reader_ids=payload.reader_ids,
    )
    await session.flush()
    return await finalize(
        session, user.organization_id, success=True, message="Habitación actualizada."
    )


@router.patch("/zones/{zone_id}", response_model=StateResponse)
async def configure_zone(
    zone_id: str,
    payload: ZoneActiveInput,
    user: CurrentUser = Depends(get_admin),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    zone = await session.get(Zone, zone_id)
    if zone is None or zone.organization_id != user.organization_id:
        return await finalize(
            session, user.organization_id, success=False, message="No se encontró la habitación."
        )
    zone.active = payload.active
    await session.flush()
    return await finalize(
        session,
        user.organization_id,
        success=True,
        message="Estado de la habitación actualizado.",
    )


@router.get("/readers", response_model=list[ReaderSchema])
async def list_readers(
    user: CurrentUser = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[ReaderSchema]:
    """Lista los lectores activos y no eliminados de la organización."""
    result = await session.execute(
        select(Reader)
        .where(
            Reader.organization_id == user.organization_id,
            Reader.deleted_at.is_(None),
        )
        .order_by(Reader.name)
    )
    return [ReaderSchema.model_validate(reader) for reader in result.scalars().all()]


@router.post("/readers", response_model=StateResponse)
async def add_reader(
    payload: ReaderInput,
    user: CurrentUser = Depends(get_admin),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    try:
        reader = await create_reader(session, user.organization_id, payload)
    except ReaderValidationError as exc:
        return await finalize(session, user.organization_id, success=False, message=str(exc))
    return await finalize(
        session,
        user.organization_id,
        success=True,
        message=f"Lector {reader.id} creado correctamente.",
    )


@router.put("/readers/{reader_id}", response_model=StateResponse)
async def edit_reader(
    reader_id: str,
    payload: ReaderInput,
    user: CurrentUser = Depends(get_admin),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    try:
        reader = await update_reader(session, user.organization_id, reader_id, payload)
    except ReaderValidationError as exc:
        return await finalize(session, user.organization_id, success=False, message=str(exc))
    return await finalize(
        session,
        user.organization_id,
        success=True,
        message=f"Lector {reader.id} actualizado.",
    )


@router.patch("/readers/{reader_id}/status", response_model=StateResponse)
async def change_reader_status(
    reader_id: str,
    payload: ReaderStatusInput,
    user: CurrentUser = Depends(get_admin),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    try:
        reader = await set_reader_status(
            session, user.organization_id, reader_id, payload.status.value
        )
    except ReaderValidationError as exc:
        return await finalize(session, user.organization_id, success=False, message=str(exc))
    return await finalize(
        session,
        user.organization_id,
        success=True,
        message=f"Estado del lector {reader.id} actualizado.",
    )


@router.delete("/readers/{reader_id}", response_model=StateResponse)
async def remove_reader(
    reader_id: str,
    user: CurrentUser = Depends(get_admin),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    try:
        reader = await delete_reader(session, user.organization_id, reader_id)
    except ReaderValidationError as exc:
        return await finalize(session, user.organization_id, success=False, message=str(exc))
    return await finalize(
        session,
        user.organization_id,
        success=True,
        message=f"Lector {reader.id} dado de baja.",
    )


@router.post("/suppliers", response_model=StateResponse)
async def add_supplier(
    payload: SupplierInput,
    user: CurrentUser = Depends(get_admin),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    if not payload.name.strip():
        return await finalize(
            session,
            user.organization_id,
            success=False,
            message="El nombre del proveedor es obligatorio.",
        )
    session.add(
        Supplier(
            id=new_id("SUP"),
            organization_id=user.organization_id,
            name=payload.name.strip(),
            service_type=payload.service_type.strip(),
            contact=payload.contact.strip(),
            notes=payload.notes.strip(),
        )
    )
    await session.flush()
    return await finalize(
        session, user.organization_id, success=True, message="Proveedor agregado."
    )


@router.put("/suppliers/{supplier_id}", response_model=StateResponse)
async def update_supplier(
    supplier_id: str,
    payload: SupplierInput,
    user: CurrentUser = Depends(get_admin),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    supplier = await session.get(Supplier, supplier_id)
    if supplier is None or supplier.organization_id != user.organization_id:
        return await finalize(
            session, user.organization_id, success=False, message="No se encontró el proveedor."
        )
    supplier.name = payload.name.strip()
    supplier.service_type = payload.service_type.strip()
    supplier.contact = payload.contact.strip()
    supplier.notes = payload.notes.strip()
    await session.flush()
    return await finalize(
        session, user.organization_id, success=True, message="Proveedor actualizado."
    )


@router.delete("/suppliers/{supplier_id}", response_model=StateResponse)
async def remove_supplier(
    supplier_id: str,
    user: CurrentUser = Depends(get_admin),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    supplier = await session.get(Supplier, supplier_id)
    if supplier is None or supplier.organization_id != user.organization_id:
        return await finalize(
            session, user.organization_id, success=False, message="No se encontró el proveedor."
        )
    used_by_asset = await session.execute(
        select(Asset.id).where(
            Asset.organization_id == user.organization_id,
            Asset.supplier_id == supplier_id,
        )
    )
    used_by_operation = await session.execute(
        select(SupplierOperation.id).where(
            SupplierOperation.organization_id == user.organization_id,
            SupplierOperation.supplier_id == supplier_id,
        )
    )
    if used_by_asset.first() is not None or used_by_operation.first() is not None:
        supplier.active = False
        message = "El proveedor tiene operaciones asociadas. Se marcó como inactivo."
    else:
        await session.delete(supplier)
        message = "Proveedor eliminado."
    await session.flush()
    return await finalize(session, user.organization_id, success=True, message=message)


@router.put("/settings", response_model=StateResponse)
async def update_settings(
    payload: AppSettingsSchema,
    user: CurrentUser = Depends(get_admin),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    if (
        payload.outside_threshold_hours < 1
        or payload.alert_detection_hours < 1
        or payload.dedupe_window_seconds < 1
    ):
        return await finalize(
            session,
            user.organization_id,
            success=False,
            message="Los umbrales deben ser mayores a cero.",
        )
    settings = await get_settings_row(session, user.organization_id)
    settings.organization_name = payload.organization_name
    settings.app_name = payload.app_name
    settings.outside_threshold_hours = payload.outside_threshold_hours
    settings.dedupe_window_seconds = payload.dedupe_window_seconds
    settings.alert_detection_hours = payload.alert_detection_hours
    settings.rfid_source_name = payload.rfid_source_name
    settings.rfid_source_status = payload.rfid_source_status
    settings.rfid_connected = payload.rfid_connected
    settings.demo_mode = payload.demo_mode
    settings.reader_antenna_count = payload.reader_antenna_count
    settings.theme_mode_name = payload.theme_mode_name
    await session.flush()
    return await finalize(
        session, user.organization_id, success=True, message="Configuración guardada."
    )
