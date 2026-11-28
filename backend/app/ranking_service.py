"""Ranking de cada squad no período definido pelo líder (semana por padrão).

Pontos = PDL ganho na Solo/Duo + bônus das vitórias com Ciências.

Rodado por uma tarefa agendada (a cada hora, POST /jobs/refresh-rankings):
atualiza o período em andamento, avisa promoções e, quando o período acaba,
fecha o resultado, dá os troféus do pódio e começa o próximo (se repetir).
"""

import asyncio
import logging
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime

from app import mappers
from app.auth import AuthUser
from app.cache import TTLCache
from app.config import Settings
from app.errors import NotSquadOwnerError, RiotError, SquadNotFoundError
from app.models import (
    Podium, RankedEntry, RankingEntry, RankSnapshot, ScienceWin, Squad, SquadPeriod, SquadPeriodRequest, Trophy,
    WeeklyRanking,
)
from app.notifier import Notifier
from app.periods import custom_period, default_period, next_period, period_id, preset_period
from app.ranking import absolute_lp, rank_step
from app.riot_client import RiotClient
from app.store import Store

logger = logging.getLogger(__name__)

# Chamadas simultâneas à Riot (dev key: 20 por segundo).
_CONCURRENCY = 5
PODIUM_SIZE = 3

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
    wins: dict[str, list[ScienceWin]] | None = None,
    period: SquadPeriod | None = None,
) -> list[RankingEntry]:
    """Monta e ORDENA o ranking: mais pontos primeiro; sem ranque por último.

    Vitória com Ciência só conta dentro do período e depois do retrato de
    quem entrou no meio dele.
    """
    entries = []
    for uid in squad.member_uids:
        member = squad.members[uid]
        now = current.get(member.puuid)
        snapshot = starts.get(member.puuid)
        start = snapshot.entry if snapshot else None
        both = now is not None and start is not None
        lp_delta = absolute_lp(now) - absolute_lp(start) if both else None  # type: ignore[arg-type]
        counted = sorted(
            (w for w in (wins or {}).get(member.puuid, [])
             if snapshot is not None and w.played_at >= snapshot.taken_at
             and (period is None or period.starts_at <= w.played_at < period.ends_at)),
            key=lambda w: w.played_at,
        )
        bonus = sum(w.bonus for w in counted)
        entries.append(RankingEntry(
            uid=uid, display_name=member.display_name, riot_id=member.riot_id,
            profile_icon_url=member.profile_icon_url, current=now, lp_delta=lp_delta,
            games=(now.wins + now.losses) - (start.wins + start.losses) if both else 0,  # type: ignore[union-attr]
            bonus=bonus, points=lp_delta + bonus if lp_delta is not None else None, science_wins=counted,
        ))
    return sorted(entries, key=lambda e: (e.points is None, -(e.points or 0), e.riot_id.game_name.casefold()))


