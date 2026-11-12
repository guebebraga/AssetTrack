"""Idempotencia de mutaciones para reintentos desde la cola offline."""

import json

from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.db.models import IdempotencyKey
from app.db.session import AsyncSessionLocal

MUTATING_METHODS = {"POST", "PUT", "PATCH", "DELETE"}


class IdempotencyMiddleware(BaseHTTPMiddleware):
    """Evita aplicar dos veces la misma mutación si el cliente reintenta.

    El cliente envía un encabezado ``Idempotency-Key`` único por operación.
    La primera solicitud reserva la clave, y cuando termina guarda el cuerpo y
    el código de respuesta. Los reintentos reciben exactamente esa respuesta.
    """

    async def dispatch(self, request: Request, call_next):
        key = request.headers.get("Idempotency-Key")
        if not key or request.method not in MUTATING_METHODS:
            return await call_next(request)

        endpoint = f"{request.method} {request.url.path}"
        try:
            cached = await _claim_key(key, endpoint)
        except SQLAlchemyError:
            return await call_next(request)

        if cached is not None:
            return cached

        try:
            response = await call_next(request)
        except Exception:
            await _release_key(key)
            raise

        if response.status_code >= 400:
            await _release_key(key)
            return response

        body = b"".join([chunk async for chunk in response.body_iterator])
        await _store_response(key, body, response.status_code)
        headers = {
            name: value
            for name, value in response.headers.items()
            if name.lower() != "content-length"
        }
        return Response(
            content=body,
            status_code=response.status_code,
            headers=headers,
            media_type=response.media_type,
            background=response.background,
        )


async def _claim_key(key: str, endpoint: str) -> Response | None:
    """Reserva la clave o devuelve la respuesta previamente almacenada."""
    async with AsyncSessionLocal() as session:
        existing = await session.get(IdempotencyKey, key)
        if existing is not None:
            return _cached_response(existing)

        session.add(
            IdempotencyKey(
                key=key,
                endpoint=endpoint,
                response_json={},
                status_code=0,
            )
        )
        try:
            await session.commit()
        except IntegrityError:
            await session.rollback()
            existing = await session.get(IdempotencyKey, key)
            if existing is not None:
                return _cached_response(existing)
            raise
    return None


def _cached_response(record: IdempotencyKey) -> Response:
    if record.status_code == 0:
        return JSONResponse(
            {"detail": "La operación con esta clave todavía está en proceso."},
            status_code=409,
        )
    return JSONResponse(content=record.response_json, status_code=record.status_code)


async def _store_response(key: str, body: bytes, status_code: int) -> None:
    """Guarda el cuerpo JSON de una respuesta exitosa."""
    payload: dict = {}
    if body:
        try:
            decoded = json.loads(body)
        except (ValueError, UnicodeDecodeError):
            decoded = {}
        if isinstance(decoded, dict):
            payload = decoded

    try:
        async with AsyncSessionLocal() as session:
            record = await session.get(IdempotencyKey, key)
            if record is None:
                return
            record.response_json = payload
            record.status_code = status_code
            await session.commit()
    except SQLAlchemyError:
        return


async def _release_key(key: str) -> None:
    """Libera una clave reservada cuando la operación falló."""
    try:
        async with AsyncSessionLocal() as session:
            record = await session.get(IdempotencyKey, key)
            if record is not None and record.status_code == 0:
                await session.delete(record)
                await session.commit()
    except SQLAlchemyError:
        return
