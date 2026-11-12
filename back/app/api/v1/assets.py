"""Endpoints de activos y correcciones de inventario."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser, get_operator
from app.api.v1.common import finalize
from app.db.models import Asset, AssetCategory, Supplier, Zone
from app.db.session import get_session
from app.schemas.enums import AssetLocation, AssetSituation, EventOrigin, MovementType
from app.schemas.models import Asset as AssetSchema
from app.schemas.models import CorrectionInput, StateResponse
from app.services.ids import new_id
from app.services.inventory import contradiction_for
from app.services.movements import record

router = APIRouter(tags=["activos"])


async def _validate_asset(
    session: AsyncSession,
    organization_id: str,
    payload: AssetSchema,
    *,
    exclude_id: str | None = None,
    allow_contradiction: bool = False,
) -> str | None:
    if not payload.code.strip():
        return "El código interno es obligatorio."
    if not payload.rfid_epc.strip():
        return "El identificador RFID es obligatorio."

    category = await session.get(AssetCategory, payload.category_id)
    if category is None or category.organization_id != organization_id:
        return "Seleccioná una categoría válida."

    duplicate_code = await session.execute(
        select(Asset).where(
            Asset.organization_id == organization_id,
            Asset.code == payload.code.strip(),
            Asset.id != (exclude_id or ""),
        )
    )
    if duplicate_code.scalar_one_or_none() is not None:
        return f"El código {payload.code.strip()} ya existe."

    duplicate_epc = await session.execute(
        select(Asset).where(
            Asset.organization_id == organization_id,
            Asset.rfid_epc == payload.rfid_epc.strip().upper(),
            Asset.id != (exclude_id or ""),
        )
    )
    if duplicate_epc.scalar_one_or_none() is not None:
        return "El identificador RFID ya está asignado."

    if payload.room_id is not None:
        zone = await session.get(Zone, payload.room_id)
        if zone is None or zone.organization_id != organization_id:
            return "La habitación indicada no existe."
    if payload.supplier_id is not None:
        supplier = await session.get(Supplier, payload.supplier_id)
        if supplier is None or supplier.organization_id != organization_id:
            return "El proveedor indicado no existe."

    candidate = Asset(
        id=exclude_id or "temp",
        organization_id=organization_id,
        code=payload.code,
        name=payload.name,
        category_id=payload.category_id,
        description=payload.description,
        rfid_epc=payload.rfid_epc,
        location=payload.location.value,
        situation=payload.situation.value,
        operational_status=payload.operational_status.value,
        room_id=payload.room_id,
        created_at=payload.created_at,
    )
    contradiction = contradiction_for(candidate)
    if contradiction is not None and not allow_contradiction:
        return contradiction
    return None


@router.post("/assets", response_model=StateResponse)
async def create_asset(
    payload: AssetSchema,
    allow_contradiction: bool = Query(False, alias="allowContradiction"),
    user: CurrentUser = Depends(get_operator),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    error = await _validate_asset(
        session,
        user.organization_id,
        payload,
        allow_contradiction=allow_contradiction,
    )
    if error is not None:
        return await finalize(session, user.organization_id, success=False, message=error)

    asset = Asset(
        id=new_id("AST"),
        organization_id=user.organization_id,
        code=payload.code.strip(),
        name=payload.name.strip(),
        category_id=payload.category_id,
        description=payload.description.strip(),
        rfid_epc=payload.rfid_epc.strip().upper(),
        location=payload.location.value,
        situation=payload.situation.value,
        operational_status=payload.operational_status.value,
        last_detection_at=payload.last_detection_at,
        last_entry_at=payload.last_entry_at,
        last_exit_at=payload.last_exit_at,
        last_movement_at=payload.last_movement_at,
        responsible=payload.responsible,
        supplier_id=payload.supplier_id,
        expected_return_at=payload.expected_return_at,
        created_at=payload.created_at or datetime.now(timezone.utc),
        last_access_id=payload.last_access_id,
        last_reader_id=payload.last_reader_id,
        room_id=payload.room_id,
        last_room_entry_at=payload.last_room_entry_at,
        last_room_exit_at=payload.last_room_exit_at,
        last_room_detection_at=payload.last_room_detection_at,
        notes=payload.notes.strip(),
    )
    session.add(asset)
    await session.flush()
    return await finalize(
        session,
        user.organization_id,
        success=True,
        message=f"Activo {asset.code} creado correctamente.",
    )


@router.put("/assets/{asset_id}", response_model=StateResponse)
async def update_asset(
    asset_id: str,
    payload: AssetSchema,
    allow_contradiction: bool = Query(False, alias="allowContradiction"),
    user: CurrentUser = Depends(get_operator),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    asset = await session.get(Asset, asset_id)
    if asset is None or asset.organization_id != user.organization_id:
        return await finalize(
            session, user.organization_id, success=False, message="No se encontró el activo."
        )

    error = await _validate_asset(
        session,
        user.organization_id,
        payload,
        exclude_id=asset_id,
        allow_contradiction=allow_contradiction,
    )
    if error is not None:
        return await finalize(session, user.organization_id, success=False, message=error)

    asset.code = payload.code.strip()
    asset.name = payload.name.strip()
    asset.category_id = payload.category_id
    asset.description = payload.description.strip()
    asset.rfid_epc = payload.rfid_epc.strip().upper()
    asset.location = payload.location.value
    asset.situation = payload.situation.value
    asset.operational_status = payload.operational_status.value
    asset.last_detection_at = payload.last_detection_at
    asset.last_entry_at = payload.last_entry_at
    asset.last_exit_at = payload.last_exit_at
    asset.last_movement_at = payload.last_movement_at
    asset.responsible = payload.responsible
    asset.supplier_id = payload.supplier_id
    asset.expected_return_at = payload.expected_return_at
    asset.last_access_id = payload.last_access_id
    asset.last_reader_id = payload.last_reader_id
    asset.room_id = payload.room_id
    asset.last_room_entry_at = payload.last_room_entry_at
    asset.last_room_exit_at = payload.last_room_exit_at
    asset.last_room_detection_at = payload.last_room_detection_at
    asset.notes = payload.notes.strip()
    await session.flush()
    return await finalize(
        session,
        user.organization_id,
        success=True,
        message=f"Activo {asset.code} actualizado.",
    )


@router.post("/assets/{asset_id}/corrections", response_model=StateResponse)
async def apply_correction(
    asset_id: str,
    payload: CorrectionInput,
    user: CurrentUser = Depends(get_operator),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    asset = await session.get(Asset, asset_id)
    if asset is None or asset.organization_id != user.organization_id:
        return await finalize(
            session, user.organization_id, success=False, message="No se encontró el activo."
        )
    if not payload.notes.strip():
        return await finalize(
            session,
            user.organization_id,
            success=False,
            message="La corrección requiere una justificación.",
        )

    now = datetime.now(timezone.utc)
    if payload.location is not None:
        asset.location = payload.location.value
    if payload.situation is not None:
        asset.situation = payload.situation.value
    if payload.operational_status is not None:
        asset.operational_status = payload.operational_status.value

    keep_room = asset.location == AssetLocation.inside.value
    asset.room_id = payload.room_id if keep_room and payload.room_id is not None else None

    if asset.situation == AssetSituation.available.value:
        asset.responsible = None
        asset.supplier_id = None
        asset.expected_return_at = None
    if asset.situation == AssetSituation.maintenance.value:
        asset.expected_return_at = None
    if keep_room and asset.situation in (
        AssetSituation.available.value,
        AssetSituation.maintenance.value,
    ):
        asset.last_entry_at = now
        asset.last_detection_at = now

    asset.last_movement_at = now
    result = await record(
        session,
        user.organization_id,
        asset_id=asset_id,
        movement_type=MovementType.inventoryCorrection,
        timestamp=now,
        origin=EventOrigin.correction,
        notes=payload.notes.strip(),
        reason="Corrección administrativa explícita",
        bypass_validation=True,
        check_duplicate=False,
    )
    if not result.success:
        return await finalize(session, user.organization_id, success=False, message=result.message)
    return await finalize(
        session,
        user.organization_id,
        success=True,
        message="Corrección registrada en el historial.",
    )