def podium_of(ranking: WeeklyRanking) -> list[RankingEntry]:
    """Até 3 primeiros, só quem terminou com pontos positivos."""
    return [e for e in ranking.entries if e.points and e.points > 0][:PODIUM_SIZE]


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

    async def refresh(self, only: str | None = None) -> int:
        """Atualiza o ranking de todos os squads (ou só de `only`). Devolve quantos.

        Pode rodar de novo sem estragos (a tarefa agendada tenta outra vez se
        a resposta não chegar): período já fechado é pulado, e o retrato do
        começo não é sobrescrito.
        """
        now = self._clock()
        squads = [(sid, sq) for sid, sq in await self._store.list_squads() if only in (None, sid)]
        puuids = self._puuids(squads)
        fetched = await self._fetch(puuids)
        wins = await self._store.get_science_wins(puuids)

        for squad_id, squad in squads:
            period = squad.period
            if period is None:
                period = default_period(now)
                await self._store.save_period(squad_id, period)
            while now >= period.ends_at:
                await self._close(squad_id, squad, period, fetched, wins, now)
                if not period.repeat:
                    break
                period = next_period(period)
                await self._store.save_period(squad_id, period)
            if now >= period.ends_at or now < period.starts_at:
                continue  # acabou sem repetir, ou ainda não começou

            pid = period_id(period)
            starts = await self._starts(pid, squad, fetched, now)
            previous = await self._store.get_ranking(squad_id, pid)
            ranking = WeeklyRanking(
                period_id=pid, starts_at=period.starts_at, ends_at=period.ends_at, updated_at=now, final=False,
                entries=build_entries(squad, starts, self._with_fallback(fetched, previous, squad), wins, period),
            )
            await self._store.save_ranking(squad_id, ranking)
            await self._notify_promotions(squad_id, squad, previous, ranking)
        return len(squads)

    async def close_week(self) -> int:
        """Compatibilidade com a tarefa antiga: o fechamento agora é no refresh."""
        return await self.refresh()

    async def set_period(self, user: AuthUser, squad_id: str, request: SquadPeriodRequest) -> SquadPeriod:
        """O líder define o período. O período em andamento acaba SEM troféus."""
        squad = await self._store.get_squad(squad_id)
        if squad is None or user.uid not in squad.member_uids:
            raise SquadNotFoundError()
        if squad.owner_uid != user.uid:
            raise NotSquadOwnerError()
        now = self._clock()
        if request.length == "custom":
            if request.starts_at is None or request.ends_at is None:
                raise ValueError("informe o começo e o fim")
            period = custom_period(request.starts_at, request.ends_at, now, request.repeat)
        else:
            period = preset_period(request.length, now, request.repeat)

        old = squad.period
        if old is not None and old.starts_at <= now < old.ends_at and period_id(old) != period_id(period):
            previous = await self._store.get_ranking(squad_id, period_id(old))
            if previous is not None and not previous.final:
                await self._store.delete_ranking(squad_id, period_id(old))
        await self._store.save_period(squad_id, period)
        await self.refresh(only=squad_id)
        return period

    async def _close(
        self, squad_id: str, squad: Squad, period: SquadPeriod, fetched: _Fetched,
        wins: dict[str, list[ScienceWin]], now: datetime,
    ) -> None:
        pid = period_id(period)
        previous = await self._store.get_ranking(squad_id, pid)
        if previous is not None and previous.final:
            return  # já fechado (e o pódio já dado)
        # Quem entrou sem retrato fica com delta 0 (o elo de agora).
        starts = await self._starts(pid, squad, fetched, now)
        ranking = WeeklyRanking(
            period_id=pid, starts_at=period.starts_at, ends_at=period.ends_at, updated_at=now, final=True,
            entries=build_entries(squad, starts, self._with_fallback(fetched, previous, squad), wins, period),
        )
        await self._store.save_ranking(squad_id, ranking)
        top = podium_of(ranking)
        if top:
            await self._store.add_podium(
                squad_id,
                Podium(period_id=pid, starts_at=period.starts_at, ends_at=period.ends_at,
                       places=[e.uid for e in top], points=[e.points or 0 for e in top]),
                {e.uid: Trophy(squad_id=squad_id, squad_name=squad.name, period_id=pid, ends_at=period.ends_at,
                               place=i + 1, points=e.points or 0) for i, e in enumerate(top)},
            )
        await self._notify_winner(squad_id, squad, ranking)

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

    async def _starts(self, pid: str, squad: Squad, fetched: _Fetched, now: datetime) -> dict[str, RankSnapshot]:
        """Retratos do começo do período. Quem não tem (entrou no meio) ganha
        um retrato agora: começa do zero, sem contar o que fez antes."""
        puuids = [m.puuid for m in squad.members.values() if m.puuid in fetched.current]
        starts = await self._store.get_snapshots(pid, puuids)
        missing = {
            p: RankSnapshot(entry=fetched.current[p], taken_at=now)
            for p in puuids if p not in starts and p not in fetched.failed
        }
        if missing:
            await self._store.save_snapshots(pid, missing)
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
            return  # primeira atualização do período: não há com o que comparar
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
        top = podium_of(ranking)
        if not top:
            return  # ninguém fez pontos: sem campeão
        winner = top[0]
        science = f" ({winner.bonus} das Ciências)" if winner.bonus else ""
        await self._notifier.notify(
            squad.member_uids,
            title=f"🏆 Campeão do período em {squad.name}",
            body=f"{winner.riot_id.game_name}#{winner.riot_id.tag_line} venceu com {winner.points} pontos{science}.",
            data={"type": "weekly_winner", "squadId": squad_id, "periodId": ranking.period_id},
        )
