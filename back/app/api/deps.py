"""Dependencias de autenticación y autorización."""

from dataclasses import dataclass

import jwt
from fastapi import Depends, Header, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.db.models import Profile
from app.db.session import get_session
from app.schemas.enums import UserRole

security = HTTPBearer(auto_error=False)
settings = get_settings()


@dataclass
class CurrentUser:
    user_id: str
    role: UserRole
    organization_id: str
    full_name: str | None = None


def _decode_token(token: str) -> dict:
    """Valida el JWT de Supabase usando JWKS o el secreto compartido."""
    try:
        if settings.supabase_jwks_url:
            jwk_client = jwt.PyJWKClient(settings.supabase_jwks_url)
            signing_key = jwk_client.get_signing_key_from_jwt(token)
            return jwt.decode(
                token,
                signing_key.key,
                algorithms=["RS256", "ES256", "ES384"],
                audience=settings.supabase_jwt_audience,
            )
        if settings.supabase_jwt_secret:
            return jwt.decode(
                token,
                settings.supabase_jwt_secret,
                algorithms=["HS256"],
                audience=settings.supabase_jwt_audience,
            )
    except jwt.PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token de Supabase inválido o vencido.",
        ) from exc
    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="El backend no tiene configurada la validación de Supabase Auth.",
    )


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    session: AsyncSession = Depends(get_session),
) -> CurrentUser:
    """Obtiene el usuario autenticado y su perfil de aplicación."""
    if settings.auth_disabled:
        return CurrentUser(
            user_id=settings.dev_user_id,
            role=UserRole(settings.dev_user_role),
            organization_id=settings.default_organization_id,
            full_name="Usuario de desarrollo",
        )

    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Falta el token de autenticación.",
        )

    payload = _decode_token(credentials.credentials)
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="El token no contiene un usuario válido.",
        )

    profile = await session.get(Profile, user_id)
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="El usuario no tiene un perfil configurado en AssetTrack.",
        )

    return CurrentUser(
        user_id=user_id,
        role=UserRole(profile.role),
        organization_id=profile.organization_id,
        full_name=profile.full_name,
    )


def require_role(*roles: UserRole):
    """Genera una dependencia que exige uno de los roles indicados."""

    async def checker(
        user: CurrentUser = Depends(get_current_user),
    ) -> CurrentUser:
        if user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tenés permisos para realizar esta acción.",
            )
        return user

    return checker


async def get_rfid_actor(
    request: Request,
    x_device_key: str | None = Header(default=None),
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    session: AsyncSession = Depends(get_session),
) -> CurrentUser:
    """Permite autenticar lectores con X-Device-Key o usuarios con JWT."""
    if settings.device_api_key and x_device_key == settings.device_api_key:
        return CurrentUser(
            user_id="device",
            role=UserRole.operator,
            organization_id=settings.default_organization_id,
            full_name="Dispositivo RFID",
        )
    # Reutiliza la autenticación normal cuando no hay clave de dispositivo.
    return await get_current_user(credentials=credentials, session=session)


async def get_admin(
    user: CurrentUser = Depends(require_role(UserRole.admin)),
) -> CurrentUser:
    return user


async def get_operator(
    user: CurrentUser = Depends(require_role(UserRole.admin, UserRole.operator)),
) -> CurrentUser:
    return user
