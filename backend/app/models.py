"""Contrato da API: o formato EXATO do JSON que o app Flutter recebe.

Tudo aqui é nosso, não da Riot. A tradução Riot → contrato fica em mappers.py.
"""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator
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
ErrorCode = Literal[
    "SUMMONER_NOT_FOUND", "RATE_LIMITED", "UPSTREAM_UNAVAILABLE",
    # Fase 3: login e squads.
    "UNAUTHENTICATED", "RIOT_ID_REQUIRED", "SQUAD_NOT_FOUND", "SQUAD_FULL", "SQUAD_LIMIT", "NOT_SQUAD_OWNER",
]


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


# ---------- Squads (fase 3) ----------
# Estes modelos são também o formato dos documentos no Firestore (camelCase),
# que o app lê direto.

class SquadMember(CamelModel):
    """Um membro, copiado (desnormalizado) dentro do squad: a tela do squad
    mostra todo mundo com UMA leitura, sem buscar cada usuário."""
    uid: str
    display_name: str | None
    riot_id: RiotId
    puuid: str
    profile_icon_url: str | None


class Squad(CamelModel):
    """Documento squads/{squadId}."""
    name: str
    invite_code: str
    owner_uid: str
    member_uids: list[str]  # para a consulta "meus squads" (array-contains) e as regras
    members: dict[str, SquadMember]  # uid → membro
    created_at: datetime
    icon: str | None = None  # chave de SQUAD_ICONS; None = inicial do nome
    description: str | None = None  # só aparece ao abrir o squad
    period: "SquadPeriod | None" = None  # None = semana de segunda a segunda
    podiums: list["Podium"] = Field(default_factory=list)  # do mais recente ao mais antigo


class UserRecord(CamelModel):
    """Documento users/{uid}."""
    display_name: str | None = None
    riot_id: RiotId | None = None
    puuid: str | None = None
    profile_icon_url: str | None = None
    squad_ids: list[str] = Field(default_factory=list)
    fcm_tokens: list[str] = Field(default_factory=list)
    trophies: list["Trophy"] = Field(default_factory=list)


class LinkRiotIdRequest(CamelModel):
    game_name: str = Field(min_length=3, max_length=16)
    tag_line: str = Field(min_length=3, max_length=5)


class LinkRiotIdResponse(CamelModel):
    riot_id: RiotId  # com a grafia oficial da Riot
    puuid: str


class CreateSquadRequest(CamelModel):
    name: str = Field(min_length=1, max_length=30)


class JoinSquadRequest(CamelModel):
    invite_code: str = Field(min_length=4, max_length=12)


# Ícones que o app sabe desenhar (o app mapeia cada chave para um desenho).
SQUAD_ICONS = (
    "shield", "trophy", "fire", "bolt", "star", "gem",
    "castle", "rocket", "paw", "medal", "target", "sparkle",
)
SquadIcon = Literal[SQUAD_ICONS]  # type: ignore[valid-type]


class SquadInfoRequest(CamelModel):
    name: str = Field(min_length=1, max_length=30)
    description: str = Field(default="", max_length=200)


class SquadIconRequest(CamelModel):
    icon: SquadIcon


class SquadRef(CamelModel):
    """Resposta de criar/entrar: o app abre o squad pelo id (e lê o resto do Firestore)."""
    id: str
    invite_code: str


class FcmTokenRequest(CamelModel):
    token: str = Field(min_length=1, max_length=4096)



# ---------- Ranking semanal (fase 3) ----------

class RankSnapshot(CamelModel):
    """O elo Solo/Duo de um jogador num momento. `entry` None = sem ranque."""
    entry: RankedEntry | None
    taken_at: datetime


PeriodLength = Literal["week", "two_weeks", "month", "custom"]


class SquadPeriod(CamelModel):
    """O período de disputa do squad, definido pelo líder."""
    length: PeriodLength
    starts_at: datetime
    ends_at: datetime
    repeat: bool  # ao acabar, começa outro igual


class SquadPeriodRequest(CamelModel):
    length: PeriodLength
    starts_at: datetime | None = None  # só no "custom"
    ends_at: datetime | None = None    # só no "custom"
    repeat: bool = True


class ScienceWin(CamelModel):
    """Vitória com uma Ciência: vale pontos extras no ranking do squad."""
    match_id: str
    played_at: datetime
    champion_name: str
    title: str
    tier: str  # "S" a "D"
    bonus: int


class RankingEntry(CamelModel):
    uid: str
    display_name: str | None
    riot_id: RiotId
    profile_icon_url: str | None
    current: RankedEntry | None  # elo agora (None = sem ranque)
    lp_delta: int | None  # PDL ganho no período (None = sem ranque no começo ou agora)
    games: int  # partidas ranqueadas Solo/Duo no período
    bonus: int = 0  # pontos extras das Ciências
    points: int | None = None  # lp_delta + bonus (None = sem ranque)
    science_wins: list[ScienceWin] = Field(default_factory=list)


class WeeklyRanking(CamelModel):
    """Documento squads/{id}/rankings/{periodId}. Do maior para o menor número de pontos."""
    period_id: str
    starts_at: datetime
    ends_at: datetime
    updated_at: datetime
    final: bool  # True quando o período acabou
    entries: list[RankingEntry]

    @model_validator(mode="before")
    @classmethod
    def _legacy_week(cls, data: object) -> object:
        """Documentos antigos (só semanas): weekId/weekStart."""
        if isinstance(data, dict) and "weekId" in data and "periodId" not in data:
            from datetime import timedelta

            data = {**data, "periodId": data["weekId"], "startsAt": data["weekStart"]}
            data.setdefault("endsAt", data["weekStart"] + timedelta(days=7))
        return data


class Podium(CamelModel):
    """Resultado de um período encerrado: até 3 uids, do 1º ao 3º."""
    period_id: str
    starts_at: datetime
    ends_at: datetime
    places: list[str]
    points: list[int]


class Trophy(CamelModel):
    """Troféu no perfil de quem ficou entre os 3 primeiros de um período."""
    squad_id: str
    squad_name: str
    period_id: str
    ends_at: datetime
    place: int  # 1 ouro, 2 prata, 3 bronze
    points: int


Squad.model_rebuild()
UserRecord.model_rebuild()
