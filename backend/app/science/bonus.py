"""Bônus dos squads: vitórias na Solo/Duo jogando uma Ciência.

Para cada membro de squad com período em andamento, lê as partidas novas e
confere se a vitória foi com uma Ciência publicada até 24 h antes da partida:
mesmo campeão, mesma rota e os 3 primeiros itens na mesma ordem. Quanto pior o
tier da Ciência, maior o bônus. O resultado fica em scienceBonus/{puuid}, que o
ranking (proxy) soma aos pontos.

Rodado pelo GitHub Actions a cada hora, antes da atualização do ranking:
    uv run python -m app.science.bonus
"""

import argparse
import asyncio
import logging
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Any, Protocol

import httpx

from app.science.collect import StaticData
from app.science.extract import BuildSample, extract_build
from app.science.items import ItemCatalog
from app.errors import UpstreamError
from app.science.riot import ScienceRiot

logger = logging.getLogger(__name__)

# 20 PDL (uma vitória típica) × (multiplicador − 1): S vale ×1,2 e D vale ×2.
BONUS = {"S": 4, "A": 8, "B": 12, "C": 16, "D": 20}
MATCH_ITEMS = 3
VALID_FOR = timedelta(hours=24)  # a Ciência vale até 24 h depois de sair da lista
MATCHES_PER_RUN = 20
KEEP = timedelta(days=100)


@dataclass(frozen=True, slots=True)
class ScienceRef:
    champion_id: int
    champion_name: str
    role: str
    title: str
    tier: str
    items: tuple[int, ...]  # os primeiros (até 3), na ordem


@dataclass(frozen=True, slots=True)
class Publication:
    published_at: datetime
    sciences: list[ScienceRef]

    @staticmethod
    def from_doc(doc: dict[str, Any]) -> "Publication":
        return Publication(
            published_at=doc["publishedAt"],
            sciences=[
                ScienceRef(b["championId"], b["championName"], b["role"], b["title"], b["tier"],
                           tuple(b["items"][:MATCH_ITEMS]))
                for b in doc["builds"]
            ],
        )


def matching_science(sample: BuildSample, played_at: datetime, history: list[Publication]) -> ScienceRef | None:
    """A Ciência que a partida seguiu, entre as publicadas nas 24 h antes dela."""
    for pub in sorted(history, key=lambda p: p.published_at, reverse=True):
        if pub.published_at > played_at:
            continue
        if played_at - pub.published_at > VALID_FOR:
            break
        for sci in pub.sciences:
            if (sci.champion_id, sci.role) == (sample.champion_id, sample.role) and sci.items \
                    and sample.items[:len(sci.items)] == sci.items:
                return sci
    return None


class BonusStore(Protocol):
    async def active_targets(self, now: datetime) -> dict[str, datetime]:
        """PUUID → começo do período mais antigo em andamento entre os squads dele."""
        ...

    async def history(self, since: datetime) -> list[Publication]: ...

    async def known_matches(self, puuid: str) -> set[str]: ...

    async def save_matches(self, puuid: str, matches: dict[str, dict[str, Any]], now: datetime) -> None: ...


async def check_player(
    riot: ScienceRiot, region: str, puuid: str, since: datetime, history: list[Publication],
    catalog: ItemCatalog, known: set[str],
) -> dict[str, dict[str, Any]]:
    """Partidas novas do jogador → registro de cada uma (bônus 0 se não valeu)."""
    ids = await riot.ranked_match_ids(region, puuid, int(since.timestamp()), MATCHES_PER_RUN)
    found: dict[str, dict[str, Any]] = {}
    for match_id in ids:
        if match_id in known:
            continue
        match = await riot.match(region, match_id)
        info = match["info"]
        played_at = datetime.fromtimestamp(info["gameStartTimestamp"] / 1000, UTC)
        record: dict[str, Any] = {"matchId": match_id, "playedAt": played_at, "bonus": 0}
        player = next((p for p in info["participants"] if p["puuid"] == puuid), None)
        if player is not None and player.get("win"):
            # A linha do tempo (ordem dos itens) só para as vitórias.
            sample = extract_build(match, await riot.timeline(region, match_id), puuid, catalog)
            sci = matching_science(sample, played_at, history) if sample else None
            if sci is not None:
                record |= {"championName": sci.champion_name, "title": sci.title, "tier": sci.tier,
                           "bonus": BONUS.get(sci.tier, 0)}
        found[match_id] = record
    return found


