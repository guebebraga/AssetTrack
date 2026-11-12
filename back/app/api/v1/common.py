"""Utilidades compartidas por los routers."""

from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.models import ActionResult, StateResponse
from app.services.alerts import rebuild_alerts
from app.services.state import load_snapshot


async def finalize(
    session: AsyncSession,
    organization_id: str,
    *,
    success: bool,
    message: str,
    rebuild: bool = True,
) -> StateResponse:
    """Confirma cambios, recalcula alertas y devuelve el snapshot completo."""
    if rebuild:
        await rebuild_alerts(session, organization_id)
    await session.commit()
    state = await load_snapshot(session, organization_id)
    return StateResponse(
        result=ActionResult(success=success, message=message),
        state=state,
    )
