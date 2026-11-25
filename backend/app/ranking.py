"""Cálculos do ranking semanal: semana atual, PDL absoluto e ordem do ranking.

Funções puras (sem rede nem banco): fáceis de testar.
"""

from datetime import datetime, timedelta, timezone

from app.models import RankedEntry

# Horário de Brasília. Sem horário de verão desde 2019, então um fuso FIXO
# basta (e evita depender do pacote tzdata no Windows).
BRT = timezone(timedelta(hours=-3), "BRT")

# Ordem dos tiers com divisão. Cada tier vale 400 PDL (4 divisões x 100).
_TIERS_WITH_DIVISIONS = ["IRON", "BRONZE", "SILVER", "GOLD", "PLATINUM", "EMERALD", "DIAMOND"]
_DIVISION_OFFSET = {"IV": 0, "III": 100, "II": 200, "I": 300}
# Mestre, Grão-Mestre e Desafiante: uma escada só de PDL, logo depois do Diamante I.
_APEX_BASE = len(_TIERS_WITH_DIVISIONS) * 400  # 2800


def week_start(now: datetime) -> datetime:
    """Segunda-feira 00:00 (Brasília) da semana de `now`, em UTC."""
    local = now.astimezone(BRT)
    monday = (local - timedelta(days=local.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
    return monday.astimezone(timezone.utc)


def week_id(now: datetime) -> str:
    """Identificador da semana, ex.: "2026-W48" (semana ISO, no horário de Brasília)."""
    year, week, _ = week_start(now).astimezone(BRT).isocalendar()
    return f"{year}-W{week:02d}"


def absolute_lp(entry: RankedEntry) -> int:
    """Elo numa escala contínua, para subtrair começo e fim da semana.

    Ferro IV 0 PDL = 0; Ouro II 54 PDL = 3*400 + 200 + 54 = 1454;
    Mestre 120 PDL = 2800 + 120. Assim, subir de tier soma o que deve somar.
    """
    if entry.tier in _TIERS_WITH_DIVISIONS:
        return _TIERS_WITH_DIVISIONS.index(entry.tier) * 400 + _DIVISION_OFFSET[entry.division] + entry.lp
    return _APEX_BASE + entry.lp


_APEX_ORDER = ["MASTER", "GRANDMASTER", "CHALLENGER"]


def rank_step(entry: RankedEntry) -> int:
    """Só o degrau (tier + divisão), sem o PDL: serve para detectar promoções.

    Mestre+ não tem divisão, e o PDL é uma escada só; o degrau é o próprio tier.
    """
    if entry.tier in _TIERS_WITH_DIVISIONS:
        return absolute_lp(entry) - entry.lp
    return _APEX_BASE + _APEX_ORDER.index(entry.tier)
