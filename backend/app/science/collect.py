"""Coleta diária das Ciências (roda no GitHub Actions).

    uv run python -m app.science.collect --minutes 45

1. Monochamps: Desafiante e Grão-Mestre de cada plataforma cuja maestria
   no campeão principal é muito maior que no segundo (refeito a cada 7 dias).
2. Partidas: as ranqueadas mais recentes de cada monochamp (desde a última
   coleta). Da partida sai a base de comparação (os 10 jogadores); da linha
   do tempo, a build do monochamp, se ele estava no campeão principal.
3. Grava os contadores, compara o patch atual com o anterior e publica
   `sciences/current`.

Para quando o tempo acaba ou a chave da Riot é recusada; nos dois casos,
grava o que já coletou e publica.
"""

import argparse
import asyncio
import logging
import random
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx

from app.errors import NotFoundError, UpstreamError
from app.science.aggregate import Aggregator
from app.science.extract import champion_games, extract_build
from app.science.items import ItemCatalog
from app.science.patch_diff import PatchChanges, diff_champions, diff_items
from app.science.riot import PLATFORMS, BadRequestError, KeyRejectedError, ScienceRiot
from app.science.scoring import PREVIEW_FILL, ROLE_NAMES, pick_sciences
from app.science.store import Monochamp, ScienceStore

logger = logging.getLogger("science")

DDRAGON = "https://ddragon.leagueoflegends.com"
LANGUAGE = "pt_BR"
MONOCHAMPS_MAX_AGE = timedelta(days=7)
FIRST_LOOKBACK = timedelta(days=3)
MAX_LOOKBACK = timedelta(days=7)
MATCHES_PER_PLAYER = 5
MIN_MASTERY = 200_000
MASTERY_RATIO = 2.5          # campeão principal com 2,5x os pontos do segundo
RECENT_PLAY = timedelta(days=30)
DISCOVERY_SHARE = 0.55       # parte do tempo que a busca de monochamps pode usar


@dataclass(slots=True)
class Report:
    monochamps: int = 0
    matches: int = 0
    samples: int = 0
    sciences: int = 0
    key_rejected: bool = False
    out_of_time: bool = False
    errors: list[str] = field(default_factory=list)


class Deadline:
    def __init__(self, seconds: float, clock: Callable[[], float] = time.monotonic) -> None:
        self._clock = clock
        self._end = clock() + seconds

    def passed(self, share: float = 1.0, total: float | None = None) -> bool:
        return self._clock() >= self._end if total is None else self._clock() >= self._end - total * (1 - share)


class StaticData:
    """Data Dragon (público, sem chave): versões, itens, campeões."""

    def __init__(self, http: httpx.AsyncClient) -> None:
        self._http = http

    async def _json(self, path: str) -> Any:
        response = await self._http.get(f"{DDRAGON}{path}")
        response.raise_for_status()
        return response.json()

    async def versions(self) -> list[str]:
        return await self._json("/api/versions.json")

    async def items(self, version: str) -> dict[str, Any]:
        return (await self._json(f"/cdn/{version}/data/{LANGUAGE}/item.json"))["data"]

    async def champions_full(self, version: str) -> dict[str, Any]:
        return (await self._json(f"/cdn/{version}/data/{LANGUAGE}/championFull.json"))["data"]


def is_monochamp(masteries: list[dict[str, Any]], now: datetime) -> bool:
    if not masteries:
        return False
    top = masteries[0]
    second = masteries[1]["championPoints"] if len(masteries) > 1 else 0
    last_play = datetime.fromtimestamp(top.get("lastPlayTime", 0) / 1000, UTC)
    return (
        top["championPoints"] >= MIN_MASTERY
        and top["championPoints"] >= MASTERY_RATIO * second
        and now - last_play <= RECENT_PLAY
    )


async def _ids_valid(riot: ScienceRiot, platform: str, players: list[Monochamp]) -> bool:
    """O PUUID é criptografado POR CHAVE: trocou a chave, a lista salva não vale
    mais (a Riot responde 400). Um pedido de teste evita perder a coleta."""
    try:
        await riot.top_masteries(platform, players[0].puuid, count=1)
    except NotFoundError:
        return True
    except BadRequestError:
        logger.warning("%s: PUUIDs salvos são de outra chave; refazendo a lista", platform)
        return False
    return True


