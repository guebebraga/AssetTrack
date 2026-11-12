"""Crea los catálogos mínimos y asigna el primer administrador.

Uso:
    py -3.12 scripts/bootstrap.py --admin-email admin@ejemplo.com

El usuario debe existir previamente en Supabase Auth. El script no crea
contraseñas ni usuarios; solo configura su perfil y rol.
"""

import argparse
import asyncio
import sys
from pathlib import Path

from sqlalchemy import text

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import get_settings  # noqa: E402
from app.db.models import Profile  # noqa: E402
from app.db.session import AsyncSessionLocal  # noqa: E402
from app.services.state import ensure_bootstrap  # noqa: E402


async def main() -> None:
    parser = argparse.ArgumentParser(description="Bootstrap de AssetTrack")
    parser.add_argument(
        "--admin-email",
        help="Email del usuario de Supabase Auth que será administrador.",
    )
    args = parser.parse_args()

    settings = get_settings()
    async with AsyncSessionLocal() as session:
        await ensure_bootstrap(session, settings.default_organization_id)

        if args.admin_email:
            result = await session.execute(
                text("select id from auth.users where email = :email"),
                {"email": args.admin_email},
            )
            user_id = result.scalar_one_or_none()
            if user_id is None:
                print(
                    f"No existe un usuario con email {args.admin_email} en "
                    "Supabase Auth. Creálo primero desde el panel de Supabase."
                )
            else:
                profile = await session.get(Profile, str(user_id))
                if profile is None:
                    session.add(
                        Profile(
                            user_id=str(user_id),
                            organization_id=settings.default_organization_id,
                            role="admin",
                            full_name=args.admin_email,
                        )
                    )
                else:
                    profile.role = "admin"
                    profile.organization_id = settings.default_organization_id
                print(f"Usuario {args.admin_email} configurado como admin.")
        else:
            print(
                "Catálogos creados. Para asignar un admin, volvé a ejecutar con "
                "--admin-email tu@email.com"
            )

        await session.commit()


if __name__ == "__main__":
    asyncio.run(main())
