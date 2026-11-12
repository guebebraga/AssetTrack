"""Generación y persistencia de alertas derivadas del estado del inventario."""

from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import (
    Alert,
    AppSettings,
    Asset,
    Loan,
    MovementEvent,
    SupplierOperation,
)
from app.schemas.enums import (
    AlertSeverity,
    AlertType,
    AssetLocation,
    AssetSituation,
    LoanStatus,
    MovementStatus,
    MovementType,
    SupplierOperationStatus,
)


def _date_label(value: datetime | None) -> str:
    if value is None:
        return "sin fecha"
    return value.strftime("%d/%m/%Y %H:%M")


def _effective_loan_status(loan: Loan, now: datetime) -> str:
    if loan.status == LoanStatus.returned.value:
        return LoanStatus.returned.value
    if loan.status == LoanStatus.pendingVerification.value:
        return LoanStatus.pendingVerification.value
    if loan.due_at is not None and loan.due_at < now:
        return LoanStatus.overdue.value
    return LoanStatus.active.value


async def rebuild_alerts(
    session: AsyncSession,
    organization_id: str,
    *,
    now: datetime | None = None,
) -> list[Alert]:
    """Recalcula las alertas del sistema conservando las resoluciones previas."""
    reference = now or datetime.now(timezone.utc)

    settings = await session.get(AppSettings, organization_id)
    outside_threshold = timedelta(hours=settings.outside_threshold_hours if settings else 72)
    detection_threshold = timedelta(hours=settings.alert_detection_hours if settings else 72)

    assets = (
        (await session.execute(select(Asset).where(Asset.organization_id == organization_id)))
        .scalars()
        .all()
    )
    assets_by_id = {asset.id: asset for asset in assets}
    loans = (
        (await session.execute(select(Loan).where(Loan.organization_id == organization_id)))
        .scalars()
        .all()
    )
    operations = (
        (
            await session.execute(
                select(SupplierOperation).where(
                    SupplierOperation.organization_id == organization_id
                )
            )
        )
        .scalars()
        .all()
    )
    movements = (
        (
            await session.execute(
                select(MovementEvent).where(MovementEvent.organization_id == organization_id)
            )
        )
        .scalars()
        .all()
    )
    existing = {
        alert.id: alert
        for alert in (
            await session.execute(
                select(Alert).where(
                    Alert.organization_id == organization_id,
                    Alert.source == "system",
                )
            )
        )
        .scalars()
        .all()
    }

    generated: dict[str, dict] = {}

    def add(
        *,
        alert_type: AlertType,
        severity: AlertSeverity,
        title: str,
        message: str,
        asset_id: str | None = None,
        operation_id: str | None = None,
    ) -> None:
        alert_id = f"alt-{alert_type.value}-{asset_id or operation_id or 'general'}"
        generated[alert_id] = {
            "type": alert_type.value,
            "severity": severity.value,
            "title": title,
            "message": message,
            "asset_id": asset_id,
        }

    for asset in assets:
        if asset.location != AssetLocation.outside.value:
            continue
        if asset.situation in (
            AssetSituation.onLoan.value,
            AssetSituation.atSupplier.value,
        ):
            continue
        since = asset.last_exit_at
        if since is None:
            continue
        elapsed = reference - since
        if elapsed <= outside_threshold:
            continue
        add(
            alert_type=AlertType.outsideTooLong,
            severity=(
                AlertSeverity.critical if elapsed > outside_threshold * 2 else AlertSeverity.warning
            ),
            title="Activo fuera de las instalaciones",
            message=(
                f"{asset.code} lleva {elapsed.days} día(s) fuera, superando el "
                f"umbral de {outside_threshold.total_seconds() / 3600:.0f} h."
            ),
            asset_id=asset.id,
        )

    for loan in loans:
        if _effective_loan_status(loan, reference) != LoanStatus.overdue.value:
            continue
        late_hours = 0 if loan.due_at is None else (reference - loan.due_at).total_seconds() / 3600
        asset = assets_by_id.get(loan.asset_id)
        add(
            alert_type=AlertType.loanOverdue,
            severity=(AlertSeverity.critical if late_hours > 48 else AlertSeverity.warning),
            title="Préstamo vencido",
            message=(
                f"{asset.code if asset else loan.asset_id} fue prestado a "
                f"{loan.borrower} y tenía que volver el "
                f"{_date_label(loan.due_at)}."
            ),
            asset_id=loan.asset_id,
        )

    for operation in operations:
        if operation.status == SupplierOperationStatus.completed.value:
            continue
        pending = [
            asset_id
            for asset_id in operation.delivered_asset_ids
            if asset_id not in operation.received_asset_ids
        ]
        if not pending:
            continue
        if operation.status == SupplierOperationStatus.partiallyReceived.value:
            add(
                alert_type=AlertType.incompleteReturn,
                severity=AlertSeverity.warning,
                title="Devolución incompleta",
                message=(
                    f"La operación con el proveedor tiene {len(pending)} "
                    "unidad(es) sin retorno registrado."
                ),
                operation_id=operation.id,
            )
            continue
        if operation.delivered_at is None:
            continue
        overdue = operation.due_at is not None and operation.due_at < reference
        long_pending = reference - operation.delivered_at > outside_threshold * 2
        if not overdue and not long_pending:
            continue
        add(
            alert_type=AlertType.supplierPending,
            severity=(
                AlertSeverity.critical
                if overdue
                and operation.due_at is not None
                and (operation.due_at - operation.delivered_at).days > 2
                else AlertSeverity.warning
            ),
            title="Entrega a proveedor pendiente",
            message=(
                f"{len(pending)} unidad(es) entregadas al proveedor todavía no "
                "fueron recibidas."
                + (
                    f" Retorno previsto: {_date_label(operation.due_at)}."
                    if operation.due_at
                    else ""
                )
            ),
            operation_id=operation.id,
        )

    for movement in movements:
        if movement.status != MovementStatus.pendingReview.value:
            continue
        asset = assets_by_id.get(movement.asset_id)
        if movement.type == MovementType.ambiguousRead.value:
            add(
                alert_type=AlertType.ambiguousRead,
                severity=AlertSeverity.warning,
                title="Lectura ambigua pendiente",
                message=(
                    f"{asset.code if asset else movement.asset_id}: lectura sin "
                    "sentido de movimiento confirmado. Requiere revisión manual."
                ),
                asset_id=movement.asset_id,
                operation_id=movement.id,
            )
        else:
            add(
                alert_type=AlertType.incompatibleMovement,
                severity=AlertSeverity.warning,
                title="Movimiento incompatible",
                message=(
                    f"{asset.code if asset else movement.asset_id}: "
                    f"{movement.alert_message or 'movimiento pendiente de revisión.'}"
                ),
                asset_id=movement.asset_id,
                operation_id=movement.id,
            )

    for asset in assets:
        if asset.location != AssetLocation.inside.value:
            continue
        detection = asset.last_detection_at
        if detection is None:
            continue
        elapsed = reference - detection
        if elapsed <= detection_threshold:
            continue
        add(
            alert_type=AlertType.noRecentDetection,
            severity=AlertSeverity.info,
            title="Sin detecciones recientes",
            message=(f"{asset.code} no registra lecturas desde {_date_label(detection)}."),
            asset_id=asset.id,
        )

    # Actualiza o crea las alertas generadas.
    for alert_id, data in generated.items():
        current = existing.get(alert_id)
        if current is None:
            session.add(
                Alert(
                    id=alert_id,
                    organization_id=organization_id,
                    type=data["type"],
                    severity=data["severity"],
                    title=data["title"],
                    message=data["message"],
                    created_at=reference,
                    asset_id=data["asset_id"],
                    simulated=True,
                    source="system",
                )
            )
        else:
            current.type = data["type"]
            current.severity = data["severity"]
            current.title = data["title"]
            current.message = data["message"]
            current.asset_id = data["asset_id"]

    # Elimina alertas del sistema que ya no corresponden.
    for alert_id, alert in existing.items():
        if alert_id not in generated:
            await session.delete(alert)

    await session.flush()
    result = await session.execute(
        select(Alert)
        .where(Alert.organization_id == organization_id)
        .order_by(Alert.severity.desc(), Alert.created_at.desc())
    )
    return list(result.scalars().all())


async def resolve_alert(
    session: AsyncSession,
    organization_id: str,
    *,
    alert_id: str,
    resolved_at: datetime | None = None,
) -> bool:
    alert = await session.get(Alert, alert_id)
    if alert is None or alert.organization_id != organization_id:
        return False
    alert.resolved_at = resolved_at or datetime.now(timezone.utc)
    await session.flush()
    return True


async def add_unknown_reader_alert(
    session: AsyncSession,
    organization_id: str,
    *,
    reader_id: str,
    message: str,
) -> Alert:
    """Crea una alerta persistente para un lector no registrado o inactivo."""
    alert_id = f"alt-{AlertType.unknownReader.value}-{reader_id or 'desconocido'}"
    alert = await session.get(Alert, alert_id)
    if alert is None:
        alert = Alert(
            id=alert_id,
            organization_id=organization_id,
            type=AlertType.unknownReader.value,
            severity=AlertSeverity.critical.value,
            title="Lector RFID no registrado",
            message=message,
            created_at=datetime.now(timezone.utc),
            asset_id=None,
            simulated=False,
            source="reader",
        )
        session.add(alert)
    else:
        alert.message = message
    await session.flush()
    return alert
