"""Motor y sesiones asíncronas de SQLAlchemy."""

from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import get_settings

settings = get_settings()

# statement_cache_size=0 evita problemas con el pooler de Supabase/PgBouncer.
engine = create_async_engine(
    settings.database_url,
    pool_pre_ping=True,
    connect_args={
        "statement_cache_size": 0,
        "prepared_statement_cache_size": 0,
    },
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_session() -> AsyncIterator[AsyncSession]:
    """Dependencia de FastAPI que entrega una sesión y la cierra al final."""
    async with AsyncSessionLocal() as session:
        yield session
