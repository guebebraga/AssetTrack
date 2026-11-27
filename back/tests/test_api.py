"""Tests de integración de la API de AssetTrack."""

from fastapi.testclient import TestClient

from app.api.deps import CurrentUser, get_current_user
from app.main import app
from app.schemas.enums import UserRole

client = TestClient(app)


def test_health() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "AssetTrack API"}


def test_me_sin_token_devuelve_unauthorized() -> None:
    response = client.get("/api/v1/me")
    assert response.status_code == 401
    assert "detail" in response.json()


def test_me_con_usuario_sintetico_devuelve_perfil() -> None:
    app.dependency_overrides[get_current_user] = lambda: CurrentUser(
        user_id="00000000-0000-0000-0000-000000000000",
        role=UserRole.admin,
        organization_id="org-default",
        full_name="Usuario de prueba",
    )
    try:
        response = client.get("/api/v1/me")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 200
    body = response.json()
    assert body["userId"] == "00000000-0000-0000-0000-000000000000"
    assert body["role"] == "admin"
    assert body["organizationId"] == "org-default"
    assert body["fullName"] == "Usuario de prueba"


def test_cors_permite_el_origen_del_frontend() -> None:
    response = client.options(
        "/api/v1/me",
        headers={
            "Origin": "https://assettrack-w24f.onrender.com",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert response.status_code == 200
    assert "access-control-allow-origin" in response.headers