async def _discover(
    riot: ScienceRiot, store: ScienceStore, platform: str, now: datetime, stop: Callable[[], bool],
) -> list[Monochamp]:
    updated, players = await store.get_monochamps(platform)
    if updated is not None and now - updated < MONOCHAMPS_MAX_AGE and players and await _ids_valid(riot, platform, players):
        return players
    found: list[Monochamp] = []
    complete = True
    for puuid in await riot.apex_puuids(platform):
        if stop():
            complete = False
            break
        try:
            masteries = await riot.top_masteries(platform, puuid)
        except NotFoundError:
            continue
        if is_monochamp(masteries, now):
            found.append(Monochamp(puuid, masteries[0]["championId"]))
    # Incompleta (acabou o tempo): grava sem data, para refazer na próxima.
    await store.save_monochamps(platform, now if complete else None, found)
    logger.info("%s: %d monochamps%s", platform, len(found), "" if complete else " (parcial)")
    return found


async def _harvest(
    riot: ScienceRiot,
    region: str,
    players: list[Monochamp],
    start_time: int,
    agg: Aggregator,
    catalog: ItemCatalog,
    report: Report,
    stop: Callable[[], bool],
) -> None:
    seen: set[str] = set()
    for mono in players:
        if stop():
            report.out_of_time = True
            return
        try:
            ids = await riot.ranked_match_ids(region, mono.puuid, start_time, MATCHES_PER_PLAYER)
        except (NotFoundError, BadRequestError):
            continue
        for match_id in ids:
            if stop():
                report.out_of_time = True
                return
            try:
                match = await riot.match(region, match_id)
                if match_id not in seen:  # a base de comparação conta cada partida uma vez
                    seen.add(match_id)
                    report.matches += 1
                    for game in champion_games(match, catalog):
                        agg.add_champion_game(game)
                player = next((p for p in match["info"]["participants"] if p["puuid"] == mono.puuid), None)
                if player is None or player["championId"] != mono.champion_id:
                    continue
                sample = extract_build(match, await riot.timeline(region, match_id), mono.puuid, catalog)
            except NotFoundError:
                continue
            except KeyRejectedError:
                raise
            except UpstreamError as e:
                report.errors.append(str(e))
                continue
            if sample is not None:
                agg.add_sample(sample)


def _patch(version: str) -> str:
    return ".".join(version.split(".")[:2])


async def publish(store: ScienceStore, static: StaticData, now: datetime) -> int:
    versions = await static.versions()
    current, previous = versions[0], versions[1]
    new_items, old_items = await static.items(current), await static.items(previous)
    new_champs, old_champs = await static.champions_full(current), await static.champions_full(previous)
    changes = PatchChanges(diff_champions(old_champs, new_champs), diff_items(old_items, new_items))
    await store.save_patch_changes(_patch(current), changes)

    catalog = ItemCatalog.from_ddragon(new_items)
    by_id = {int(c["key"]): c for c in new_champs.values()}
    patches = [_patch(current), _patch(previous)]
    sciences = pick_sciences(
        await store.list_builds(patches), await store.list_champions(patches), changes, catalog,
        {cid: c["name"] for cid, c in by_id.items()}, fill_to=PREVIEW_FILL,
    )

    def item(item_id: int) -> dict[str, Any]:
        it = catalog.get(item_id)
        return {"id": item_id, "name": it.name if it else str(item_id),
                "iconUrl": f"{DDRAGON}/cdn/{current}/img/item/{item_id}.png"}

    await store.publish({
        "patch": _patch(current),
        "updatedAt": now,
        "builds": [
            {
                "championId": s.champion_id,
                "championName": by_id[s.champion_id]["name"] if s.champion_id in by_id else "?",
                "championIconUrl": (
                    f"{DDRAGON}/cdn/{current}/img/champion/{by_id[s.champion_id]['id']}.png"
                    if s.champion_id in by_id else None
                ),
                "role": s.role,
                "roleName": ROLE_NAMES[s.role],
                "title": s.title,
                "items": [item(i) for i in s.items],
                "boots": item(s.boots) if s.boots else None,
                "skills": s.skills,
                "maxOrder": s.max_order,
                "games": s.games,
                "wins": s.wins,
            }
            for s in sciences
        ],
    })
    return len(sciences)


