"""Contrato da API: o formato EXATO do JSON que o app Flutter recebe.

Tudo aqui é nosso, não da Riot. A tradução Riot → contrato fica em mappers.py.
"""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


# Tipos reutilizáveis: equivalentes a um enum do Dart.
Tier = Literal[
    "IRON", "BRONZE", "SILVER", "GOLD", "PLATINUM", "EMERALD",
    "DIAMOND", "MASTER", "GRANDMASTER", "CHALLENGER",
]
Division = Literal["I", "II", "III", "IV"]

# Seções opcionais que podem faltar numa resposta parcial (200).
UnavailableSection = Literal["ranked", "masteries"]

# Códigos de erro estáveis: o app decide o texto a mostrar a partir do código.
ErrorCode = Literal["SUMMONER_NOT_FOUND", "RATE_LIMITED", "UPSTREAM_UNAVAILABLE"]


class CamelModel(BaseModel):
    """Base de todos os modelos do contrato: snake_case no Python, camelCase no JSON."""
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class RiotId(CamelModel):
    game_name: str
    tag_line: str


class RankedEntry(CamelModel):
    """Uma fila ranqueada (solo ou flex).

    Nomes nossos, não da Riot: `rank` → `division`, `leaguePoints` → `lp`.
    A tradução Riot → contrato acontece no proxy (camada anticorrupção).
    """
    tier: Tier
    division: Division  # MASTER+ sempre vem "I": exibir ou não é decisão do app
    lp: int = Field(ge=0)
    wins: int = Field(ge=0)
    losses: int = Field(ge=0)


class Ranked(CamelModel):
    """`None` numa fila = jogador sem ranque nela (null com sentido de negócio)."""
    solo: RankedEntry | None = None
    flex: RankedEntry | None = None


class Mastery(CamelModel):
    champion_id: int
    # None quando o Data Dragon não conhece o campeão (ex.: lançado há minutos)
    # ou está fora do ar. O app mostra um placeholder.
    champion_name: str | None
    champion_icon_url: str | None
    level: int = Field(ge=1)  # sem teto: desde 2024 a maestria passa do 7
    points: int = Field(ge=0)


class SummonerProfile(CamelModel):
    """Resposta de GET /summoner/{gameName}/{tagLine}."""
    riot_id: RiotId
    puuid: str
    level: int = Field(ge=1)
    profile_icon_url: str | None  # None se o Data Dragon estiver fora do ar
    # None aqui = a busca FALHOU (ver `unavailable`), diferente de Ranked(solo=None).
    ranked: Ranked | None
    top_masteries: list[Mastery] | None
    unavailable: list[UnavailableSection] = Field(default_factory=list)
    # Quando o elo (o dado mais volátil) foi buscado na Riot. Vem do cache,
    # então pode ser até 5 min atrás: o app mostra "atualizado há X min".
    fetched_at: datetime


# ---------- Histórico de partidas (fase 2) ----------

# Nomes nossos para as filas: o `queueId` numérico da Riot (420, 450...) não vaza para o app.
QueueType = Literal["RANKED_SOLO", "RANKED_FLEX", "NORMAL", "ARAM", "ARENA", "OTHER"]

# REMAKE: partida encerrada nos primeiros minutos (alguém não conectou). Não conta como V/D.
MatchResult = Literal["WIN", "LOSS", "REMAKE"]


class Item(CamelModel):
    item_id: int
    icon_url: str | None  # None se o Data Dragon estiver fora do ar


class MatchSummary(CamelModel):
    """Uma partida do ponto de vista de UM jogador (o dono do PUUID buscado)."""
    match_id: str  # ex.: "BR1_3307659647". Estável: o app usa para tirar duplicadas
    queue: QueueType
    result: MatchResult
    placement: int | None  # só na Arena (1º a 8º); None nos outros modos
    champion_id: int
    champion_name: str | None
    champion_icon_url: str | None
    kills: int = Field(ge=0)
    deaths: int = Field(ge=0)
    assists: int = Field(ge=0)
    cs: int = Field(ge=0)  # tropas + monstros da selva
    # Posicional, sempre 6 posições: None = espaço vazio no inventário.
    items: list[Item | None] = Field(min_length=6, max_length=6)
    trinket: Item | None  # o 7º espaço (sentinela/lente)
    duration_seconds: int = Field(ge=0)
    played_at: datetime  # quando a partida TERMINOU


class MatchPage(CamelModel):
    """Resposta de GET /matches/{puuid}?start=&count=. Partidas da mais nova para a mais antiga."""
    matches: list[MatchSummary]
    # Valor para pedir a próxima página (?start=nextStart). None = acabou o histórico.
    next_start: int | None


class ErrorResponse(CamelModel):
    """Corpo de toda resposta de erro (4xx/5xx)."""
    code: ErrorCode
    message: str  # para debug; o texto exibido ao usuário é decidido pelo app
