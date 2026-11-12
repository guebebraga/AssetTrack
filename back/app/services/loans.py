"""Lógica de préstamos de activos."""

from dataclasses import dataclass
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Asset, Loan
from app.schemas.enums import EventOrigin, LoanStatus, MovementType
from app.services.ids import new_id
from app.services.movements import record


@dataclass
class LoanResult:
    success: bool
    message: str
    loan: Loan | None = None


async def _open_loan_for_asset(
    session: AsyncSession, organization_id: str, asset_id: str
) -> Loan | None:
    result = await session.execute(
        select(Loan).where(
            Loan.organization_id == organization_id,
            Loan.asset_id == asset_id,
            Loan.status != LoanStatus.returned.value,
        )
    )
    return result.scalars().first()


async def create_loan(
    session: AsyncSession,
    organization_id: str,
    *,
    asset_id: str,
    borrower: str,
    delivered_at: datetime,
    due_at: datetime | None = None,
    reason: str = "",
    notes: str = "",
    access_id: str | None = None,
    reader_id: str | None = None,
    dedupe_window_seconds: int = 30,
) -> LoanResult:
    asset = await session.get(Asset, asset_id)
    if asset is None or asset.organization_id != organization_id:
        return LoanResult(False, "No se encontró el activo indicado.")
    if not borrower.strip():
        return LoanResult(False, "Indicá la persona o entidad que recibe el activo.")
    if await _open_loan_for_asset(session, organization_id, asset_id) is not None:
        return LoanResult(False, "El activo ya tiene un préstamo activo.")

    movement = await record(
        session,
        organization_id,
        asset_id=asset_id,
        movement_type=MovementType.loan,
        timestamp=delivered_at,
        origin=EventOrigin.manual,
        access_id=access_id,
        reader_id=reader_id,
        responsible=borrower.strip(),
        expected_return_at=due_at,
        reason=reason,
        notes=notes,
        dedupe_window_seconds=dedupe_window_seconds,
    )
    if not movement.success:
        return LoanResult(False, movement.message)

    loan = Loan(
        id=new_id("PRE"),
        organization_id=organization_id,
        asset_id=asset_id,
        borrower=borrower.strip(),
        delivered_at=delivered_at,
        due_at=due_at,
        reason=reason,
        notes=notes,
        status=LoanStatus.active.value,
    )
    session.add(loan)
    await session.flush()
    return LoanResult(True, "Préstamo registrado correctamente.", loan)


async def return_loan(
    session: AsyncSession,
    organization_id: str,
    *,
    loan_id: str,
    returned_at: datetime,
    confirmed_inside: bool = False,
    administrative_correction: bool = False,
    notes: str = "",
    dedupe_window_seconds: int = 30,
) -> LoanResult:
    loan = await session.get(Loan, loan_id)
    if loan is None or loan.organization_id != organization_id:
        return LoanResult(False, "No se encontró el préstamo.")
    if loan.status == LoanStatus.returned.value:
        return LoanResult(False, "El préstamo ya fue devuelto.")
    if not confirmed_inside and not administrative_correction:
        return LoanResult(
            False,
            "El activo todavía no está físicamente dentro. Confirmá el ingreso "
            "o registrá una corrección administrativa explícita.",
        )

    asset = await session.get(Asset, loan.asset_id)
    if asset is None or asset.organization_id != organization_id:
        return LoanResult(False, "El activo asociado al préstamo no existe.")

    is_correction = administrative_correction and not confirmed_inside
    movement = await record(
        session,
        organization_id,
        asset_id=loan.asset_id,
        movement_type=MovementType.loanReturn,
        timestamp=returned_at,
        origin=EventOrigin.correction if is_correction else EventOrigin.manual,
        responsible=loan.borrower,
        reason=loan.reason,
        notes=(
            "Corrección administrativa: devolución registrada sin confirmación "
            f"física de ingreso. {notes}"
            if is_correction
            else notes
        ),
        bypass_validation=is_correction,
        check_duplicate=False,
        dedupe_window_seconds=dedupe_window_seconds,
    )
    if not movement.success:
        return LoanResult(False, movement.message)

    loan.status = LoanStatus.returned.value
    loan.returned_at = returned_at
    loan.return_confirmed_inside = confirmed_inside
    if notes:
        loan.notes = notes
    await session.flush()
    return LoanResult(
        True,
        (
            "Devolución registrada por corrección administrativa."
            if is_correction
            else "Devolución registrada correctamente."
        ),
        loan,
    )


async def mark_pending_verification(
    session: AsyncSession,
    organization_id: str,
    *,
    loan_id: str,
    notes: str = "",
) -> LoanResult:
    loan = await session.get(Loan, loan_id)
    if (
        loan is None
        or loan.organization_id != organization_id
        or loan.status == LoanStatus.returned.value
    ):
        return LoanResult(False, "El préstamo no está activo.")
    loan.status = LoanStatus.pendingVerification.value
    loan.notes = notes
    await session.flush()
    return LoanResult(
        True,
        "Préstamo marcado como pendiente de verificación.",
        loan,
    )