async def run(
    riot: ScienceRiot,
    store: ScienceStore,
    static: StaticData,
    now: datetime,
    seconds: float,
    platforms: dict[str, str] = PLATFORMS,
    clock: Callable[[], float] = time.monotonic,
) -> Report:
    report = Report()
    deadline = Deadline(seconds, clock)
    catalog = ItemCatalog.from_ddragon(await static.items((await static.versions())[0]))
    agg = Aggregator()

    cursor = await store.get_cursor()
    start = max(cursor or now - FIRST_LOOKBACK, now - MAX_LOOKBACK)
    start_time = int(start.timestamp())

    def discovery_over() -> bool:
        return deadline.passed(DISCOVERY_SHARE, seconds)

    async def region_job(region: str, region_platforms: list[str]) -> None:
        # Cada região começa a ler partidas assim que as SUAS plataformas
        # terminam a busca de monochamps (sem esperar as outras regiões).
        found = await asyncio.gather(*(_discover(riot, store, p, now, discovery_over) for p in region_platforms))
        players = [m for group in found for m in group]
        report.monochamps += len(players)
        random.shuffle(players)  # sem tempo para todos: amostra justa entre plataformas
        await _harvest(riot, region, players, start_time, agg, catalog, report, deadline.passed)

    by_region: dict[str, list[str]] = {}
    for platform, region in platforms.items():
        by_region.setdefault(region, []).append(platform)
    try:
        await asyncio.gather(*(region_job(r, ps) for r, ps in by_region.items()))
    except KeyRejectedError as e:
        logger.error("%s", e)
        report.key_rejected = True

    report.samples = agg.samples
    if agg.builds or agg.champions:
        await store.save_aggregates(agg, now)
    report.sciences = await publish(store, static, now)
    return report


async def _main(minutes: float, only: list[str] | None, publish_only: bool = False) -> int:
    from app.config import get_settings
    from app.main import _firebase
    from app.science.store import FirestoreScienceStore

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    logging.getLogger("httpx").setLevel(logging.WARNING)  # um log por pedido é demais
    settings = get_settings()
    fb_app, _, _ = _firebase(settings)
    from firebase_admin import firestore_async

    store = FirestoreScienceStore(firestore_async.client(fb_app))
    if publish_only:
        async with httpx.AsyncClient(timeout=20) as http:
            count = await publish(store, StaticData(http), datetime.now(UTC))
        logger.info("Publicado sem coletar: %d ciências", count)
        return 0
    async with httpx.AsyncClient(timeout=20) as http:
        riot = ScienceRiot(http, settings.riot_api_key.get_secret_value())
        platforms = {p: PLATFORMS[p] for p in only} if only else PLATFORMS
        report = await run(riot, store, StaticData(http), datetime.now(UTC), minutes * 60, platforms)
    logger.info(
        "Monochamps %d · partidas %d · builds %d · ciências %d · pedidos %d%s%s",
        report.monochamps, report.matches, report.samples, report.sciences, riot.calls,
        " · tempo esgotado" if report.out_of_time else "", f" · {len(report.errors)} erros" if report.errors else "",
    )
    if report.key_rejected:
        logger.error("A chave da Riot foi recusada: troque RIOT_API_KEY (dev key vence em 24 h).")
        return 1
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Coleta das Ciências")
    parser.add_argument("--minutes", type=float, default=45)
    parser.add_argument("--platforms", nargs="*", choices=sorted(PLATFORMS), help="padrão: todas")
    parser.add_argument("--publish-only", action="store_true", help="só refaz sciences/current, sem chamar a Riot")
    args = parser.parse_args()
    raise SystemExit(asyncio.run(_main(args.minutes, args.platforms, args.publish_only)))
