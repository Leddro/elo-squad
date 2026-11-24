"""Camada anticorrupção: JSON da Riot (nomes deles) → modelos do contrato (nomes nossos).

Se a Riot renomear um campo, só este arquivo muda. O app nem fica sabendo.
"""

from typing import Any

from app.ddragon import Champion, champion_icon_url
from app.models import Mastery, Ranked, RankedEntry, RiotId

QUEUE_SOLO = "RANKED_SOLO_5x5"
QUEUE_FLEX = "RANKED_FLEX_SR"


def to_riot_id(account: dict[str, Any]) -> RiotId:
    # Usa a grafia oficial da Riot: quem buscou "fulano#br1" recebe "Fulano#BR1".
    return RiotId(game_name=account["gameName"], tag_line=account["tagLine"])


def to_ranked(entries: list[dict[str, Any]]) -> Ranked:
    by_queue = {e["queueType"]: e for e in entries}
    return Ranked(solo=_to_entry(by_queue.get(QUEUE_SOLO)), flex=_to_entry(by_queue.get(QUEUE_FLEX)))


def _to_entry(raw: dict[str, Any] | None) -> RankedEntry | None:
    if raw is None:
        return None
    return RankedEntry(
        tier=raw["tier"],
        division=raw["rank"],
        lp=raw["leaguePoints"],
        wins=raw["wins"],
        losses=raw["losses"],
    )


def to_masteries(
    raw: list[dict[str, Any]], champions: dict[int, Champion], version: str | None
) -> list[Mastery]:
    return [_to_mastery(m, champions.get(m["championId"]), version) for m in raw]


def _to_mastery(raw: dict[str, Any], champion: Champion | None, version: str | None) -> Mastery:
    return Mastery(
        champion_id=raw["championId"],
        champion_name=champion.name if champion else None,
        champion_icon_url=champion_icon_url(version, champion.image_id) if champion and version else None,
        level=raw["championLevel"],
        points=raw["championPoints"],
    )
