"""Persistência das Ciências no Firestore.

  scienceMonochamps/{plataforma}   lista de monochamps (refeita a cada 7 dias)
  scienceMeta/collector            última coleta (ponto de partida de quem não tem progresso)
  scienceProgress/{plataforma}     até onde as partidas de cada monochamp foram lidas
  scienceSeen/{região}             partidas já contadas na base (não contar duas vezes)
  scienceBuilds/{patch_campeão_rota_item1_item2}   contadores da build
  scienceChampions/{patch_campeão}  base de comparação (rotas e itens de todos)
  sciencePatches/{patch}           buffs e nerfs detectados (uso interno)
  sciences/current                 o que o app mostra (ÚNICO documento legível)
"""

from collections import Counter
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Protocol

from app.science.aggregate import Aggregator, BuildStats, ChampionStats
from app.science.patch_diff import PatchChanges

MONOCHAMPS = "scienceMonochamps"
META = "scienceMeta"
BUILDS = "scienceBuilds"
CHAMPIONS = "scienceChampions"
PATCHES = "sciencePatches"
PUBLISHED = "sciences"
PROGRESS = "scienceProgress"  # scienceProgress/{plataforma}: até onde cada monochamp foi lido
SEEN = "scienceSeen"          # scienceSeen/{região}: partidas já contadas (últimos 7 dias)
TOTALS = "scienceTotals"      # scienceTotals/{patch}: partidas com os bans contados
_BATCH = 400  # o Firestore aceita até 500 operações por lote


@dataclass(frozen=True, slots=True)
class Monochamp:
    puuid: str
    champion_id: int


class ScienceStore(Protocol):
    async def get_monochamps(self, platform: str) -> tuple[datetime | None, list[Monochamp]]: ...

    async def save_monochamps(self, platform: str, at: datetime | None, players: list[Monochamp]) -> None: ...

    async def get_cursor(self) -> datetime | None: ...

    async def get_progress(self, platform: str) -> dict[str, int]:
        """puuid → até quando (epoch s) as partidas dele já foram lidas."""
        ...

    async def get_seen(self, region: str) -> dict[str, int]:
        """Partidas já contadas na base de comparação (id → início, epoch s)."""
        ...

    async def save_aggregates(
        self, agg: Aggregator, cursor: datetime,
        progress: dict[str, dict[str, int]], seen: dict[str, dict[str, int]],
    ) -> None:
        """Soma os contadores e, só depois de tudo gravado, o progresso."""
        ...

    async def list_builds(self, patches: list[str]) -> list[BuildStats]: ...

    async def list_champions(self, patches: list[str]) -> list[ChampionStats]: ...

    async def ban_matches(self, patches: list[str]) -> int:
        """Partidas em que os bans foram contados (denominador da taxa de ban)."""
        ...

    async def save_patch_changes(self, patch: str, changes: PatchChanges) -> None: ...

    async def publish(self, document: dict[str, Any]) -> None: ...


def _str_keys(counter: Counter[Any]) -> dict[str, int]:
    return {str(k): v for k, v in counter.items()}


