"""Riot SIMULADA, compartilhada por todos os testes (o pytest carrega este arquivo sozinho).

httpx.MockTransport intercepta as requisições: nenhuma chamada sai para a internet,
os testes não gastam rate limit e rodam no CI sem a chave da Riot.
"""

from collections import Counter
from collections.abc import Iterator

import httpx
import pytest
from fastapi.testclient import TestClient

from app.cache import TTLCache
from app.config import Settings
from app.main import app, build_services, get_services

# ---------- Respostas falsas no formato REAL da Riot ----------

PUUID = "puuid-123"
ACCOUNT = {"puuid": PUUID, "gameName": "Fulano", "tagLine": "BR1"}
SUMMONER = {"puuid": PUUID, "profileIconId": 4568, "revisionDate": 0, "summonerLevel": 347}
LEAGUE = [
    {"queueType": "RANKED_SOLO_5x5", "tier": "GOLD", "rank": "II",
     "leaguePoints": 54, "wins": 40, "losses": 35},
]
MASTERIES = [
    {"championId": 157, "championLevel": 12, "championPoints": 245000},
    {"championId": 62, "championLevel": 7, "championPoints": 98000},
]
VERSIONS = ["16.23.1", "16.22.1"]
CHAMPIONS = {"data": {
    "Yasuo": {"id": "Yasuo", "key": "157", "name": "Yasuo"},
    "MonkeyKing": {"id": "MonkeyKing", "key": "62", "name": "Wukong"},
}}

# Trecho da URL → nome da rota (para contar chamadas e sobrescrever respostas).
ROUTES = {
    "/riot/account/v1/": "account",
    "/lol/summoner/v4/": "summoner",
    "/lol/league/v4/": "league",
    "/lol/champion-mastery/v4/": "masteries",
    "/api/versions.json": "versions",
    "/champion.json": "champions",
}
DEFAULTS = {
    "account": ACCOUNT, "summoner": SUMMONER, "league": LEAGUE,
    "masteries": MASTERIES, "versions": VERSIONS, "champions": CHAMPIONS,
}


class FakeRiot:
    """Responde como a Riot. `overrides` troca a resposta de uma rota (ex.: forçar 500)."""

    def __init__(self) -> None:
        self.calls: Counter[str] = Counter()
        self.overrides: dict[str, httpx.Response] = {}

    def __call__(self, request: httpx.Request) -> httpx.Response:
        route = next(name for part, name in ROUTES.items() if part in request.url.path)
        self.calls[route] += 1
        return self.overrides.get(route) or httpx.Response(200, json=DEFAULTS[route])


class FakeClock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now


@pytest.fixture
def riot() -> FakeRiot:
    return FakeRiot()


@pytest.fixture
def clock() -> FakeClock:
    return FakeClock()


@pytest.fixture
def client(riot: FakeRiot, clock: FakeClock) -> Iterator[TestClient]:
    # _env_file=None: o teste NÃO lê o backend/.env (roda igual no CI, sem chave).
    settings = Settings(riot_api_key="chave-de-teste", _env_file=None)  # type: ignore[call-arg]
    http = httpx.AsyncClient(transport=httpx.MockTransport(riot))
    services = build_services(http, settings, cache=TTLCache(clock=clock))

    # Mesma ideia do ProviderScope(overrides: [...]) do Riverpod:
    # trocamos a dependência real por uma montada com a Riot falsa.
    app.dependency_overrides[get_services] = lambda: services
    yield TestClient(app)
    app.dependency_overrides.clear()
