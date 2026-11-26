"""Uma partida (match-v5 + timeline) → a build de UM jogador, e a base de comparação."""

from dataclasses import dataclass
from typing import Any

from app.science.items import ItemCatalog

RANKED_SOLO = 420
MIN_DURATION_S = 15 * 60  # partidas curtas (remake, rendição cedo) não dizem nada da build
ROLES = ("TOP", "JUNGLE", "MIDDLE", "BOTTOM", "UTILITY")
SKILL_KEYS = "QWER"
MAX_LEVEL = 18


@dataclass(frozen=True, slots=True)
class BuildSample:
    match_id: str
    patch: str               # "16.23"
    champion_id: int
    role: str                # um de ROLES
    win: bool
    items: tuple[int, ...]   # itens completos, na ordem da 1ª compra
    boots: int | None        # botas de 2º nível
    skills: str              # ordem das habilidades, ex.: "QEWQQRQEQEREEWWRWW"
    keystone: int | None


@dataclass(frozen=True, slots=True)
class ChampionGame:
    """Base de comparação: como QUALQUER jogador da partida jogou o campeão."""
    patch: str
    champion_id: int
    role: str
    win: bool
    final_items: frozenset[int]


def patch_of(game_version: str) -> str:
    """"16.23.840.6595" → "16.23"."""
    return ".".join(game_version.split(".")[:2])


def _usable(info: dict[str, Any]) -> bool:
    return info.get("queueId") == RANKED_SOLO and info.get("gameDuration", 0) >= MIN_DURATION_S


def extract_build(
    match: dict[str, Any], timeline: dict[str, Any], puuid: str, catalog: ItemCatalog,
) -> BuildSample | None:
    """None quando a partida não serve (fila errada, curta, sem rota, menos de 2 itens)."""
    info = match["info"]
    if not _usable(info):
        return None
    player = next((p for p in info["participants"] if p["puuid"] == puuid), None)
    if player is None or player.get("gameEndedInEarlySurrender") or player.get("teamPosition") not in ROLES:
        return None

    pid = next(
        (p["participantId"] for p in timeline["info"]["participants"] if p["puuid"] == puuid),
        player.get("participantId"),
    )
    events = sorted(
        (e for frame in timeline["info"]["frames"] for e in frame["events"] if e.get("participantId") == pid),
        key=lambda e: e["timestamp"],
    )

    purchases: list[int] = []
    skills: list[str] = []
    for e in events:
        kind = e["type"]
        if kind == "ITEM_PURCHASED":
            purchases.append(e["itemId"])
        elif kind == "ITEM_UNDO":
            # Desfez a compra: some a última compra desse item.
            before = e.get("beforeId")
            for i in range(len(purchases) - 1, -1, -1):
                if purchases[i] == before:
                    del purchases[i]
                    break
        elif kind == "SKILL_LEVEL_UP" and e.get("levelUpType") == "NORMAL" and 1 <= e.get("skillSlot", 0) <= 4:
            skills.append(SKILL_KEYS[e["skillSlot"] - 1])

    items: list[int] = []
    boots: int | None = None
    for item_id in purchases:
        if catalog.is_completed(item_id):
            if item_id not in items:
                items.append(item_id)
        elif boots is None and (tier2 := catalog.boots_tier2(item_id)) is not None:
            boots = tier2
    if len(items) < 2:
        return None

    styles = player.get("perks", {}).get("styles", [])
    keystone = styles[0]["selections"][0]["perk"] if styles and styles[0].get("selections") else None
    return BuildSample(
        match_id=match["metadata"]["matchId"],
        patch=patch_of(info["gameVersion"]),
        champion_id=player["championId"],
        role=player["teamPosition"],
        win=bool(player["win"]),
        items=tuple(items),
        boots=boots,
        skills="".join(skills[:MAX_LEVEL]),
        keystone=keystone,
    )


def champion_games(match: dict[str, Any], catalog: ItemCatalog) -> list[ChampionGame]:
    """Os 10 jogadores da partida (não precisa da linha do tempo): rota e itens finais."""
    info = match["info"]
    if not _usable(info):
        return []
    patch = patch_of(info["gameVersion"])
    return [
        ChampionGame(
            patch=patch, champion_id=p["championId"], role=p["teamPosition"], win=bool(p["win"]),
            final_items=frozenset(i for k in range(6) if catalog.is_completed(i := p.get(f"item{k}", 0))),
        )
        for p in info["participants"]
        if p.get("teamPosition") in ROLES and not p.get("gameEndedInEarlySurrender")
    ]
