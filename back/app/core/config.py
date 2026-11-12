"""Configuración central del backend.

Todas las variables se leen desde el entorno o desde un archivo .env.
Nunca se deben exponer las claves de servicio en el frontend.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Variables de entorno del servicio."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "AssetTrack API"
    api_prefix: str = "/api/v1"

    # Conexión a Postgres de Supabase. Se recomienda el pooler en modo
    # transaccional (puerto 6543) para despliegues serverless.
    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/assettrack"

    supabase_url: str = ""
    supabase_anon_key: str = ""
    supabase_service_role_key: str = ""
    supabase_jwt_secret: str = ""
    supabase_jwt_audience: str = "authenticated"
    supabase_jwks_url: str = ""

    default_organization_id: str = "org-default"
    default_organization_name: str = "Sanatorio Modelo"

    # Clave que usan los lectores RFID para enviar lecturas sin JWT de usuario.
    device_api_key: str = ""

    # Solo para desarrollo local. En producción debe quedar en false.
    auth_disabled: bool = False
    dev_user_id: str = "00000000-0000-0000-0000-000000000000"
    dev_user_role: str = "admin"

    auto_create_tables: bool = False
    auto_bootstrap: bool = True

    cors_origins: str = "*"

    @property
    def cors_origin_list(self) -> list[str]:
        """Convierte CORS_ORIGINS separado por comas en una lista."""
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    """Devuelve una única instancia cacheada de la configuración."""
    return Settings()