class FirestoreScienceStore:
    def __init__(self, db: Any) -> None:  # google.cloud.firestore.AsyncClient
        self._db = db

    async def get_monochamps(self, platform: str) -> tuple[datetime | None, list[Monochamp]]:
        snap = await self._db.collection(MONOCHAMPS).document(platform).get()
        if not snap.exists:
            return None, []
        data = snap.to_dict()
        return data.get("updatedAt"), [Monochamp(p["puuid"], p["championId"]) for p in data.get("players", [])]

    async def save_monochamps(self, platform: str, at: datetime | None, players: list[Monochamp]) -> None:
        await self._db.collection(MONOCHAMPS).document(platform).set({
            "updatedAt": at, "players": [{"puuid": p.puuid, "championId": p.champion_id} for p in players],
        })

    async def get_cursor(self) -> datetime | None:
        snap = await self._db.collection(META).document("collector").get()
        return snap.to_dict().get("cursor") if snap.exists else None

    async def get_progress(self, platform: str) -> dict[str, int]:
        snap = await self._db.collection(PROGRESS).document(platform).get()
        return dict(snap.to_dict().get("since", {})) if snap.exists else {}

    async def get_seen(self, region: str) -> dict[str, int]:
        snap = await self._db.collection(SEEN).document(region).get()
        return dict(snap.to_dict().get("matches", {})) if snap.exists else {}

    async def save_aggregates(
        self, agg: Aggregator, cursor: datetime,
        progress: dict[str, dict[str, int]], seen: dict[str, dict[str, int]],
    ) -> None:
        from google.cloud.firestore import Increment

        def inc(counter: Counter[Any]) -> dict[str, Any]:
            return {k: Increment(v) for k, v in _str_keys(counter).items()}

        writes: list[tuple[Any, dict[str, Any]]] = []
        for b in agg.builds.values():
            writes.append((self._db.collection(BUILDS).document(b.key), {
                "patch": b.patch, "championId": b.champion_id, "role": b.role, "core": list(b.core),
                "games": Increment(b.games), "wins": Increment(b.wins),
                "thirds": inc(b.thirds), "boots": inc(b.boots), "skills": inc(b.skills),
                "keystones": inc(b.keystones),
            }))
        for c in agg.champions.values():
            writes.append((self._db.collection(CHAMPIONS).document(c.key), {
                "patch": c.patch, "championId": c.champion_id,
                "games": Increment(c.games), "wins": Increment(c.wins),
                "roles": inc(c.roles), "items": inc(c.items), "bans": Increment(c.bans),
            }))
        for patch, matches in agg.ban_matches.items():
            writes.append((self._db.collection(TOTALS).document(patch), {"banMatches": Increment(matches)}))
        for start in range(0, len(writes), _BATCH):
            batch = self._db.batch()
            for ref, data in writes[start:start + _BATCH]:
                batch.set(ref, data, merge=True)  # merge + Increment: soma ao que já existe
            await batch.commit()
        # set sem merge: substitui o mapa inteiro (já vem podado pela coleta)
        for platform, since in progress.items():
            await self._db.collection(PROGRESS).document(platform).set({"since": since})
        for region, matches in seen.items():
            await self._db.collection(SEEN).document(region).set({"matches": matches})
        await self._db.collection(META).document("collector").set({"cursor": cursor}, merge=True)

    async def list_builds(self, patches: list[str]) -> list[BuildStats]:
        from google.cloud.firestore_v1.base_query import FieldFilter

        query = self._db.collection(BUILDS).where(filter=FieldFilter("patch", "in", patches))
        out: list[BuildStats] = []
        async for snap in query.stream():
            d = snap.to_dict()
            out.append(BuildStats(
                d["patch"], d["championId"], d["role"], (d["core"][0], d["core"][1]),
                d.get("games", 0), d.get("wins", 0),
                Counter({int(k): v for k, v in d.get("thirds", {}).items()}),
                Counter({int(k): v for k, v in d.get("boots", {}).items()}),
                Counter(d.get("skills", {})),
                Counter({int(k): v for k, v in d.get("keystones", {}).items()}),
            ))
        return out

    async def list_champions(self, patches: list[str]) -> list[ChampionStats]:
        from google.cloud.firestore_v1.base_query import FieldFilter

        query = self._db.collection(CHAMPIONS).where(filter=FieldFilter("patch", "in", patches))
        out: list[ChampionStats] = []
        async for snap in query.stream():
            d = snap.to_dict()
            out.append(ChampionStats(
                d["patch"], d["championId"], d.get("games", 0), d.get("wins", 0),
                Counter(d.get("roles", {})), Counter({int(k): v for k, v in d.get("items", {}).items()}),
                d.get("bans", 0),
            ))
        return out

    async def ban_matches(self, patches: list[str]) -> int:
        total = 0
        for patch in patches:
            snap = await self._db.collection(TOTALS).document(patch).get()
            total += snap.to_dict().get("banMatches", 0) if snap.exists else 0
        return total

    async def save_patch_changes(self, patch: str, changes: PatchChanges) -> None:
        await self._db.collection(PATCHES).document(patch).set({
            "champions": {str(k): v for k, v in changes.champions.items()},
            "items": {str(k): v for k, v in changes.items.items()},
        })

    async def publish(self, document: dict[str, Any]) -> None:
        await self._db.collection(PUBLISHED).document("current").set(document)
