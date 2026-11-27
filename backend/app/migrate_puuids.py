"""Troca de chave da Riot: refaz os PUUIDs salvos no Firestore.

O PUUID que a Riot devolve é criptografado POR CHAVE. Depois de trocar a
RIOT_API_KEY, os PUUIDs salvos (usuários, membros dos squads e retratos da
semana) deixam de valer: a Riot responde 400. Este script pega o PUUID novo de
cada um pelo Riot ID (account-v1) e regrava.

Uso:  uv run python -m app.migrate_puuids          (só mostra)
      uv run python -m app.migrate_puuids --apply  (grava)
"""

import argparse
import asyncio
from datetime import UTC, datetime
from urllib.parse import quote

import httpx

from app.ranking import week_id
from app.store import SQUADS, USERS, WEEKS


async def _new_puuid(http: httpx.AsyncClient, key: str, region: str, riot_id: dict[str, str]) -> str | None:
    name, tag = quote(riot_id["gameName"], safe=""), quote(riot_id["tagLine"], safe="")
    response = await http.get(
        f"https://{region}.api.riotgames.com/riot/account/v1/accounts/by-riot-id/{name}/{tag}",
        headers={"X-Riot-Token": key},
    )
    if response.status_code == 404:
        return None
    response.raise_for_status()
    return response.json()["puuid"]


async def main(apply: bool) -> None:
    from firebase_admin import firestore_async

    from app.config import get_settings
    from app.main import _firebase

    settings = get_settings()
    fb_app, _, _ = _firebase(settings)
    db = firestore_async.client(fb_app)
    key = settings.riot_api_key.get_secret_value()
    mapping: dict[str, str] = {}  # PUUID antigo → novo

    async with httpx.AsyncClient(timeout=20) as http:
        async def resolve(old: str, riot_id: dict[str, str]) -> str | None:
            if old not in mapping:
                new = await _new_puuid(http, key, settings.riot_region, riot_id)
                if new is None:
                    print(f"  ! Riot ID não encontrado: {riot_id['gameName']}#{riot_id['tagLine']}")
                    return None
                mapping[old] = new
            return mapping[old]

        batch = db.batch()
        writes = 0
        async for snap in db.collection(USERS).stream():
            data = snap.to_dict()
            if not data.get("riotId") or not data.get("puuid"):
                continue
            new = await resolve(data["puuid"], data["riotId"])
            if new and new != data["puuid"]:
                print(f"usuário {data['riotId']['gameName']}: PUUID trocado")
                batch.set(snap.reference, {"puuid": new}, merge=True)
                writes += 1

        async for snap in db.collection(SQUADS).stream():
            members = snap.to_dict().get("members", {})
            for uid, member in members.items():
                new = await resolve(member["puuid"], member["riotId"])
                if new and new != member["puuid"]:
                    print(f"squad {snap.to_dict().get('name')}: {member['riotId']['gameName']} trocado")
                    batch.update(snap.reference, {f"members.{uid}.puuid": new})
                    writes += 1

        # Retratos da semana atual: o ponto de partida do ranking continua valendo.
        week = week_id(datetime.now(UTC))
        snapshots = db.collection(WEEKS).document(week).collection("snapshots")
        for old, new in mapping.items():
            if old == new:
                continue
            snap = await snapshots.document(old).get()
            if snap.exists and not (await snapshots.document(new).get()).exists:
                print(f"retrato da semana {week}: copiado para o PUUID novo")
                batch.set(snapshots.document(new), snap.to_dict())
                writes += 1

    print(f"{writes} gravações{'' if apply else ' (simulação; use --apply para gravar)'}")
    if apply and writes:
        await batch.commit()
        print("Gravado.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Refaz os PUUIDs depois de trocar a chave da Riot")
    parser.add_argument("--apply", action="store_true")
    asyncio.run(main(parser.parse_args().apply))
