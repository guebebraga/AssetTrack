"""Reglas de inventario y validación de transiciones.

Es un port directo de lib/services/inventory_service.dart para mantener el
mismo comportamiento entre el frontend anterior y el backend.
"""

from app.db.models import Asset
from app.schemas.enums import AssetLocation, AssetSituation, MovementType


def contradiction_for(asset: Asset) -> str | None:
    """Devuelve un mensaje si la combinación ubicación/situación es inválida."""
    if asset.location == AssetLocation.inside.value and asset.situation in (
        AssetSituation.onLoan.value,
        AssetSituation.atSupplier.value,
    ):
        return (
            "Un activo prestado o en poder de un proveedor no puede figurar "
            "dentro de las instalaciones sin una corrección explícita."
        )
    if (
        asset.location == AssetLocation.inside.value
        and asset.situation == AssetSituation.pendingReturn.value
    ):
        return (
            "Un activo pendiente de devolución normalmente se encuentra fuera de las instalaciones."
        )
    if asset.location != AssetLocation.inside.value and asset.room_id is not None:
        return "Un activo fuera de las instalaciones no puede tener una habitación asignada."
    return None


def validate_transition(
    asset: Asset,
    movement_type: MovementType,
    *,
    room_id: str | None = None,
) -> str | None:
    """Valida si el activo puede pasar por el movimiento indicado."""
    inside = asset.location == AssetLocation.inside.value

    if movement_type == MovementType.entry:
        if inside:
            return "El activo ya figura dentro de las instalaciones."
        if asset.situation == AssetSituation.onLoan.value:
            return (
                "El activo tiene un préstamo abierto. Registrá la devolución "
                "del préstamo en lugar de una entrada genérica."
            )
        if asset.situation == AssetSituation.atSupplier.value:
            return (
                "El activo está en poder de un proveedor. Registrá la recepción "
                "de proveedor correspondiente."
            )

    elif movement_type == MovementType.exit:
        if not inside:
            return "El activo no figura dentro de las instalaciones."

    elif movement_type == MovementType.loan:
        if not inside:
            return "Solo se pueden prestar activos que están dentro."
        if asset.situation == AssetSituation.onLoan.value:
            return "El activo ya tiene un préstamo activo."
        if asset.situation == AssetSituation.atSupplier.value:
            return "El activo está en poder de un proveedor."

    elif movement_type == MovementType.loanReturn:
        if inside:
            return "El activo ya figura dentro de las instalaciones."

    elif movement_type in (
        MovementType.supplierDelivery,
        MovementType.sendForRefill,
    ):
        if not inside:
            return "La entrega requiere que el activo esté dentro."
        if asset.situation == AssetSituation.atSupplier.value:
            return "El activo ya figura en poder de un proveedor."

    elif movement_type in (
        MovementType.supplierReceipt,
        MovementType.receiveAfterRefill,
        MovementType.unitExchange,
    ):
        if inside:
            return "El activo ya figura dentro de las instalaciones."

    elif movement_type == MovementType.roomEntry:
        if not inside:
            return (
                "El activo debe estar dentro de las instalaciones para ingresar a una habitación."
            )
        if room_id is None:
            return "Seleccioná una habitación válida."
        if asset.room_id == room_id:
            return "El activo ya figura en esa habitación."

    elif movement_type == MovementType.roomExit:
        if not inside:
            return "El activo debe estar dentro de las instalaciones para salir de una habitación."
        if asset.room_id is None:
            return "El activo no figura en ninguna habitación registrada."
        if room_id is not None and asset.room_id != room_id:
            return "El activo no se encuentra en la habitación indicada."

    elif movement_type == MovementType.roomTransfer:
        if not inside:
            return (
                "El activo debe estar dentro de las instalaciones para "
                "trasladarse entre habitaciones."
            )
        if room_id is None:
            return "Seleccioná la habitación de destino."
        if asset.room_id == room_id:
            return "El activo ya figura en la habitación de destino."

    return None
