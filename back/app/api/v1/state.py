"""Endpoints de estado general y perfil del usuario."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser, get_current_user
from app.db.session import get_session
from app.schemas.models import AppSnapshot, MeResponse
from app.services.state import load_snapshot

router = APIRouter(tags=["estado"])


@router.get("/state", response_model=AppSnapshot)
async def get_state(
    user: CurrentUser = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> AppSnapshot:
    """Devuelve el snapshot completo que consume el frontend."""
    return await load_snapshot(session, user.organization_id)


@router.get("/me", response_model=MeResponse)
async def get_me(user: CurrentUser = Depends(get_current_user)) -> MeResponse:
    """Devuelve el usuario, su rol y su organización."""
    return MeResponse(
        user_id=user.user_id,
        role=user.role,
        organization_id=user.organization_id,
        full_name=user.full_name,
    )
