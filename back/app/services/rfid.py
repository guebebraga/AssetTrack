"""Procesamiento de lecturas RFID y validación de lectores registrados."""

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import AccessPoint, Asset, Reader, Zone
from app.schemas.enums import EventOrigin, MovementStatus, MovementType
from app.schemas.models import RfidReadInput, RfidReadResult
from app.services.alerts import add_unknown_reader_alert
from app.services.movements import record, register_detection


async def _reject_reader(
    session: AsyncSession,
    organization_id: str,
    event: RfidReadInput,
    message: str,
) -> RfidReadResult:
    await add_unknown_reader_alert(
        session,
        organization_id,
        reader_id=event.reader_id,
        message=message,
    )
    return RfidReadResult(
        success=False,
        message=message,
        recognised=False,
    )


async def process_read(
    session: AsyncSession,
    organization_id: str,
    event: RfidReadInput,
    *,
    origin: EventOrigin = EventOrigin.rfidRead,
    dedupe_window_seconds: int = 30,
) -> RfidReadResult:
    """Valida el lector y aplica la lectura como movimiento o evento ambiguo."""
    reader = await session.get(Reader, event.reader_id)
    if reader is None or reader.organization_id != organization_id or reader.deleted_at is not None:
        return await _reject_reader(
            session,
            organization_id,
            event,
            f"El lector {event.reader_id} no está registrado. Un administrador debe darlo de alta.",
        )

    if reader.status != "active":
        return await _reject_reader(
            session,
            organization_id,
            event,
            f"El lector {reader.id} está en estado {reader.status} y no puede procesar lecturas.",
        )

    if event.room_id is not None:
        if reader.zone_id != event.room_id:
            return await _reject_reader(
                session,
                organization_id,
                event,
                f"El sensor {reader.id} no está asignado a la habitación {event.room_id}.",
            )
        zone = await session.get(Zone, event.room_id)
        if zone is None or zone.organization_id != organization_id or not zone.active:
            return await _reject_reader(
                session,
                organization_id,
                event,
                f"La habitación {event.room_id} no está activa o no existe.",
            )
    else:
        if reader.access_id is None:
            return await _reject_reader(
                session,
                organization_id,
                event,
                f"El lector {reader.id} no está asignado a ningún acceso.",
            )
        if event.access_id and reader.access_id != event.access_id:
            return await _reject_reader(
                session,
                organization_id,
                event,
                f"El lector {reader.id} no pertenece al acceso {event.access_id}.",
            )
        access = await session.get(AccessPoint, reader.access_id)
        if access is None or access.organization_id != organization_id or not access.configured:
            return await _reject_reader(
                session,
                organization_id,
                event,
                f"El acceso {reader.access_id} no está configurado.",
            )

    reader.last_seen_at = datetime.now(timezone.utc)

    asset_result = await session.execute(
        select(Asset).where(
            Asset.organization_id == organization_id,
            Asset.rfid_epc == event.epc.strip().upper(),
        )
    )
    asset = asset_result.scalar_one_or_none()
    if asset is None:
        return RfidReadResult(
            success=False,
            message=(
                f"EPC {event.epc} no está asociado a ningún activo registrado. "
                "Se requiere un flujo de alta controlado."
            ),
            recognised=False,
        )

    if event.room_id is not None:
        return await _process_room_read(
            session,
            organization_id,
            asset,
            reader,
            event,
            origin=origin,
            dedupe_window_seconds=dedupe_window_seconds,
        )

    if event.direction_hint is None:
        await register_detection(
            session,
            organization_id,
            asset_id=asset.id,
            timestamp=event.timestamp,
            access_id=reader.access_id,
            reader_id=reader.id,
            dedupe_window_seconds=dedupe_window_seconds,
        )
        result = await record(
            session,
            organization_id,
            asset_id=asset.id,
            movement_type=MovementType.ambiguousRead,
            timestamp=event.timestamp,
            origin=origin,
            status=MovementStatus.pendingReview,
            access_id=reader.access_id,
            reader_id=reader.id,
            reason="Lectura sin sentido de movimiento confirmado",
            alert_message=(
                f"La antena {event.antenna} recibió el EPC {event.epc} sin "
                "información suficiente para determinar el sentido."
            ),
            dedupe_window_seconds=dedupe_window_seconds,
        )
        return RfidReadResult(
            success=False,
            message=(
                f"{asset.code}: lectura ambigua guardada para revisión. No se "
                "modificó la ubicación."
            ),
            recognised=True,
            ambiguous=True,
            asset_id=asset.id,
        )

    movement_type = MovementType.entry if event.direction_hint == "inbound" else MovementType.exit
    result = await record(
        session,
        organization_id,
        asset_id=asset.id,
        movement_type=movement_type,
        timestamp=event.timestamp,
        origin=origin,
        access_id=reader.access_id,
        reader_id=reader.id,
        reason="Evento generado por lector RFID",
        check_duplicate=True,
        dedupe_window_seconds=dedupe_window_seconds,
    )
    return RfidReadResult(
        success=result.success,
        message=f"{asset.code}: {result.message}",
        recognised=True,
        duplicate=result.duplicate,
        asset_id=asset.id,
    )


async def _process_room_read(
    session: AsyncSession,
    organization_id: str,
    asset: Asset,
    reader: Reader,
    event: RfidReadInput,
    *,
    origin: EventOrigin,
    dedupe_window_seconds: int,
) -> RfidReadResult:
    zone = await session.get(Zone, event.room_id)
    if zone is None or zone.organization_id != organization_id:
        return RfidReadResult(
            success=False,
            message=(f"El sensor {reader.id} no está asociado a ninguna habitación configurada."),
            recognised=False,
        )

    if event.direction_hint is None:
        await register_detection(
            session,
            organization_id,
            asset_id=asset.id,
            timestamp=event.timestamp,
            access_id=None,
            reader_id=reader.id,
            room_id=zone.id,
            dedupe_window_seconds=dedupe_window_seconds,
        )
        await record(
            session,
            organization_id,
            asset_id=asset.id,
            movement_type=MovementType.ambiguousRead,
            timestamp=event.timestamp,
            origin=origin,
            status=MovementStatus.pendingReview,
            access_id=None,
            reader_id=reader.id,
            room_id=zone.id,
            reason="Lectura de habitación sin sentido confirmado",
            alert_message=(
                f"La antena {event.antenna} detectó el EPC {event.epc} en "
                f"{zone.name} sin información suficiente para determinar si "
                "entró o salió."
            ),
            dedupe_window_seconds=dedupe_window_seconds,
        )
        return RfidReadResult(
            success=False,
            message=(
                f"{asset.code}: lectura ambigua en {zone.name} guardada para "
                "revisión. No se modificó la habitación."
            ),
            recognised=True,
            ambiguous=True,
            asset_id=asset.id,
        )

    inbound = event.direction_hint == "inbound"
    movement_type = MovementType.roomEntry if inbound else MovementType.roomExit
    if inbound and asset.room_id is not None and asset.room_id != zone.id:
        movement_type = MovementType.roomTransfer

    result = await record(
        session,
        organization_id,
        asset_id=asset.id,
        movement_type=movement_type,
        timestamp=event.timestamp,
        origin=origin,
        access_id=None,
        reader_id=reader.id,
        room_id=zone.id,
        reason="Evento generado por sensor de habitación",
        check_duplicate=True,
        dedupe_window_seconds=dedupe_window_seconds,
    )
    return RfidReadResult(
        success=result.success,
        message=f"{asset.code}: {result.message} ({zone.name})",
        recognised=True,
        duplicate=result.duplicate,
        asset_id=asset.id,
    )
