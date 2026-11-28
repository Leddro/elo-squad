"""Períodos de disputa dos squads: semana, 2 semanas, mês ou datas do líder.

Funções puras (sem rede nem banco). Todas as datas em UTC; os cortes de dia
seguem o horário de Brasília.
"""

from datetime import datetime, timedelta

from app.models import PeriodLength, SquadPeriod
from app.ranking import BRT, week_id, week_start

PRESET_DAYS: dict[str, int] = {"week": 7, "two_weeks": 14}
MIN_CUSTOM = timedelta(days=1)
MAX_CUSTOM = timedelta(days=92)


def _next_midnight(moment: datetime) -> datetime:
    """A meia-noite (Brasília) seguinte a `moment` (ou ela mesma, se já for)."""
    local = moment.astimezone(BRT)
    midnight = local.replace(hour=0, minute=0, second=0, microsecond=0)
    if midnight < local:
        midnight += timedelta(days=1)
    return midnight.astimezone(moment.tzinfo)


def _add_month(moment: datetime) -> datetime:
    local = moment.astimezone(BRT)
    year, month = (local.year + 1, 1) if local.month == 12 else (local.year, local.month + 1)
    day = min(local.day, 28)  # 29–31 não existem em todo mês
    return local.replace(year=year, month=month, day=day).astimezone(moment.tzinfo)


def _end_for(length: PeriodLength, start: datetime) -> datetime:
    if length == "month":
        return _next_midnight(_add_month(start))
    return _next_midnight(start + timedelta(days=PRESET_DAYS[length]))


def default_period(now: datetime) -> SquadPeriod:
    """Squad sem período definido: a semana de segunda a segunda, repetindo."""
    start = week_start(now)
    return SquadPeriod(length="week", starts_at=start, ends_at=start + timedelta(days=7), repeat=True)


def preset_period(length: PeriodLength, now: datetime, repeat: bool) -> SquadPeriod:
    """Semana, 2 semanas ou mês, começando agora e terminando à meia-noite."""
    return SquadPeriod(length=length, starts_at=now, ends_at=_end_for(length, now), repeat=repeat)


def custom_period(starts_at: datetime, ends_at: datetime, now: datetime, repeat: bool) -> SquadPeriod:
    """Datas do líder. Começar no passado não dá: o elo daquele dia não foi guardado."""
    start = max(starts_at, now)
    if ends_at - start < MIN_CUSTOM or ends_at - start > MAX_CUSTOM:
        raise ValueError("o período precisa ter de 1 a 92 dias")
    return SquadPeriod(length="custom", starts_at=start, ends_at=ends_at, repeat=repeat)


def next_period(period: SquadPeriod) -> SquadPeriod:
    """O período seguinte, emendado no fim deste (mesma duração)."""
    start = period.ends_at
    if period.length == "custom":
        end = start + (period.ends_at - period.starts_at)
    elif period.length == "week" and period.starts_at == week_start(period.starts_at):
        end = start + timedelta(days=7)  # semana de segunda a segunda
    else:
        end = _end_for(period.length, start)
    return period.model_copy(update={"starts_at": start, "ends_at": end})


def period_id(period: SquadPeriod) -> str:
    """Id do documento do ranking (e dos retratos de elo do começo).

    A semana de segunda a segunda mantém o id antigo ("2026-W48"); os outros
    usam começo e fim, ex.: "20261127-1930_20261205".
    """
    if period.length == "week" and period.starts_at == week_start(period.starts_at) \
            and period.ends_at - period.starts_at == timedelta(days=7):
        return week_id(period.starts_at)
    start = period.starts_at.astimezone(BRT)
    end = period.ends_at.astimezone(BRT)
    return f"{start:%Y%m%d-%H%M}_{end:%Y%m%d}"
