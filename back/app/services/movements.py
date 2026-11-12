"""Registro de movimientos, deduplicación y aplicación al inventario."""

from dataclasses import dataclass
from datetime import datetime, timezone

from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Asset, MovementEvent
from app.schemas.enums import (
    AssetLocation,
    AssetSituation,
    EventOrigin,
    MovementStatus,
    MovementType,
)
from app.services.ids import new_id
from app.services.inventory import validate_transition


@dataclass
class MovementResult:
    success: bool
    message: str
    event: MovementEvent | None = None
    duplicate: bool = False
    asset: Asset | None = None

    @staticmethod
    def failure(message: str, *, asset: Asset | None = None) -> "MovementResult":
        return MovementResult(success=False, message=message, asset=asset)


async def _last_confirmed(
    session: AsyncSession,
    organization_id: str,
    asset_id: str,
    movement_type: MovementType,
) -> MovementEvent | None:
    result = await session.execute(
        select(MovementEvent)
        .where(
            MovementEvent.organization_id == organization_id,
            MovementEvent.asset_id == asset_id,
            MovementEvent.type == movement_type.value,
            MovementEvent.status == MovementStatus.confirmed.value,
        )
        .order_by(desc(MovementEvent.timestamp))
        .limit(1)
    )
    return result.scalar_one_or_none()


async def _is_duplicate(
    session: AsyncSession,
    organization_id: str,
    asset_id: str,
    movement_type: MovementType,
    timestamp: datetime,
    access_id: str | None,
    room_id: str | None,
    dedupe_window_seconds: int,
) -> bool:
    last = await _last_confirmed(session, organization_id, asset_id, movement_type)
    if last is None:
        return False
    difference = abs((timestamp - last.timestamp).total_seconds())
    if difference > dedupe_window_seconds:
        return False
    if access_id is not None and last.access_id is not None and last.access_id != access_id:
        return False
    if room_id is not None and last.room_id is not None and last.room_id != room_id:
        return False
    return True


def apply_movement_to_asset(
    asset: Asset,
    movement_type: MovementType,
    timestamp: datetime,
    *,
    room_id: str | None = None,
    responsible: str | None = None,
    supplier_id: str | None = None,
    expected_return_at: datetime | None = None,
) -> None:
    """Aplica el efecto del movimiento sobre el activo."""
    asset.last_detection_at = timestamp
    if room_id is not None:
        asset.last_room_detection_at = timestamp

    if movement_type == MovementType.entry:
        if asset.situation == AssetSituation.pendingReturn.value:
            asset.situation = AssetSituation.available.value
        asset.location = AssetLocation.inside.value
        asset.last_entry_at = timestamp
        asset.last_movement_at = timestamp
        asset.room_id = None

    elif movement_type == MovementType.loan:
        asset.location = AssetLocation.outside.value
        asset.situation = AssetSituation.onLoan.value
        asset.last_exit_at = timestamp
        asset.last_movement_at = timestamp
        asset.responsible = responsible
        asset.expected_return_at = expected_return_at
        asset.supplier_id = None
        asset.room_id = None

    elif movement_type == MovementType.loanReturn:
        asset.location = AssetLocation.inside.value
        asset.situation = AssetSituation.available.value
        asset.last_entry_at = timestamp
        asset.last_movement_at = timestamp
        asset.responsible = None
        asset.expected_return_at = None
        asset.room_id = None

    elif movement_type in (
        MovementType.supplierDelivery,
        MovementType.sendForRefill,
    ):
        asset.location = AssetLocation.outside.value
        asset.situation = AssetSituation.atSupplier.value
        asset.last_exit_at = timestamp
        asset.last_movement_at = timestamp
        asset.supplier_id = supplier_id
        asset.expected_return_at = expected_return_at
        asset.responsible = None
        asset.room_id = None

    elif movement_type in (
        MovementType.supplierReceipt,
        MovementType.receiveAfterRefill,
        MovementType.unitExchange,
    ):
        asset.location = AssetLocation.inside.value
        asset.situation = AssetSituation.available.value
        asset.last_entry_at = timestamp
        asset.last_movement_at = timestamp
        asset.supplier_id = None
        asset.expected_return_at = None
        asset.room_id = None

    elif movement_type == MovementType.exit:
        asset.location = AssetLocation.outside.value
        if asset.situation == AssetSituation.available.value:
            asset.situation = AssetSituation.inUse.value
        asset.last_exit_at = timestamp
        asset.last_movement_at = timestamp
        asset.room_id = None

    elif movement_type == MovementType.roomEntry:
        asset.location = AssetLocation.inside.value
        asset.room_id = room_id
        asset.last_room_entry_at = timestamp
        asset.last_room_detection_at = timestamp
        asset.last_movement_at = timestamp

    elif movement_type == MovementType.roomExit:
        asset.room_id = None
        asset.last_room_exit_at = timestamp
        asset.last_room_detection_at = timestamp
        asset.last_movement_at = timestamp

    elif movement_type == MovementType.roomTransfer:
        asset.location = AssetLocation.inside.value
        asset.room_id = room_id
        asset.last_room_entry_at = timestamp
        asset.last_room_exit_at = timestamp
        asset.last_room_detection_at = timestamp
        asset.last_movement_at = timestamp

    elif movement_type in (
        MovementType.adminAdjustment,
        MovementType.inventoryCorrection,
    ):
        asset.last_movement_at = timestamp
        if room_id is not None:
            asset.room_id = room_id

    # ambiguousRead no modifica la ubicación.


