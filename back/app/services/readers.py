"""Alta, edición y asignación de lectores/sensores RFID."""

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import AccessPoint, Reader, Zone
from app.schemas.models import ReaderInput
from app.services.ids import new_id


class ReaderValidationError(ValueError):
    """Error de validación de un lector."""


async def validate_reader_ids(
    session: AsyncSession,
    organization_id: str,
    reader_ids: list[str],
) -> None:
    """Valida que todos los IDs existan antes de modificar accesos o zonas."""
    for reader_id in dict.fromkeys(reader_ids):
        reader = await session.get(Reader, reader_id)
        if (
            reader is None
            or reader.organization_id != organization_id
            or reader.deleted_at is not None
        ):
            raise ReaderValidationError(f"El lector {reader_id} no existe.")


async def _validate_location(
    session: AsyncSession,
    organization_id: str,
    *,
    access_id: str | None,
    zone_id: str | None,
) -> None:
    if access_id is not None and zone_id is not None:
        raise ReaderValidationError(
            "Un lector no puede pertenecer a un acceso y a una habitación a la vez."
        )
    if access_id is not None:
        access = await session.get(AccessPoint, access_id)
        if access is None or access.organization_id != organization_id:
            raise ReaderValidationError("El acceso indicado no existe.")
    if zone_id is not None:
        zone = await session.get(Zone, zone_id)
        if zone is None or zone.organization_id != organization_id:
            raise ReaderValidationError("La habitación indicada no existe.")


async def create_reader(
    session: AsyncSession,
    organization_id: str,
    payload: ReaderInput,
) -> Reader:
    reader_id = payload.id or new_id("LEC")
    existing = await session.get(Reader, reader_id)
    if existing is not None:
        raise ReaderValidationError(f"El lector {reader_id} ya existe.")
    if not payload.name.strip():
        raise ReaderValidationError("El nombre del lector es obligatorio.")
    if payload.antenna_count < 1:
        raise ReaderValidationError("La cantidad de antenas debe ser mayor a cero.")
    await _validate_location(
        session,
        organization_id,
        access_id=payload.access_id,
        zone_id=payload.zone_id,
    )
    reader = Reader(
        id=reader_id,
        organization_id=organization_id,
        name=payload.name.strip(),
        type=payload.type.value,
        status=payload.status.value,
        access_id=payload.access_id,
        zone_id=payload.zone_id,
        antenna_count=payload.antenna_count,
        protocol=payload.protocol.value,
        host=payload.host.strip(),
        port=payload.port,
        topic=payload.topic.strip(),
        model=payload.model.strip(),
        firmware=payload.firmware.strip(),
        notes=payload.notes.strip(),
    )
    session.add(reader)
    await session.flush()
    return reader


async def update_reader(
    session: AsyncSession,
    organization_id: str,
    reader_id: str,
    payload: ReaderInput,
) -> Reader:
    reader = await session.get(Reader, reader_id)
    if reader is None or reader.organization_id != organization_id or reader.deleted_at is not None:
        raise ReaderValidationError("No se encontró el lector.")
    if not payload.name.strip():
        raise ReaderValidationError("El nombre del lector es obligatorio.")
    if payload.antenna_count < 1:
        raise ReaderValidationError("La cantidad de antenas debe ser mayor a cero.")
    await _validate_location(
        session,
        organization_id,
        access_id=payload.access_id,
        zone_id=payload.zone_id,
    )
    reader.name = payload.name.strip()
    reader.type = payload.type.value
    reader.status = payload.status.value
    reader.access_id = payload.access_id
    reader.zone_id = payload.zone_id
    reader.antenna_count = payload.antenna_count
    reader.protocol = payload.protocol.value
    reader.host = payload.host.strip()
    reader.port = payload.port
    reader.topic = payload.topic.strip()
    reader.model = payload.model.strip()
    reader.firmware = payload.firmware.strip()
    reader.notes = payload.notes.strip()
    await session.flush()
    return reader


async def set_reader_status(
    session: AsyncSession,
    organization_id: str,
    reader_id: str,
    status: str,
) -> Reader:
    reader = await session.get(Reader, reader_id)
    if reader is None or reader.organization_id != organization_id or reader.deleted_at is not None:
        raise ReaderValidationError("No se encontró el lector.")
    reader.status = status
    await session.flush()
    return reader


async def delete_reader(
    session: AsyncSession,
    organization_id: str,
    reader_id: str,
) -> Reader:
    reader = await session.get(Reader, reader_id)
    if reader is None or reader.organization_id != organization_id or reader.deleted_at is not None:
        raise ReaderValidationError("No se encontró el lector.")
    reader.deleted_at = datetime.now(timezone.utc)
    reader.status = "inactive"
    await session.flush()
    return reader


async def sync_access_readers(
    session: AsyncSession,
    organization_id: str,
    *,
    access_id: str,
    reader_ids: list[str],
) -> None:
    """Asigna exactamente los lectores indicados al acceso."""
    requested = set(reader_ids)
    current = (
        (
            await session.execute(
                select(Reader).where(
                    Reader.organization_id == organization_id,
                    Reader.access_id == access_id,
                    Reader.deleted_at.is_(None),
                )
            )
        )
        .scalars()
        .all()
    )
    for reader in current:
        if reader.id not in requested:
            reader.access_id = None
    for reader_id in requested:
        reader = await session.get(Reader, reader_id)
        if (
            reader is None
            or reader.organization_id != organization_id
            or reader.deleted_at is not None
        ):
            raise ReaderValidationError(f"El lector {reader_id} no existe.")
        reader.access_id = access_id
        reader.zone_id = None
    await session.flush()


async def sync_zone_readers(
    session: AsyncSession,
    organization_id: str,
    *,
    zone_id: str,
    reader_ids: list[str],
) -> None:
    """Asigna exactamente los sensores indicados a la habitación."""
    requested = set(reader_ids)
    current = (
        (
            await session.execute(
                select(Reader).where(
                    Reader.organization_id == organization_id,
                    Reader.zone_id == zone_id,
                    Reader.deleted_at.is_(None),
                )
            )
        )
        .scalars()
        .all()
    )
    for reader in current:
        if reader.id not in requested:
            reader.zone_id = None
    for reader_id in requested:
        reader = await session.get(Reader, reader_id)
        if (
            reader is None
            or reader.organization_id != organization_id
            or reader.deleted_at is not None
        ):
            raise ReaderValidationError(f"El sensor {reader_id} no existe.")
        reader.zone_id = zone_id
        reader.access_id = None
    await session.flush()
