"""Lógica de entregas, recepciones e intercambios con proveedores."""

from dataclasses import dataclass
from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Asset, Supplier, SupplierOperation
from app.schemas.enums import (
    AssetLocation,
    EventOrigin,
    MovementType,
    SupplierOperationStatus,
)
from app.services.ids import new_id
from app.services.inventory import validate_transition
from app.services.movements import record


@dataclass
class SupplierOperationResult:
    success: bool
    message: str
    operation: SupplierOperation | None = None


async def create_delivery(
    session: AsyncSession,
    organization_id: str,
    *,
    supplier_id: str,
    asset_ids: list[str],
    delivered_at: datetime,
    due_at: datetime | None = None,
    reason: str = "",
    notes: str = "",
    access_id: str | None = None,
    reader_id: str | None = None,
    deliver_now: bool = True,
    origin: EventOrigin = EventOrigin.manual,
    dedupe_window_seconds: int = 30,
) -> SupplierOperationResult:
    supplier = await session.get(Supplier, supplier_id)
    if supplier is None or supplier.organization_id != organization_id:
        return SupplierOperationResult(False, "No se encontró el proveedor.")
    if not supplier.active:
        return SupplierOperationResult(False, "El proveedor está inactivo.")

    unique_ids = list(dict.fromkeys(asset_ids))
    if not unique_ids:
        return SupplierOperationResult(False, "Seleccioná al menos un activo.")

    assets: list[Asset] = []
    for asset_id in unique_ids:
        asset = await session.get(Asset, asset_id)
        if asset is None or asset.organization_id != organization_id:
            return SupplierOperationResult(False, "Uno de los activos seleccionados no existe.")
        if deliver_now:
            error = validate_transition(asset, MovementType.supplierDelivery)
            if error is not None:
                return SupplierOperationResult(False, f"{asset.code}: {error}")
        assets.append(asset)

    operation_id = new_id("OPR")
    if deliver_now:
        for asset in assets:
            result = await record(
                session,
                organization_id,
                asset_id=asset.id,
                movement_type=MovementType.supplierDelivery,
                timestamp=delivered_at,
                origin=origin,
                access_id=access_id,
                reader_id=reader_id,
                supplier_id=supplier_id,
                expected_return_at=due_at,
                reason=reason,
                notes=notes,
                related_operation_id=operation_id,
                check_duplicate=False,
                dedupe_window_seconds=dedupe_window_seconds,
            )
            if not result.success:
                return SupplierOperationResult(False, result.message)

    operation = SupplierOperation(
        id=operation_id,
        organization_id=organization_id,
        supplier_id=supplier_id,
        delivered_asset_ids=unique_ids,
        received_asset_ids=[],
        created_at=delivered_at,
        delivered_at=delivered_at if deliver_now else None,
        due_at=due_at,
        reason=reason,
        notes=notes,
        status=(
            SupplierOperationStatus.delivered.value
            if deliver_now
            else SupplierOperationStatus.prepared.value
        ),
    )
    session.add(operation)
    await session.flush()
    return SupplierOperationResult(
        True,
        (
            f"Entrega al proveedor registrada con {len(unique_ids)} activo(s)."
            if deliver_now
            else "Operación preparada. Los activos todavía no salieron."
        ),
        operation,
    )


async def deliver_operation(
    session: AsyncSession,
    organization_id: str,
    *,
    operation_id: str,
    delivered_at: datetime,
    access_id: str | None = None,
    reader_id: str | None = None,
    notes: str = "",
    dedupe_window_seconds: int = 30,
) -> SupplierOperationResult:
    operation = await session.get(SupplierOperation, operation_id)
    if operation is None or operation.organization_id != organization_id:
        return SupplierOperationResult(False, "No se encontró la operación.")
    if operation.delivered_at is not None:
        return SupplierOperationResult(False, "La operación ya fue entregada.")

    assets: list[Asset] = []
    for asset_id in operation.delivered_asset_ids:
        asset = await session.get(Asset, asset_id)
        if asset is None or asset.organization_id != organization_id:
            return SupplierOperationResult(False, "Uno de los activos de la operación no existe.")
        error = validate_transition(asset, MovementType.supplierDelivery)
        if error is not None:
            return SupplierOperationResult(False, f"{asset.code}: {error}")
        assets.append(asset)

    for asset in assets:
        result = await record(
            session,
            organization_id,
            asset_id=asset.id,
            movement_type=MovementType.supplierDelivery,
            timestamp=delivered_at,
            origin=EventOrigin.manual,
            access_id=access_id,
            reader_id=reader_id,
            supplier_id=operation.supplier_id,
            expected_return_at=operation.due_at,
            reason=operation.reason,
            notes=notes,
            related_operation_id=operation.id,
            check_duplicate=False,
            dedupe_window_seconds=dedupe_window_seconds,
        )
        if not result.success:
            return SupplierOperationResult(False, result.message, operation)

    operation.delivered_at = delivered_at
    operation.status = SupplierOperationStatus.delivered.value
    if notes:
        operation.notes = notes
    await session.flush()
    return SupplierOperationResult(True, "Salida de la operación registrada.", operation)