async def run(riot: ScienceRiot, store: BonusStore, catalog: ItemCatalog, region: str, now: datetime) -> int:
    """Devolve quantas vitórias com Ciência foram achadas nesta rodada."""
    targets = await store.active_targets(now)
    if not targets:
        return 0
    history = await store.history(min(targets.values()) - VALID_FOR)
    wins = 0
    for puuid, since in targets.items():
        try:
            found = await check_player(riot, region, puuid, since, history, catalog, await store.known_matches(puuid))
        except UpstreamError as e:
            logger.warning("Bônus: Riot indisponível para %s (%s)", puuid, e)
            continue
        if found:
            await store.save_matches(puuid, found, now)
            wins += sum(1 for r in found.values() if r["bonus"])
    return wins


class FirestoreBonusStore:
    COLLECTION = "scienceBonus"

    def __init__(self, db: Any) -> None:
        self._db = db

    async def active_targets(self, now: datetime) -> dict[str, datetime]:
        from app.models import Squad
        from app.periods import default_period

        targets: dict[str, datetime] = {}
        async for doc in self._db.collection("squads").stream():
            squad = Squad.model_validate(doc.to_dict())
            period = squad.period or default_period(now)
            # Folga de 2 h depois do fim: o fechamento do ranking roda de hora em hora.
            if not period.starts_at <= now < period.ends_at + timedelta(hours=2):
                continue
            for member in squad.members.values():
                if member.puuid not in targets or period.starts_at < targets[member.puuid]:
                    targets[member.puuid] = period.starts_at
        return targets

    async def history(self, since: datetime) -> list[Publication]:
        from google.cloud.firestore_v1.base_query import FieldFilter

        query = self._db.collection("scienceHistory").where(filter=FieldFilter("publishedAt", ">=", since))
        return [Publication.from_doc(snap.to_dict()) async for snap in query.stream()]

    async def known_matches(self, puuid: str) -> set[str]:
        snap = await self._db.collection(self.COLLECTION).document(puuid).get()
        return set((snap.to_dict() or {}).get("matches", {})) if snap.exists else set()

    async def save_matches(self, puuid: str, matches: dict[str, dict[str, Any]], now: datetime) -> None:
        ref = self._db.collection(self.COLLECTION).document(puuid)
        snap = await ref.get()
        kept = {
            k: v for k, v in ((snap.to_dict() or {}).get("matches", {}) if snap.exists else {}).items()
            if v["playedAt"] >= now - KEEP
        }
        await ref.set({"matches": kept | matches})


async def _main() -> int:
    from firebase_admin import firestore_async

    from app.config import get_settings
    from app.main import _firebase

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    logging.getLogger("httpx").setLevel(logging.WARNING)
    settings = get_settings()
    fb_app, _, _ = _firebase(settings)
    store = FirestoreBonusStore(firestore_async.client(fb_app))
    async with httpx.AsyncClient(timeout=20) as http:
        static = StaticData(http)
        catalog = ItemCatalog.from_ddragon(await static.items((await static.versions())[0]))
        riot = ScienceRiot(http, settings.riot_api_key.get_secret_value())
        wins = await run(riot, store, catalog, settings.riot_region, datetime.now(UTC))
    logger.info("Bônus: %d vitórias com Ciência · pedidos %d", wins, riot.calls)
    return 0


if __name__ == "__main__":
    argparse.ArgumentParser(description="Bônus das Ciências nos squads").parse_args()
    raise SystemExit(asyncio.run(_main()))
