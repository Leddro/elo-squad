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
        self.history: list[dict[str, Any]] = []
        self.progress: dict[str, dict[str, int]] = {}
        self.seen: dict[str, dict[str, int]] = {}
        self.totals: dict[str, int] = {}

    async def get_monochamps(self, platform: str) -> tuple[datetime | None, list[Monochamp]]:
        return self.monochamps.get(platform, (None, []))

    async def save_monochamps(self, platform: str, at: datetime | None, players: list[Monochamp]) -> None:
        self.monochamps[platform] = (at, list(players))

    async def get_cursor(self) -> datetime | None:
        return self.cursor

    async def get_progress(self, platform: str) -> dict[str, int]:
        return dict(self.progress.get(platform, {}))

    async def get_seen(self, region: str) -> dict[str, int]:
        return dict(self.seen.get(region, {}))

    async def save_aggregates(
        self, agg: Aggregator, cursor: datetime,
        progress: dict[str, dict[str, int]], seen: dict[str, dict[str, int]],
    ) -> None:
        self.progress.update({p: dict(s) for p, s in progress.items()})
        self.seen.update({r: dict(m) for r, m in seen.items()})
        for patch, matches in agg.ban_matches.items():
            self.totals[patch] = self.totals.get(patch, 0) + matches
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

    async def ban_matches(self, patches: list[str]) -> int:
        return sum(self.totals.get(p, 0) for p in patches)

    async def save_patch_changes(self, patch: str, changes: PatchChanges) -> None:
        self.patches[patch] = changes

    async def publish(self, document: dict[str, Any]) -> None:
        from app.science.store import history_entry

        self.published = document
        self.history.append(history_entry(document))
