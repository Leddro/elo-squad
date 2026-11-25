"""Ranking semanal de cada squad: PDL ganho na Solo/Duo desde segunda-feira.

Rodado por tarefas agendadas (Cloud Scheduler → POST /jobs/...):
- `refresh()`, periódico: atualiza o ranking da semana atual e avisa promoções.
- `close_week()`, segunda 00:05: fecha a semana anterior, avisa o destaque e
  tira o "retrato" do elo de todos para a semana nova.
"""

import asyncio
import logging
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from app import mappers
from app.cache import TTLCache
from app.config import Settings
from app.errors import RiotError
from app.models import RankedEntry, RankingEntry, RankSnapshot, Squad, WeeklyRanking
from app.notifier import Notifier
from app.ranking import absolute_lp, rank_step, week_id, week_start
from app.riot_client import RiotClient
from app.store import Store

logger = logging.getLogger(__name__)

# Chamadas simultâneas à Riot (dev key: 20 por segundo).
_CONCURRENCY = 5

_TIER_NAMES = {
    "IRON": "Ferro", "BRONZE": "Bronze", "SILVER": "Prata", "GOLD": "Ouro",
    "PLATINUM": "Platina", "EMERALD": "Esmeralda", "DIAMOND": "Diamante",
    "MASTER": "Mestre", "GRANDMASTER": "Grão-Mestre", "CHALLENGER": "Desafiante",
}


def rank_label(entry: RankedEntry) -> str:
    name = _TIER_NAMES[entry.tier]
    return name if entry.tier in ("MASTER", "GRANDMASTER", "CHALLENGER") else f"{name} {entry.division}"


@dataclass(frozen=True, slots=True)
class _Fetched:
    """Elo atual de cada PUUID. `failed`: a Riot não respondeu para esses."""
    current: dict[str, RankedEntry | None]
    failed: set[str]


def build_entries(
    squad: Squad,
    starts: dict[str, RankSnapshot],
    current: dict[str, RankedEntry | None],
) -> list[RankingEntry]:
    """Monta e ORDENA o ranking: maior PDL ganho primeiro; sem ranque por último."""
    entries = []
    for uid in squad.member_uids:
        member = squad.members[uid]
        now = current.get(member.puuid)
        start = starts[member.puuid].entry if member.puuid in starts else None
        both = now is not None and start is not None
        entries.append(RankingEntry(
            uid=uid, display_name=member.display_name, riot_id=member.riot_id,
            profile_icon_url=member.profile_icon_url, current=now,
            lp_delta=absolute_lp(now) - absolute_lp(start) if both else None,  # type: ignore[arg-type]
            games=(now.wins + now.losses) - (start.wins + start.losses) if both else 0,  # type: ignore[union-attr]
        ))
    return sorted(entries, key=lambda e: (e.lp_delta is None, -(e.lp_delta or 0), e.riot_id.game_name.casefold()))


