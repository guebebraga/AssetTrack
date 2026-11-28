"""Seed de datos de demostración para AssetTrack.

Crea el esquema (si falta), aplica el bootstrap mínimo, asigna el perfil admin
al usuario existente de Supabase Auth y siembra datos de prueba usando los
endpoints reales de la API, en proceso, con AUTH_DISABLED=true solo para este
script.

Uso (desde la carpeta back):
    .venv\\Scripts\\python.exe scripts\\seed_demo.py
"""

from __future__ import annotations

import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[1]
os.chdir(BASE_DIR)
sys.path.insert(0, str(BASE_DIR))

# Autenticación de desarrollo solo para este proceso (no afecta a Render).
os.environ["AUTH_DISABLED"] = "true"
os.environ["AUTO_CREATE_TABLES"] = "false"
os.environ["AUTO_BOOTSTRAP"] = "false"

import asyncio  # noqa: E402

import httpx  # noqa: E402
from sqlalchemy import text  # noqa: E402

from app.db.models import Base, Profile  # noqa: E402
from app.db.session import AsyncSessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.services.state import ensure_bootstrap  # noqa: E402

ORG_ID = "org-default"
NOW = datetime.now(timezone.utc)


def iso(moment: datetime) -> str:
    return moment.astimezone(timezone.utc).isoformat()


def find(items: list[dict], key: str, value: object) -> dict | None:
    for item in items:
        if item.get(key) == value:
            return item
    return None


async def ensure_schema_and_profile() -> None:
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as session:
        await ensure_bootstrap(session)
        users = (await session.execute(text("select id, email from auth.users"))).all()
        for user_id, email in users:
            profile = await session.get(Profile, str(user_id))
            if profile is None:
                session.add(
                    Profile(
                        user_id=str(user_id),
                        organization_id=ORG_ID,
                        role="admin",
                        full_name=email,
                    )
                )
            else:
                profile.organization_id = ORG_ID
                profile.role = "admin"
        await session.commit()

    print(f"[setup] esquema listo y {len(users)} perfil(es) admin configurado(s)")


async def request(client: httpx.AsyncClient, method: str, path: str, payload=None):
    response = await client.request(method, path, json=payload)
    if response.status_code >= 400:
        raise RuntimeError(f"{method} {path} -> {response.status_code}: {response.text}")
    return response.json()


async def mutate(client: httpx.AsyncClient, method: str, path: str, payload=None) -> dict:
    data = await request(client, method, path, payload)
    result = data.get("result", {})
    flag = "ok  " if result.get("success") else "warn"
    print(f"  [{flag}] {method} {path}: {result.get('message', '')}")
    return data["state"]


async def send_rfid(client: httpx.AsyncClient, reads: list[dict]) -> dict:
    data = await request(client, "POST", "/api/v1/rfid/reads", reads)
    for result in data.get("results", []):
        if result.get("success"):
            flag = "ok  "
        elif result.get("duplicate"):
            flag = "dup "
        else:
            flag = "warn"
        print(f"  [{flag}] rfid: {result.get('message', '')}")
    return data["state"]


