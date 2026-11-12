"""Punto de entrada de la API de AssetTrack."""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1 import assets, catalogs, operations, rfid, state
from app.core.config import get_settings
from app.core.idempotency import IdempotencyMiddleware
from app.db.models import Base
from app.db.session import AsyncSessionLocal, engine
from app.services.state import ensure_bootstrap

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Prepara tablas y catálogos mínimos al iniciar el servicio."""
    if settings.auto_create_tables:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)

    if settings.auto_bootstrap:
        async with AsyncSessionLocal() as session:
            await ensure_bootstrap(session)
            await session.commit()

    yield

    await engine.dispose()


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(IdempotencyMiddleware)


@app.get("/health", tags=["salud"])
async def health() -> dict[str, str]:
    """Chequeo simple para monitoreo y despliegue."""
    return {"status": "ok", "service": settings.app_name}


app.include_router(state.router, prefix=settings.api_prefix)
app.include_router(assets.router, prefix=settings.api_prefix)
app.include_router(catalogs.router, prefix=settings.api_prefix)
app.include_router(operations.router, prefix=settings.api_prefix)
app.include_router(rfid.router, prefix=settings.api_prefix)