class RankingService:
    def __init__(
        self,
        store: Store,
        riot: RiotClient,
        cache: TTLCache,
        settings: Settings,
        notifier: Notifier,
        clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._store = store
        self._riot = riot
        self._cache = cache
        self._s = settings
        self._notifier = notifier
        self._clock = clock

    async def refresh(self) -> int:
        """Atualiza o ranking da semana atual de todos os squads. Devolve quantos."""
        now = self._clock()
        week = week_id(now)
        squads = await self._store.list_squads()
        fetched = await self._fetch(self._puuids(squads))
        starts = await self._starts(week, fetched, now)

        for squad_id, squad in squads:
            previous = await self._store.get_ranking(squad_id, week)
            current = self._with_fallback(fetched, previous, squad)
            ranking = WeeklyRanking(
                week_id=week, week_start=week_start(now), updated_at=now, final=False,
                entries=build_entries(squad, starts, current),
            )
            await self._store.save_ranking(squad_id, ranking)
            await self._notify_promotions(squad_id, squad, previous, ranking)
        return len(squads)

    async def close_week(self) -> int:
        """Fecha a semana que acabou e abre a nova. Devolve quantos squads."""
        now = self._clock()
        last_week_moment = week_start(now) - timedelta(seconds=1)
        last_week = week_id(last_week_moment)
        squads = await self._store.list_squads()
        fetched = await self._fetch(self._puuids(squads))
        # Quem entrou sem retrato na semana passada fica com delta 0 (o elo de agora).
        starts = await self._starts(last_week, fetched, now)

        for squad_id, squad in squads:
            previous = await self._store.get_ranking(squad_id, last_week)
            ranking = WeeklyRanking(
                week_id=last_week, week_start=week_start(last_week_moment), updated_at=now, final=True,
                entries=build_entries(squad, starts, self._with_fallback(fetched, previous, squad)),
            )
            await self._store.save_ranking(squad_id, ranking)
            await self._notify_winner(squad_id, squad, ranking)

        # O elo de agora é o ponto de partida da semana nova.
        await self._store.save_snapshots(week_id(now), {
            puuid: RankSnapshot(entry=entry, taken_at=now)
            for puuid, entry in fetched.current.items() if puuid not in fetched.failed
        })
        return len(squads)

    # ---------- Riot ----------

    @staticmethod
    def _puuids(squads: list[tuple[str, Squad]]) -> list[str]:
        return sorted({m.puuid for _, squad in squads for m in squad.members.values()})

    async def _fetch(self, puuids: list[str]) -> _Fetched:
        semaphore = asyncio.Semaphore(_CONCURRENCY)
        current: dict[str, RankedEntry | None] = {}
        failed: set[str] = set()

        async def one(puuid: str) -> None:
            async with semaphore:
                try:
                    # Mesma chave de cache da busca de perfil: reaproveita.
                    raw = await self._cache.get_or_set(
                        f"ranked:{puuid}", self._s.ttl_ranked_s, lambda: self._riot.get_league_entries(puuid),
                    )
                    current[puuid] = mappers.to_ranked(raw.value).solo
                except RiotError as e:
                    logger.warning("Ranking: sem elo de %s (%s)", puuid, e)
                    failed.add(puuid)

        await asyncio.gather(*(one(p) for p in puuids))
        return _Fetched(current, failed)

    async def _starts(self, week: str, fetched: _Fetched, now: datetime) -> dict[str, RankSnapshot]:
        """Retratos do começo da semana. Quem não tem (entrou no meio da semana)
        ganha um retrato agora: começa do zero, sem contar o que fez antes."""
        puuids = list(fetched.current)
        starts = await self._store.get_snapshots(week, puuids)
        missing = {
            p: RankSnapshot(entry=fetched.current[p], taken_at=now)
            for p in puuids if p not in starts and p not in fetched.failed
        }
        if missing:
            await self._store.save_snapshots(week, missing)
            starts.update(missing)
        return starts

    @staticmethod
    def _with_fallback(
        fetched: _Fetched, previous: WeeklyRanking | None, squad: Squad,
    ) -> dict[str, RankedEntry | None]:
        """Se a Riot falhou para alguém, mantém o elo da atualização anterior
        (em vez de tirá-lo do ranking por um erro passageiro)."""
        current = dict(fetched.current)
        old = {e.uid: e.current for e in previous.entries} if previous else {}
        for uid, member in squad.members.items():
            if member.puuid in fetched.failed and uid in old:
                current[member.puuid] = old[uid]
        return current

    # ---------- Notificações ----------

    async def _notify_promotions(
        self, squad_id: str, squad: Squad, previous: WeeklyRanking | None, ranking: WeeklyRanking,
    ) -> None:
        if previous is None:
            return  # primeira atualização da semana: não há com o que comparar
        before = {e.uid: e.current for e in previous.entries}
        for entry in ranking.entries:
            old = before.get(entry.uid)
            if entry.current and old and rank_step(entry.current) > rank_step(old):
                others = [uid for uid in squad.member_uids if uid != entry.uid]
                await self._notifier.notify(
                    others,
                    title=f"{entry.riot_id.game_name} subiu de elo!",
                    body=f"{entry.riot_id.game_name}#{entry.riot_id.tag_line} agora é "
                         f"{rank_label(entry.current)} ({squad.name}).",
                    data={"type": "promotion", "uid": entry.uid, "squadId": squad_id},
                )

    async def _notify_winner(self, squad_id: str, squad: Squad, ranking: WeeklyRanking) -> None:
        top = ranking.entries[0] if ranking.entries else None
        if top is None or not top.lp_delta or top.lp_delta <= 0:
            return  # ninguém ganhou PDL: sem destaque
        await self._notifier.notify(
            squad.member_uids,
            title=f"🏆 Destaque da semana em {squad.name}",
            body=f"{top.riot_id.game_name}#{top.riot_id.tag_line} ganhou {top.lp_delta} PDL.",
            data={"type": "weekly_winner", "squadId": squad_id, "weekId": ranking.week_id},
        )