async def seed() -> None:
    await ensure_schema_and_profile()

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://seed") as client:
        state = await request(client, "GET", "/api/v1/state")

        # Proveedores
        for name, service in (
            ("Oxígeno del Sur", "Recarga de oxígeno"),
            ("Biomedicina S.A.", "Mantenimiento de equipos"),
        ):
            if find(state["suppliers"], "name", name) is None:
                state = await mutate(
                    client,
                    "POST",
                    "/api/v1/suppliers",
                    {"name": name, "serviceType": service, "contact": "", "notes": ""},
                )
        supplier_bio = find(state["suppliers"], "name", "Biomedicina S.A.")

        # Lectores / sensores
        readers = (
            {
                "id": "LEC-UTI-01",
                "name": "Sensor UTI",
                "type": "room_sensor",
                "status": "active",
                "zoneId": "zon-uti",
                "antennaCount": 1,
                "protocol": "none",
            },
            {
                "id": "LEC-GUARDIA-01",
                "name": "Sensor Guardia",
                "type": "room_sensor",
                "status": "active",
                "zoneId": "zon-guardia",
                "antennaCount": 1,
                "protocol": "none",
            },
            {
                "id": "LEC-PROV-01",
                "name": "Lector proveedores",
                "type": "fixed_uhf",
                "status": "active",
                "accessId": "acc-proveedores",
                "antennaCount": 2,
                "protocol": "none",
            },
        )
        for reader in readers:
            if find(state["readers"], "id", reader["id"]) is None:
                state = await mutate(client, "POST", "/api/v1/readers", reader)

        # Categoría extra
        if find(state["categories"], "name", "Insumos") is None:
            state = await mutate(
                client,
                "POST",
                "/api/v1/categories",
                {
                    "name": "Insumos",
                    "codePrefix": "INS",
                    "description": "Insumos clínicos descartables.",
                },
            )
        category_insumos = find(state["categories"], "name", "Insumos")

        # Activos
        asset_specs = (
            {
                "code": "O2-001",
                "name": "Balón de oxígeno 10L",
                "categoryId": "cat-oxigeno",
                "rfidEpc": "E200-O2-0001",
                "location": "inside",
                "situation": "available",
                "operationalStatus": "operational",
                "lastDetectionAt": iso(NOW),
            },
            {
                "code": "O2-002",
                "name": "Balón de oxígeno 5L",
                "categoryId": "cat-oxigeno",
                "rfidEpc": "E200-O2-0002",
                "location": "inside",
                "situation": "available",
                "operationalStatus": "operational",
                "lastDetectionAt": iso(NOW),
            },
            {
                "code": "O2-003",
                "name": "Balón de oxígeno 15L",
                "categoryId": "cat-oxigeno",
                "rfidEpc": "E200-O2-0003",
                "location": "outside",
                "situation": "inUse",
                "operationalStatus": "operational",
                "lastDetectionAt": iso(NOW - timedelta(days=5)),
                "lastExitAt": iso(NOW - timedelta(days=5)),
            },
            {
                "code": "EQP-001",
                "name": "Monitor multiparamétrico",
                "categoryId": "cat-equipamiento",
                "rfidEpc": "E200-EQP-0001",
                "location": "inside",
                "situation": "inUse",
                "operationalStatus": "operational",
                "roomId": "zon-uti",
                "lastDetectionAt": iso(NOW),
            },
            {
                "code": "EQP-002",
                "name": "Bomba de infusión",
                "categoryId": "cat-equipamiento",
                "rfidEpc": "E200-EQP-0002",
                "location": "inside",
                "situation": "available",
                "operationalStatus": "operational",
                "lastDetectionAt": iso(NOW),
            },
            {
                "code": "EQP-003",
                "name": "Electrocardiógrafo",
                "categoryId": "cat-equipamiento",
                "rfidEpc": "E200-EQP-0003",
                "location": "inside",
                "situation": "available",
                "operationalStatus": "operational",
                "lastDetectionAt": iso(NOW),
            },
            {
                "code": "EQP-004",
                "name": "Desfibrilador",
                "categoryId": "cat-equipamiento",
                "rfidEpc": "E200-EQP-0004",
                "location": "inside",
                "situation": "available",
                "operationalStatus": "operational",
                "lastDetectionAt": iso(NOW - timedelta(days=5)),
            },
            {
                "code": "EQP-005",
                "name": "Ventilador mecánico",
                "categoryId": "cat-equipamiento",
                "rfidEpc": "E200-EQP-0005",
                "location": "inside",
                "situation": "available",
                "operationalStatus": "operational",
                "lastDetectionAt": iso(NOW),
            },
            {
                "code": "MOB-001",
                "name": "Cama clínica",
                "categoryId": "cat-mobiliario",
                "rfidEpc": "E200-MOB-0001",
                "location": "inside",
                "situation": "available",
                "operationalStatus": "operational",
                "roomId": "zon-guardia",
                "lastDetectionAt": iso(NOW),
            },
            {
                "code": "MOB-002",
                "name": "Silla de ruedas",
                "categoryId": "cat-mobiliario",
                "rfidEpc": "E200-MOB-0002",
                "location": "inside",
                "situation": "inUse",
                "operationalStatus": "operational",
                "lastDetectionAt": iso(NOW),
            },
            {
                "code": "INS-001",
                "name": "Set de infusión",
                "categoryId": category_insumos["id"],
                "rfidEpc": "E200-INS-0001",
                "location": "inside",
                "situation": "available",
                "operationalStatus": "operational",
                "lastDetectionAt": iso(NOW),
            },
        )
        for spec in asset_specs:
            if find(state["assets"], "code", spec["code"]) is None:
                payload = {"id": f"seed-{spec['code']}", "createdAt": iso(NOW), **spec}
                state = await mutate(client, "POST", "/api/v1/assets", payload)

        asset_ids = {item["code"]: item["id"] for item in state["assets"]}

        def has_open_loan(asset_id: str) -> bool:
            return any(
                loan["assetId"] == asset_id and loan["status"] != "returned"
                for loan in state["loans"]
            )

        # Préstamos
        if not has_open_loan(asset_ids["O2-002"]):
            state = await mutate(
                client,
                "POST",
                "/api/v1/loans",
                {
                    "assetId": asset_ids["O2-002"],
                    "borrower": "Dr. Pérez",
                    "dueAt": iso(NOW + timedelta(days=2)),
                    "reason": "Uso en guardia",
                    "notes": "Préstamo de prueba",
                },
            )
        if not has_open_loan(asset_ids["MOB-002"]):
            state = await mutate(
                client,
                "POST",
                "/api/v1/loans",
                {
                    "assetId": asset_ids["MOB-002"],
                    "borrower": "Enfermería",
                    "dueAt": iso(NOW - timedelta(days=3)),
                    "reason": "Traslado de paciente",
                    "notes": "Préstamo vencido de prueba",
                },
            )

        ins_id = asset_ids["INS-001"]
        ins_returned = any(
            loan["assetId"] == ins_id and loan["status"] == "returned"
            for loan in state["loans"]
        )
        ins_open = next(
            (
                loan
                for loan in state["loans"]
                if loan["assetId"] == ins_id and loan["status"] != "returned"
            ),
            None,
        )
        if ins_open is None and not ins_returned:
            state = await mutate(
                client,
                "POST",
                "/api/v1/loans",
                {
                    "assetId": ins_id,
                    "borrower": "Lic. Gómez",
                    "dueAt": iso(NOW + timedelta(days=1)),
                    "reason": "Uso temporario",
                    "notes": "Préstamo de prueba",
                },
            )
            ins_open = next(
                loan
                for loan in state["loans"]
                if loan["assetId"] == ins_id and loan["status"] != "returned"
            )
        if ins_open is not None:
            state = await mutate(
                client,
                "POST",
                f"/api/v1/loans/{ins_open['id']}/return",
                {
                    "confirmedInside": True,
                    "administrativeCorrection": False,
                    "notes": "Devuelto en buen estado",
                },
            )

        # Operación de proveedor vencida (supplierPending)
        eqp_003 = asset_ids["EQP-003"]
        if not any(eqp_003 in op["deliveredAssetIds"] for op in state["supplierOperations"]):
            state = await mutate(
                client,
                "POST",
                "/api/v1/supplier-operations",
                {
                    "supplierId": supplier_bio["id"],
                    "assetIds": [eqp_003],
                    "dueAt": iso(NOW - timedelta(days=2)),
                    "reason": "Mantenimiento preventivo",
                    "notes": "Entrega vencida de prueba",
                    "origin": "manual",
                },
            )

        # Operación parcial (incompleteReturn)
        eqp_002 = asset_ids["EQP-002"]
        eqp_005 = asset_ids["EQP-005"]
        partial_exists = any(
            eqp_002 in op["deliveredAssetIds"] and eqp_005 in op["deliveredAssetIds"]
            for op in state["supplierOperations"]
        )
        if not partial_exists:
            state = await mutate(
                client,
                "POST",
                "/api/v1/supplier-operations",
                {
                    "supplierId": supplier_bio["id"],
                    "assetIds": [eqp_002, eqp_005],
                    "dueAt": iso(NOW + timedelta(days=3)),
                    "reason": "Calibración",
                    "notes": "Operación parcial de prueba",
                    "origin": "manual",
                },
            )
            operation = next(
                op
                for op in state["supplierOperations"]
                if eqp_002 in op["deliveredAssetIds"] and eqp_005 in op["deliveredAssetIds"]
            )
            state = await mutate(
                client,
                "POST",
                f"/api/v1/supplier-operations/{operation['id']}/receive",
                {
                    "assetIds": [eqp_002],
                    "notes": "Se recibió solo una unidad",
                    "origin": "manual",
                },
            )

        # Historial RFID (entrada/salida)
        o2_001 = find(state["assets"], "code", "O2-001")
        if o2_001 is not None:
            has_exit = any(
                movement["assetId"] == o2_001["id"] and movement["type"] == "exit"
                for movement in state["movements"]
            )
            if not has_exit:
                state = await send_rfid(
                    client,
                    [
                        {
                            "epc": o2_001["rfidEpc"],
                            "readerId": "LEC-VIRTUAL-01",
                            "accessId": "acc-principal",
                            "timestamp": iso(NOW - timedelta(hours=3)),
                            "directionHint": "outbound",
                            "antenna": 1,
                            "rssi": -55,
                            "origin": "simulator",
                        }
                    ],
                )
                state = await send_rfid(
                    client,
                    [
                        {
                            "epc": o2_001["rfidEpc"],
                            "readerId": "LEC-VIRTUAL-01",
                            "accessId": "acc-principal",
                            "timestamp": iso(NOW - timedelta(hours=2)),
                            "directionHint": "inbound",
                            "antenna": 1,
                            "rssi": -55,
                            "origin": "simulator",
                        }
                    ],
                )

            # Historial de habitación (sensor UTI)
            has_room = any(
                movement["assetId"] == o2_001["id"]
                and movement["type"] in ("roomEntry", "roomExit")
                for movement in state["movements"]
            )
            if not has_room:
                for hint, minutes in (("inbound", 90), ("outbound", 60), ("inbound", 30)):
                    state = await send_rfid(
                        client,
                        [
                            {
                                "epc": o2_001["rfidEpc"],
                                "readerId": "LEC-UTI-01",
                                "accessId": "",
                                "timestamp": iso(NOW - timedelta(minutes=minutes)),
                                "directionHint": hint,
                                "roomId": "zon-uti",
                                "antenna": 1,
                                "rssi": -55,
                                "origin": "simulator",
                            }
                        ],
                    )

        # Lectura ambigua (ambiguousRead)
        eqp_001 = find(state["assets"], "code", "EQP-001")
        ambiguous_exists = any(
            movement["assetId"] == eqp_001["id"] and movement["type"] == "ambiguousRead"
            for movement in state["movements"]
        ) if eqp_001 else True
        if eqp_001 is not None and not ambiguous_exists:
            state = await send_rfid(
                client,
                [
                    {
                        "epc": eqp_001["rfidEpc"],
                        "readerId": "LEC-VIRTUAL-01",
                        "accessId": "acc-principal",
                        "timestamp": iso(NOW - timedelta(minutes=10)),
                        "antenna": 1,
                        "rssi": -55,
                        "origin": "simulator",
                    }
                ],
            )

        # Corrección de inventario (needsInspection) sobre un activo distinto,
        # para no resetear la última detección de EQP-004 (alerta noRecentDetection).
        mob_001 = find(state["assets"], "code", "MOB-001")
        correction_exists = any(
            movement["assetId"] == mob_001["id"]
            and movement["type"] == "inventoryCorrection"
            for movement in state["movements"]
        ) if mob_001 else True
        if mob_001 is not None and not correction_exists:
            state = await mutate(
                client,
                "POST",
                f"/api/v1/assets/{mob_001['id']}/corrections",
                {
                    "roomId": "zon-guardia",
                    "operationalStatus": "needsInspection",
                    "notes": "Mobiliario requiere inspección técnica programada.",
                },
            )

        # Resumen final
        state = await request(client, "GET", "/api/v1/state")
        print("\n[resumen]")
        print(f"  assets:              {len(state['assets'])}")
        print(f"  categories:          {len(state['categories'])}")
        print(f"  accesses:            {len(state['accesses'])}")
        print(f"  zones:               {len(state['zones'])}")
        print(f"  readers:             {len(state['readers'])}")
        print(f"  suppliers:           {len(state['suppliers'])}")
        print(f"  movements:           {len(state['movements'])}")
        print(f"  loans:               {len(state['loans'])}")
        print(f"  supplierOperations:  {len(state['supplierOperations'])}")
        print(f"  alerts:              {len(state['alerts'])}")
        alert_types = sorted({alert["type"] for alert in state["alerts"]})
        print(f"  alert types:         {', '.join(alert_types)}")


if __name__ == "__main__":
    asyncio.run(seed())