async def receive_assets(
    session: AsyncSession,
    organization_id: str,
    *,
    operation_id: str,
    received_asset_ids: list[str],
    received_at: datetime,
    notes: str = "",
    access_id: str | None = None,
    reader_id: str | None = None,
    origin: EventOrigin = EventOrigin.manual,
    dedupe_window_seconds: int = 30,
) -> SupplierOperationResult:
    operation = await session.get(SupplierOperation, operation_id)
    if operation is None or operation.organization_id != organization_id:
        return SupplierOperationResult(False, "No se encontró la operación.")
    if operation.status == SupplierOperationStatus.completed.value:
        return SupplierOperationResult(False, "La operación ya está completada.")
    if operation.delivered_at is None:
        return SupplierOperationResult(False, "La operación todavía no fue entregada al proveedor.")

    unique = [
        asset_id
        for asset_id in dict.fromkeys(received_asset_ids)
        if asset_id not in operation.received_asset_ids
    ]
    if not unique:
        return SupplierOperationResult(False, "No se seleccionaron activos nuevos para recibir.")

    for asset_id in unique:
        asset = await session.get(Asset, asset_id)
        if asset is None or asset.organization_id != organization_id:
            return SupplierOperationResult(
                False, "Uno de los activos recibidos no existe en el inventario."
            )
        if asset.location == AssetLocation.inside.value and asset.situation != "atSupplier":
            return SupplierOperationResult(
                False,
                f"{asset.code} ya figura dentro y no puede recibirse nuevamente. "
                "Usá una corrección de inventario si corresponde.",
            )

    for asset_id in unique:
        is_exchange = asset_id not in operation.delivered_asset_ids
        movement_type = MovementType.unitExchange if is_exchange else MovementType.supplierReceipt
        result = await record(
            session,
            organization_id,
            asset_id=asset_id,
            movement_type=movement_type,
            timestamp=received_at,
            origin=origin,
            access_id=access_id,
            reader_id=reader_id,
            supplier_id=operation.supplier_id,
            reason=operation.reason,
            notes=(
                "Unidad recibida en intercambio, distinta a las entregadas."
                if is_exchange
                else notes
            ),
            related_operation_id=operation.id,
            bypass_validation=is_exchange,
            check_duplicate=False,
            dedupe_window_seconds=dedupe_window_seconds,
        )
        if not result.success:
            return SupplierOperationResult(False, result.message, operation)

    received = [*operation.received_asset_ids, *unique]
    pending = [asset_id for asset_id in operation.delivered_asset_ids if asset_id not in received]
    operation.received_asset_ids = received
    operation.status = (
        SupplierOperationStatus.completed.value
        if not pending
        else SupplierOperationStatus.partiallyReceived.value
    )
    operation.received_at = received_at
    if notes:
        operation.notes = notes
    await session.flush()
    return SupplierOperationResult(
        True,
        (
            "Operación completada. Todas las unidades entregadas fueron recibidas."
            if not pending
            else f"Recepción parcial registrada. Quedan {len(pending)} unidad(es) "
            "entregadas pendientes de retorno."
        ),
        operation,
    )


async def complete_with_pending(
    session: AsyncSession,
    organization_id: str,
    *,
    operation_id: str,
    notes: str = "",
    closed_at: datetime | None = None,
) -> SupplierOperationResult:
    operation = await session.get(SupplierOperation, operation_id)
    if operation is None or operation.organization_id != organization_id:
        return SupplierOperationResult(False, "No se encontró la operación.")
    operation.status = SupplierOperationStatus.completed.value
    operation.received_at = closed_at or datetime.now()
    operation.notes = notes or "Operación cerrada explícitamente con unidades no retornadas."
    await session.flush()
    return SupplierOperationResult(
        True,
        "Operación cerrada. Las unidades no recibidas mantienen su trazabilidad.",
        operation,
    )
