"""Store das Ciências em MEMÓRIA, com o mesmo contrato do FirestoreScienceStore."""

from datetime import datetime
from typing import Any

from app.science.aggregate import Aggregator, BuildStats, ChampionStats
from app.science.patch_diff import PatchChanges
from app.science.store import Monochamp


class InMemoryScienceStore:
    def __init__(self) -> None:
        self.monochamps: dict[str, tuple[datetime | None, list[Monochamp]]] = {}
        self.cursor: datetime | None = None
        self.builds: dict[str, BuildStats] = {}
        self.champions: dict[str, ChampionStats] = {}
        self.patches: dict[str, PatchChanges] = {}
        self.published: dict[str, Any] | None = None

    async def get_monochamps(self, platform: str) -> tuple[datetime | None, list[Monochamp]]:
        return self.monochamps.get(platform, (None, []))

    async def save_monochamps(self, platform: str, at: datetime | None, players: list[Monochamp]) -> None:
        self.monochamps[platform] = (at, list(players))

    async def get_cursor(self) -> datetime | None:
        return self.cursor

    async def save_aggregates(self, agg: Aggregator, cursor: datetime) -> None:
        for key, b in agg.builds.items():
            target = self.builds.setdefault(key, BuildStats(b.patch, b.champion_id, b.role, b.core))
            target.merge(b)
        for key, c in agg.champions.items():
            self.champions.setdefault(key, ChampionStats(c.patch, c.champion_id)).merge(c)
        self.cursor = cursor

    async def list_builds(self, patches: list[str]) -> list[BuildStats]:
        return [b for b in self.builds.values() if b.patch in patches]

    async def list_champions(self, patches: list[str]) -> list[ChampionStats]:
        return [c for c in self.champions.values() if c.patch in patches]

    async def save_patch_changes(self, patch: str, changes: PatchChanges) -> None:
        self.patches[patch] = changes

    async def publish(self, document: dict[str, Any]) -> None:
        self.published = document
