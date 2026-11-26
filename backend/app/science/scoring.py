"""Quais builds viram Ciência, em que ordem, e o título de cada uma.

Ciência = build de monochamp de elite que é INCOMUM (rota ou itens fora do
padrão do campeão) e que GANHA (limite inferior de Wilson do winrate, que
desconta amostras pequenas). Buffs no patch dão um empurrão pequeno.
"""

import math
from collections import Counter
from dataclasses import dataclass

from app.science.aggregate import BuildStats, ChampionStats
from app.science.items import ItemCatalog
from app.science.patch_diff import PatchChanges

MIN_GAMES = 8                # partidas mínimas da build
MIN_CHAMPION_GAMES = 30      # abaixo disso não dá para dizer o que é "comum" no campeão
OFF_ROLE_SHARE = 0.15        # rota em menos de 15% das partidas do campeão
OFF_BUILD_SHARE = 0.15       # item em menos de 15% das partidas do campeão
MIN_WINRATE = 0.5
PATCH_WEIGHT = 0.01          # por ponto de buff/nerf
MAX_PATCH_BONUS = 0.05
MAX_PER_CHAMPION = 3
MAX_SCIENCES = 60

ROLE_NAMES = {"TOP": "Top", "JUNGLE": "Selva", "MIDDLE": "Mid", "BOTTOM": "Bot", "UTILITY": "Suporte"}
_ROLE_PHRASE = {"TOP": "no Top", "JUNGLE": "na Selva", "MIDDLE": "no Mid", "BOTTOM": "no Bot", "UTILITY": "de Suporte"}


@dataclass(frozen=True, slots=True)
class Science:
    champion_id: int
    role: str
    title: str
    items: list[int]        # 2 ou 3 itens completos, em ordem
    boots: int | None
    skills: str             # habilidade de cada nível, ex.: "QEWQQRQEQ..."
    max_order: str          # ex.: "Q > E > W"
    games: int
    wins: int
    score: float


def wilson_lower_bound(wins: int, games: int, z: float = 1.645) -> float:
    """Winrate "pessimista" (90%): 7 de 8 vale menos que 70 de 80."""
    if games == 0:
        return 0.0
    p = wins / games
    denominator = 1 + z * z / games
    centre = p + z * z / (2 * games)
    margin = z * math.sqrt(p * (1 - p) / games + z * z / (4 * games * games))
    return (centre - margin) / denominator


def max_order(skills: str) -> str:
    """Em que ordem Q, W e E chegam ao máximo (5 pontos). Ex.: "Q > E > W"."""
    counts: Counter[str] = Counter()
    order: list[str] = []
    for key in skills:
        if key == "R":
            continue
        counts[key] += 1
        if counts[key] == 5:
            order.append(key)
    rest = sorted((k for k in "QWE" if k not in order), key=lambda k: -counts[k])
    return " > ".join(order + rest)


def _patch_bonus(build: BuildStats, items: list[int], changes: PatchChanges) -> float:
    points = changes.champions.get(build.champion_id, 0) + sum(changes.items.get(i, 0) for i in items)
    return max(-MAX_PATCH_BONUS, min(MAX_PATCH_BONUS, points * PATCH_WEIGHT))


def _merge_by_build(builds: list[BuildStats]) -> list[BuildStats]:
    """Soma os patches (ex.: o atual e o anterior) de cada build."""
    merged: dict[tuple[int, str, tuple[int, int]], BuildStats] = {}
    for b in builds:
        key = (b.champion_id, b.role, b.core)
        if key not in merged:
            merged[key] = BuildStats(b.patch, b.champion_id, b.role, b.core)
        merged[key].merge(b)
    return list(merged.values())


def _merge_by_champion(champions: list[ChampionStats]) -> dict[int, ChampionStats]:
    merged: dict[int, ChampionStats] = {}
    for c in champions:
        merged.setdefault(c.champion_id, ChampionStats(c.patch, c.champion_id)).merge(c)
    return merged


def pick_sciences(
    builds: list[BuildStats],
    champions: list[ChampionStats],
    changes: PatchChanges,
    catalog: ItemCatalog,
    champion_names: dict[int, str],
) -> list[Science]:
    by_champion = _merge_by_champion(champions)
    candidates: list[tuple[Science, bool]] = []
    for build in _merge_by_build(builds):
        champ = by_champion.get(build.champion_id)
        if build.games < MIN_GAMES or champ is None or champ.games < MIN_CHAMPION_GAMES:
            continue
        if build.wins / build.games < MIN_WINRATE:
            continue
        off_role = champ.roles[build.role] / champ.games < OFF_ROLE_SHARE
        off_build = min(champ.items[i] for i in build.core) / champ.games < OFF_BUILD_SHARE
        if not (off_role or off_build):
            continue

        items = list(build.core)
        if build.thirds:
            third, count = build.thirds.most_common(1)[0]
            if count * 2 >= build.games or len(build.thirds) == 1:
                items.append(third)
        skills = _typical_skills(build.skills)
        science = Science(
            champion_id=build.champion_id,
            role=build.role,
            title=_title(champion_names.get(build.champion_id, "?"), catalog.archetype(items), build.role,
                         off_role, catalog, items),
            items=items,
            boots=build.boots.most_common(1)[0][0] if build.boots else None,
            skills=skills,
            max_order=max_order(skills),
            games=build.games,
            wins=build.wins,
            score=wilson_lower_bound(build.wins, build.games) + _patch_bonus(build, items, changes),
        )
        candidates.append((science, off_role))

    candidates.sort(key=lambda c: c[0].score, reverse=True)
    picked: list[Science] = []
    per_champion: Counter[int] = Counter()
    titles: set[str] = set()
    for science, _ in candidates:
        if per_champion[science.champion_id] >= MAX_PER_CHAMPION:
            continue
        if science.title in titles:  # mesmo título no mesmo campeão: diferencia pelo 1º item
            first = catalog.get(science.items[0])
            science = _with_title(science, f"{science.title} · {first.name if first else science.items[0]}")
        titles.add(science.title)
        per_champion[science.champion_id] += 1
        picked.append(science)
        if len(picked) == MAX_SCIENCES:
            break
    return picked


def _typical_skills(skills: Counter[str]) -> str:
    """A ordem mais comum entre as que vão mais longe (partidas mais longas)."""
    if not skills:
        return ""
    longest = max(len(s) for s in skills)
    pool = Counter({s: c for s, c in skills.items() if len(s) >= min(longest, 15)})
    return pool.most_common(1)[0][0]


def _title(
    champion: str, archetype: str | None, role: str, off_role: bool, catalog: ItemCatalog, items: list[int],
) -> str:
    """Ex.: "Malphite AP no Mid", "Jinx Letalidade", "Sona de Mandamento Imperial"."""
    title = f"{champion} {archetype}" if archetype else champion
    if off_role:
        return f"{title} {_ROLE_PHRASE[role]}"
    if archetype:
        return title
    first = catalog.get(items[0])
    return f"{champion} de {first.name}" if first else champion


def _with_title(s: Science, title: str) -> Science:
    return Science(
        s.champion_id, s.role, title, s.items, s.boots, s.skills, s.max_order, s.games, s.wins, s.score,
    )