async def record(
    session: AsyncSession,
    organization_id: str,
    *,
    asset_id: str,
    movement_type: MovementType,
    timestamp: datetime,
    origin: EventOrigin,
    status: MovementStatus = MovementStatus.confirmed,
    access_id: str | None = None,
    reader_id: str | None = None,
    room_id: str | None = None,
    responsible: str | None = None,
    supplier_id: str | None = None,
    expected_return_at: datetime | None = None,
    reason: str = "",
    notes: str = "",
    related_operation_id: str | None = None,
    alert_message: str | None = None,
    bypass_validation: bool = False,
    check_duplicate: bool = True,
    dedupe_window_seconds: int = 30,
) -> MovementResult:
    """Registra un movimiento y actualiza el activo cuando corresponde."""
    asset = await session.get(Asset, asset_id)
    if asset is None or asset.organization_id != organization_id:
        return MovementResult.failure("No se encontró el activo indicado.")

    duplicate_types = {
        MovementType.entry,
        MovementType.exit,
        MovementType.roomEntry,
        MovementType.roomExit,
        MovementType.roomTransfer,
    }

    if (
        check_duplicate
        and status == MovementStatus.confirmed
        and movement_type in duplicate_types
        and await _is_duplicate(
            session,
            organization_id,
            asset_id,
            movement_type,
            timestamp,
            access_id,
            room_id,
            dedupe_window_seconds,
        )
    ):
        asset.last_detection_at = timestamp
        if access_id is not None:
            asset.last_access_id = access_id
        if reader_id is not None:
            asset.last_reader_id = reader_id
        if room_id is not None:
            asset.last_room_detection_at = timestamp
        await session.flush()
        return MovementResult(
            success=False,
            duplicate=True,
            message=(
                "Lectura repetida dentro de la ventana de agrupación. No se "
                "generó un movimiento nuevo."
            ),
            asset=asset,
        )

    if status == MovementStatus.confirmed and not bypass_validation:
        error = validate_transition(asset, movement_type, room_id=room_id)
        if error is not None:
            event = MovementEvent(
                id=new_id("MOV"),
                organization_id=organization_id,
                asset_id=asset_id,
                type=movement_type.value,
                timestamp=timestamp,
                origin=origin.value,
                status=MovementStatus.pendingReview.value,
                access_id=access_id,
                reader_id=reader_id,
                room_id=room_id,
                responsible=responsible,
                supplier_id=supplier_id,
                reason=reason,
                notes=notes,
                related_operation_id=related_operation_id,
                alert_message=error,
            )
            session.add(event)
            await session.flush()
            return MovementResult(success=False, message=error, event=event, asset=asset)

    if status == MovementStatus.pendingReview:
        event = MovementEvent(
            id=new_id("MOV"),
            organization_id=organization_id,
            asset_id=asset_id,
            type=movement_type.value,
            timestamp=timestamp,
            origin=origin.value,
            status=MovementStatus.pendingReview.value,
            access_id=access_id,
            reader_id=reader_id,
            room_id=room_id,
            responsible=responsible,
            supplier_id=supplier_id,
            reason=reason,
            notes=notes,
            related_operation_id=related_operation_id,
            alert_message=alert_message or "Evento pendiente de verificación manual.",
        )
        session.add(event)
        if movement_type != MovementType.ambiguousRead:
            asset.last_detection_at = timestamp
            if access_id is not None:
                asset.last_access_id = access_id
            if reader_id is not None:
                asset.last_reader_id = reader_id
            if room_id is not None:
                asset.last_room_detection_at = timestamp
        await session.flush()
        return MovementResult(
            success=False,
            message="Evento registrado como pendiente de revisión.",
            event=event,
            asset=asset,
        )

    apply_movement_to_asset(
        asset,
        movement_type,
        timestamp,
        room_id=room_id,
        responsible=responsible,
        supplier_id=supplier_id,
        expected_return_at=expected_return_at,
    )
    if access_id is not None:
        asset.last_access_id = access_id
    if reader_id is not None:
        asset.last_reader_id = reader_id

    event = MovementEvent(
        id=new_id("MOV"),
        organization_id=organization_id,
        asset_id=asset_id,
        type=movement_type.value,
        timestamp=timestamp,
        origin=origin.value,
        status=MovementStatus.confirmed.value,
        access_id=access_id,
        reader_id=reader_id,
        room_id=room_id,
        responsible=responsible,
        supplier_id=supplier_id,
        reason=reason,
        notes=notes,
        related_operation_id=related_operation_id,
        alert_message=alert_message,
    )
    session.add(event)
    await session.flush()
    return MovementResult(
        success=True,
        message="Movimiento registrado correctamente.",
        event=event,
        asset=asset,
    )


