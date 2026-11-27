"""Contadores das builds e dos campeões (o que vai para o Firestore).

A coleta soma tudo em memória (Aggregator) e grava só os INCREMENTOS no fim,
um documento por build ou campeão tocado. Assim nenhuma partida bruta é
guardada, e as escritas ficam na cota gratuita do Firestore.
"""

from collections import Counter
from dataclasses import dataclass, field

from app.science.extract import BuildSample, ChampionGame


def build_key(patch: str, champion_id: int, role: str, core: tuple[int, int]) -> str:
    """Uma "build" = campeão + rota + os 2 primeiros itens completos, por patch."""
    return f"{patch}_{champion_id}_{role}_{core[0]}_{core[1]}"


def champion_key(patch: str, champion_id: int) -> str:
    return f"{patch}_{champion_id}"


@dataclass(slots=True)
class BuildStats:
    patch: str
    champion_id: int
    role: str
    core: tuple[int, int]
    games: int = 0
    wins: int = 0
    thirds: Counter[int] = field(default_factory=Counter)    # 3º item completo
    boots: Counter[int] = field(default_factory=Counter)
    skills: Counter[str] = field(default_factory=Counter)    # ordem das habilidades
    keystones: Counter[int] = field(default_factory=Counter)

    @property
    def key(self) -> str:
        return build_key(self.patch, self.champion_id, self.role, self.core)

    def merge(self, other: "BuildStats") -> None:
        self.games += other.games
        self.wins += other.wins
        self.thirds.update(other.thirds)
        self.boots.update(other.boots)
        self.skills.update(other.skills)
        self.keystones.update(other.keystones)


@dataclass(slots=True)
class ChampionStats:
    patch: str
    champion_id: int
    games: int = 0
    wins: int = 0
    roles: Counter[str] = field(default_factory=Counter)
    items: Counter[int] = field(default_factory=Counter)  # partidas em que o item estava no fim
    bans: int = 0  # partidas em que foi banido

    @property
    def key(self) -> str:
        return champion_key(self.patch, self.champion_id)

    def merge(self, other: "ChampionStats") -> None:
        self.games += other.games
        self.wins += other.wins
        self.bans += other.bans
        self.roles.update(other.roles)
        self.items.update(other.items)


class Aggregator:
    def __init__(self) -> None:
        self.builds: dict[str, BuildStats] = {}
        self.champions: dict[str, ChampionStats] = {}
        self.ban_matches: Counter[str] = Counter()  # patch → partidas com os bans contados
        self.samples = 0

    def add_bans(self, patch: str, banned: set[int]) -> None:
        self.ban_matches[patch] += 1
        for champion_id in banned:
            key = champion_key(patch, champion_id)
            self.champions.setdefault(key, ChampionStats(patch, champion_id)).bans += 1

    def add_sample(self, s: BuildSample) -> None:
        core = (s.items[0], s.items[1])
        key = build_key(s.patch, s.champion_id, s.role, core)
        stats = self.builds.setdefault(key, BuildStats(s.patch, s.champion_id, s.role, core))
        stats.games += 1
        stats.wins += s.win
        if len(s.items) >= 3:
            stats.thirds[s.items[2]] += 1
        if s.boots is not None:
            stats.boots[s.boots] += 1
        if s.skills:
            stats.skills[s.skills] += 1
        if s.keystone is not None:
            stats.keystones[s.keystone] += 1
        self.samples += 1

    def add_champion_game(self, g: ChampionGame) -> None:
        key = champion_key(g.patch, g.champion_id)
        stats = self.champions.setdefault(key, ChampionStats(g.patch, g.champion_id))
        stats.games += 1
        stats.wins += g.win
        stats.roles[g.role] += 1
        stats.items.update(g.final_items)
