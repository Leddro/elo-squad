"""Camada anticorrupção: JSON da Riot (nomes deles) → modelos do contrato (nomes nossos).

Se a Riot renomear um campo, só este arquivo muda. O app nem fica sabendo.
"""

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from app.ddragon import Champion, StaticData, champion_icon_url, item_icon_url
from app.models import (
    Item, Mastery, MatchResult, MatchSummary, QueueType, Ranked, RankedEntry, RiotId,
)

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


# ---------- Partidas (match-v5) ----------

# queueId da Riot → fila nossa. Lista oficial: static.developer.riotgames.com/docs/lol/queues.json
_QUEUES: dict[int, QueueType] = {
    420: "RANKED_SOLO",
    440: "RANKED_FLEX",
    400: "NORMAL",  # escolha alternada
    430: "NORMAL",  # escolha às cegas
    480: "NORMAL",  # Swiftplay
    490: "NORMAL",  # Quickplay
    450: "ARAM",
    2400: "ARAM",   # ARAM: Mayhem
    1700: "ARENA",
    1710: "ARENA",
}


@dataclass(frozen=True, slots=True)
class ParticipantStats:
    champion_id: int
    kills: int
    deaths: int
    assists: int
    cs: int
    items: tuple[int, ...]  # 7 posições (item0..item6), 0 = vazio
    win: bool
    placement: int          # Arena: 1 a 8. Outros modos: 0


@dataclass(frozen=True, slots=True)
class MatchRecord:
    """A partida reduzida ao que usamos: ~1% dos ~78 KB do JSON da Riot.

    É ISTO que vai para o cache, não o JSON cru. Guarda os 10 jogadores (por PUUID)
    para reaproveitar a mesma entrada quando dois amigos jogaram juntos.
    """
    match_id: str
    queue_id: int
    duration_seconds: int
    ended_at: datetime
    game_version: str
    remake: bool
    participants: dict[str, ParticipantStats]


def to_match_record(raw: dict[str, Any]) -> MatchRecord:
    info = raw["info"]
    players = info["participants"]
    return MatchRecord(
        match_id=raw["metadata"]["matchId"],
        queue_id=info["queueId"],
        duration_seconds=info["gameDuration"],  # em segundos (desde o patch 11.20)
        ended_at=datetime.fromtimestamp(info["gameEndTimestamp"] / 1000, tz=UTC),  # vem em ms
        game_version=info["gameVersion"],
        # Remake vale para a partida inteira: basta olhar o primeiro jogador.
        remake=bool(players and players[0].get("gameEndedInEarlySurrender", False)),
        participants={p["puuid"]: _to_stats(p) for p in players},
    )


def _to_stats(p: dict[str, Any]) -> ParticipantStats:
    return ParticipantStats(
        champion_id=p["championId"],
        kills=p["kills"],
        deaths=p["deaths"],
        assists=p["assists"],
        cs=p["totalMinionsKilled"] + p["neutralMinionsKilled"],
        items=tuple(p[f"item{i}"] for i in range(7)),
        win=p["win"],
        placement=p.get("placement", 0),
    )


def to_match_summary(record: MatchRecord, puuid: str, static: StaticData) -> MatchSummary:
    me = record.participants[puuid]  # o ID veio do histórico DESTE puuid: ele está na partida
    queue = _QUEUES.get(record.queue_id, "OTHER")
    champion = static.champions.get(me.champion_id)
    latest = static.latest
    item_version = static.version_for_patch(record.game_version)

    def item(item_id: int) -> Item | None:
        if item_id == 0:
            return None
        return Item(item_id=item_id, icon_url=item_icon_url(item_version, item_id) if item_version else None)

    return MatchSummary(
        match_id=record.match_id,
        queue=queue,
        result=_result(record.remake, me.win),
        placement=me.placement if queue == "ARENA" and me.placement > 0 else None,
        champion_id=me.champion_id,
        champion_name=champion.name if champion else None,
        champion_icon_url=champion_icon_url(latest, champion.image_id) if champion and latest else None,
        kills=me.kills,
        deaths=me.deaths,
        assists=me.assists,
        cs=me.cs,
        items=[item(i) for i in me.items[:6]],
        trinket=item(me.items[6]),
        duration_seconds=record.duration_seconds,
        played_at=record.ended_at,
    )


def _result(remake: bool, win: bool) -> MatchResult:
    if remake:
        return "REMAKE"
    return "WIN" if win else "LOSS"