async def register_detection(
    session: AsyncSession,
    organization_id: str,
    *,
    asset_id: str,
    timestamp: datetime,
    access_id: str | None = None,
    reader_id: str | None = None,
    room_id: str | None = None,
    dedupe_window_seconds: int = 30,
) -> MovementResult:
    """Actualiza la última detección sin crear un movimiento confirmado."""
    asset = await session.get(Asset, asset_id)
    if asset is None or asset.organization_id != organization_id:
        return MovementResult.failure("No se encontró el activo indicado.")

    last_detection = asset.last_detection_at
    is_repeated = (
        last_detection is not None
        and abs((timestamp - last_detection).total_seconds()) <= dedupe_window_seconds
    )
    asset.last_detection_at = timestamp
    if access_id is not None:
        asset.last_access_id = access_id
    if reader_id is not None:
        asset.last_reader_id = reader_id
    if room_id is not None:
        asset.last_room_detection_at = timestamp
    await session.flush()

    if is_repeated:
        return MovementResult(
            success=False,
            duplicate=True,
            message=("Lectura repetida. Se actualizó la última detección sin crear un movimiento."),
            asset=asset,
        )
    return MovementResult(
        success=True,
        message="Detección registrada sin movimiento confirmado.",
        asset=asset,
    )


async def resolve_pending_event(
    session: AsyncSession,
    organization_id: str,
    event_id: str,
    *,
    approve: bool,
    notes: str = "",
    timestamp: datetime | None = None,
) -> MovementResult:
    """Aprueba o rechaza un evento pendiente de revisión."""
    event = await session.get(MovementEvent, event_id)
    if event is None or event.organization_id != organization_id:
        return MovementResult.failure("No se encontró el evento.")
    if event.status != MovementStatus.pendingReview.value:
        return MovementResult.failure("El evento ya fue procesado.")

    if not approve:
        event.status = MovementStatus.rejected.value
        event.notes = notes or "Evento rechazado durante la revisión."
        await session.flush()
        return MovementResult(
            success=True,
            message="Evento rechazado. El inventario no se modificó.",
            event=event,
        )

    moment = timestamp or datetime.now(timezone.utc)
    new_type = (
        MovementType.adminAdjustment
        if event.type == MovementType.ambiguousRead.value
        else MovementType(event.type)
    )
    result = await record(
        session,
        organization_id,
        asset_id=event.asset_id,
        movement_type=new_type,
        timestamp=moment,
        origin=EventOrigin.correction,
        access_id=event.access_id,
        reader_id=event.reader_id,
        room_id=event.room_id,
        responsible=event.responsible,
        supplier_id=event.supplier_id,
        reason=event.reason,
        notes=notes or "Evento ambiguo aprobado manualmente.",
        bypass_validation=True,
        check_duplicate=False,
    )
    if not result.success:
        return result

    await session.delete(event)
    await session.flush()
    return MovementResult(
        success=True,
        message="Evento aprobado y aplicado al inventario.",
        event=result.event,
        asset=result.asset,
    )
