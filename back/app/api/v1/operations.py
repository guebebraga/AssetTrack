"""Endpoints de préstamos, proveedores, alertas y eventos pendientes."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser, get_operator
from app.api.v1.common import finalize
from app.db.models import Asset, AssetCategory, SupplierOperation
from app.db.session import get_session
from app.schemas.enums import (
    AssetLocation,
    AssetSituation,
    EventOrigin,
    OperationalStatus,
)
from app.schemas.models import (
    LoanCreateInput,
    LoanReturnInput,
    PendingEventResolutionInput,
    StateResponse,
    SupplierCompleteInput,
    SupplierDeliverInput,
    SupplierNewAssetInput,
    SupplierOperationCreateInput,
    SupplierReceiveInput,
)
from app.services.alerts import resolve_alert
from app.services.ids import new_id
from app.services.loans import (
    create_loan,
    mark_pending_verification,
    return_loan,
)
from app.services.movements import resolve_pending_event
from app.services.state import get_settings_row
from app.services.suppliers import (
    complete_with_pending,
    create_delivery,
    deliver_operation,
    receive_assets,
)

router = APIRouter(tags=["operaciones"])


async def _dedupe_window(session: AsyncSession, organization_id: str) -> int:
    settings = await get_settings_row(session, organization_id)
    return settings.dedupe_window_seconds


@router.post("/loans", response_model=StateResponse)
async def create_loan_endpoint(
    payload: LoanCreateInput,
    user: CurrentUser = Depends(get_operator),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    result = await create_loan(
        session,
        user.organization_id,
        asset_id=payload.asset_id,
        borrower=payload.borrower,
        delivered_at=datetime.now(timezone.utc),
        due_at=payload.due_at,
        reason=payload.reason,
        notes=payload.notes,
        access_id=payload.access_id,
        reader_id=payload.reader_id,
        dedupe_window_seconds=await _dedupe_window(session, user.organization_id),
    )
    return await finalize(
        session,
        user.organization_id,
        success=result.success,
        message=result.message,
    )


@router.post("/loans/{loan_id}/return", response_model=StateResponse)
async def return_loan_endpoint(
    loan_id: str,
    payload: LoanReturnInput,
    user: CurrentUser = Depends(get_operator),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    result = await return_loan(
        session,
        user.organization_id,
        loan_id=loan_id,
        returned_at=datetime.now(timezone.utc),
        confirmed_inside=payload.confirmed_inside,
        administrative_correction=payload.administrative_correction,
        notes=payload.notes,
        dedupe_window_seconds=await _dedupe_window(session, user.organization_id),
    )
    return await finalize(
        session,
        user.organization_id,
        success=result.success,
        message=result.message,
    )


@router.post("/loans/{loan_id}/pending-verification", response_model=StateResponse)
async def mark_loan_pending_endpoint(
    loan_id: str,
    notes: str = Query(""),
    user: CurrentUser = Depends(get_operator),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    result = await mark_pending_verification(
        session, user.organization_id, loan_id=loan_id, notes=notes
    )
    return await finalize(
        session,
        user.organization_id,
        success=result.success,
        message=result.message,
    )


@router.post("/supplier-operations", response_model=StateResponse)
async def create_supplier_operation_endpoint(
    payload: SupplierOperationCreateInput,
    user: CurrentUser = Depends(get_operator),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    result = await create_delivery(
        session,
        user.organization_id,
        supplier_id=payload.supplier_id,
        asset_ids=payload.asset_ids,
        delivered_at=datetime.now(timezone.utc),
        due_at=payload.due_at,
        reason=payload.reason,
        notes=payload.notes,
        access_id=payload.access_id,
        reader_id=payload.reader_id,
        origin=payload.origin,
        dedupe_window_seconds=await _dedupe_window(session, user.organization_id),
    )
    return await finalize(
        session,
        user.organization_id,
        success=result.success,
        message=result.message,
    )


@router.post("/supplier-operations/{operation_id}/deliver", response_model=StateResponse)
async def deliver_supplier_operation_endpoint(
    operation_id: str,
    payload: SupplierDeliverInput,
    user: CurrentUser = Depends(get_operator),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    result = await deliver_operation(
        session,
        user.organization_id,
        operation_id=operation_id,
        delivered_at=datetime.now(timezone.utc),
        access_id=payload.access_id,
        reader_id=payload.reader_id,
        notes=payload.notes,
        dedupe_window_seconds=await _dedupe_window(session, user.organization_id),
    )
    return await finalize(
        session,
        user.organization_id,
        success=result.success,
        message=result.message,
    )


@router.post("/supplier-operations/{operation_id}/receive", response_model=StateResponse)
async def receive_supplier_assets_endpoint(
    operation_id: str,
    payload: SupplierReceiveInput,
    user: CurrentUser = Depends(get_operator),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    result = await receive_assets(
        session,
        user.organization_id,
        operation_id=operation_id,
        received_asset_ids=payload.asset_ids,
        received_at=datetime.now(timezone.utc),
        notes=payload.notes,
        access_id=payload.access_id,
        reader_id=payload.reader_id,
        origin=payload.origin,
        dedupe_window_seconds=await _dedupe_window(session, user.organization_id),
    )
    return await finalize(
        session,
        user.organization_id,
        success=result.success,
        message=result.message,
    )


@router.post(
    "/supplier-operations/{operation_id}/receive-new-asset",
    response_model=StateResponse,
)
async def receive_new_supplier_asset_endpoint(
    operation_id: str,
    payload: SupplierNewAssetInput,
    user: CurrentUser = Depends(get_operator),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    operation = await session.get(SupplierOperation, operation_id)
    if operation is None or operation.organization_id != user.organization_id:
        return await finalize(
            session,
            user.organization_id,
            success=False,
            message="No se encontró la operación.",
        )
    category = await session.get(AssetCategory, payload.category_id)
    if category is None or category.organization_id != user.organization_id:
        return await finalize(
            session,
            user.organization_id,
            success=False,
            message="Seleccioná una categoría válida.",
        )

    from sqlalchemy import select

    from app.db.models import Asset as AssetModel

    duplicate_code = await session.execute(
        select(AssetModel).where(
            AssetModel.organization_id == user.organization_id,
            AssetModel.code == payload.code.strip(),
        )
    )
    if duplicate_code.scalar_one_or_none() is not None:
        return await finalize(
            session,
            user.organization_id,
            success=False,
            message=f"El código {payload.code} ya existe.",
        )
    duplicate_epc = await session.execute(
        select(AssetModel).where(
            AssetModel.organization_id == user.organization_id,
            AssetModel.rfid_epc == payload.rfid_epc.strip().upper(),
        )
    )
    if duplicate_epc.scalar_one_or_none() is not None:
        return await finalize(
            session,
            user.organization_id,
            success=False,
            message="El identificador RFID ya está asignado.",
        )

    asset = Asset(
        id=new_id("AST"),
        organization_id=user.organization_id,
        code=payload.code.strip(),
        name=payload.name.strip(),
        category_id=payload.category_id,
        description=payload.description.strip(),
        rfid_epc=payload.rfid_epc.strip().upper(),
        location=AssetLocation.outside.value,
        situation=AssetSituation.available.value,
        operational_status=OperationalStatus.operational.value,
        created_at=datetime.now(timezone.utc),
        notes="Unidad incorporada durante una recepción de proveedor.",
    )
    session.add(asset)
    await session.flush()

    result = await receive_assets(
        session,
        user.organization_id,
        operation_id=operation_id,
        received_asset_ids=[asset.id],
        received_at=datetime.now(timezone.utc),
        notes=payload.notes or "Alta controlada de unidad no registrada.",
        origin=EventOrigin.manual,
        dedupe_window_seconds=await _dedupe_window(session, user.organization_id),
    )
    if not result.success:
        await session.rollback()
        return await finalize(
            session,
            user.organization_id,
            success=False,
            message=result.message,
        )
    return await finalize(
        session,
        user.organization_id,
        success=True,
        message=result.message,
    )


@router.post("/supplier-operations/{operation_id}/complete", response_model=StateResponse)
async def complete_supplier_operation_endpoint(
    operation_id: str,
    payload: SupplierCompleteInput,
    user: CurrentUser = Depends(get_operator),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    result = await complete_with_pending(
        session,
        user.organization_id,
        operation_id=operation_id,
        notes=payload.notes,
        closed_at=datetime.now(timezone.utc),
    )
    return await finalize(
        session,
        user.organization_id,
        success=result.success,
        message=result.message,
    )


@router.post("/alerts/{alert_id}/resolve", response_model=StateResponse)
async def resolve_alert_endpoint(
    alert_id: str,
    user: CurrentUser = Depends(get_operator),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    ok = await resolve_alert(
        session,
        user.organization_id,
        alert_id=alert_id,
        resolved_at=datetime.now(timezone.utc),
    )
    return await finalize(
        session,
        user.organization_id,
        success=ok,
        message=("Alerta marcada como resuelta." if ok else "No se encontró la alerta."),
    )


@router.post("/movements/{event_id}/resolve", response_model=StateResponse)
async def resolve_movement_endpoint(
    event_id: str,
    payload: PendingEventResolutionInput,
    user: CurrentUser = Depends(get_operator),
    session: AsyncSession = Depends(get_session),
) -> StateResponse:
    result = await resolve_pending_event(
        session,
        user.organization_id,
        event_id,
        approve=payload.approve,
        notes=payload.notes,
        timestamp=datetime.now(timezone.utc),
    )
    return await finalize(
        session,
        user.organization_id,
        success=result.success,
        message=result.message,
    )
