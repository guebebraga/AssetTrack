"""Ingesta de lecturas RFID para el simulador y lectores reales."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser, get_rfid_actor
from app.db.session import get_session
from app.schemas.models import RfidReadInput, RfidReadsResponse
from app.services.alerts import rebuild_alerts
from app.services.rfid import process_read
from app.services.state import get_settings_row, load_snapshot

router = APIRouter(tags=["rfid"])


@router.post("/rfid/reads", response_model=RfidReadsResponse)
async def ingest_reads(
    reads: list[RfidReadInput],
    user: CurrentUser = Depends(get_rfid_actor),
    session: AsyncSession = Depends(get_session),
) -> RfidReadsResponse:
    """Procesa un lote de lecturas y devuelve el resultado de cada una."""
    settings = await get_settings_row(session, user.organization_id)
    results = []
    for read in reads:
        result = await process_read(
            session,
            user.organization_id,
            read,
            origin=read.origin,
            dedupe_window_seconds=settings.dedupe_window_seconds,
        )
        results.append(result)

    await rebuild_alerts(session, user.organization_id)
    await session.commit()
    state = await load_snapshot(session, user.organization_id)
    return RfidReadsResponse(results=results, state=state)
