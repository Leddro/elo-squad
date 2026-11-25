"""Riot SIMULADA, compartilhada por todos os testes (o pytest carrega este arquivo sozinho).

httpx.MockTransport intercepta as requisições: nenhuma chamada sai para a internet,
os testes não gastam rate limit e rodam no CI sem a chave da Riot.
"""

import copy
from collections import Counter
from collections.abc import Iterator
from typing import Any

import httpx
import pytest
from fastapi.testclient import TestClient

from app.auth import AuthUser, get_token_verifier
from app.cache import TTLCache
from app.config import Settings
from app.errors import UnauthenticatedError
from app.main import app, build_services, get_services
from fake_store import InMemoryStore

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

# Histórico com 25 partidas, da mais nova (BR1_1024) para a mais antiga (BR1_1000).
MATCH_IDS = [f"BR1_{1000 + i}" for i in reversed(range(25))]


def make_match(match_id: str) -> dict[str, Any]:
    """Partida no formato do match-v5 (só os campos que o proxy lê, mais alguns de enfeite)."""

    def player(puuid: str, champion_id: int, win: bool) -> dict[str, Any]:
        return {
            "puuid": puuid, "championId": champion_id, "championName": "MonkeyKing",
            "kills": 7, "deaths": 2, "assists": 9,
            "totalMinionsKilled": 150, "neutralMinionsKilled": 30,
            "item0": 3111, "item1": 0, "item2": 6676, "item3": 0, "item4": 0, "item5": 0, "item6": 3340,
            "win": win, "placement": 0, "gameEndedInEarlySurrender": False,
        }

    return {
        "metadata": {"matchId": match_id, "participants": [PUUID, "outro-puuid"]},
        "info": {
            "queueId": 420,
            "gameDuration": 1702,
            "gameEndTimestamp": 1_795_563_763_329,  # ms
            "gameVersion": "16.22.841.3489",        # patch ANTERIOR ao mais novo do Data Dragon
            "participants": [player(PUUID, 62, True), player("outro-puuid", 157, False)],
        },
    }


# Trecho da URL → nome da rota. A ORDEM importa: "by-puuid" antes do detalhe da partida.
ROUTES = {
    "/riot/account/v1/": "account",
    "/lol/summoner/v4/": "summoner",
    "/lol/league/v4/": "league",
    "/lol/champion-mastery/v4/": "masteries",
    "/lol/match/v5/matches/by-puuid/": "match_ids",
    "/lol/match/v5/matches/": "match",
    "/api/versions.json": "versions",
    "/champion.json": "champions",
}
DEFAULTS = {
    "account": ACCOUNT, "summoner": SUMMONER, "league": LEAGUE,
    "masteries": MASTERIES, "versions": VERSIONS, "champions": CHAMPIONS,
}


class FakeRiot:
    """Responde como a Riot.

    - `overrides` troca a resposta de uma rota inteira (ex.: forçar 500 no league).
    - `matches` tem o JSON de cada partida: o teste pode editar (ex.: mudar a fila).
    - `match_overrides` troca a resposta de UMA partida (ex.: 429 só na BR1_1023).
    """

    def __init__(self) -> None:
        self.calls: Counter[str] = Counter()
        self.overrides: dict[str, httpx.Response] = {}
        self.matches: dict[str, dict[str, Any]] = {mid: make_match(mid) for mid in MATCH_IDS}
        self.match_overrides: dict[str, httpx.Response] = {}
        # Elo por PUUID (league-v4). Quem não estiver aqui recebe o LEAGUE padrão.
        self.league: dict[str, list[dict[str, Any]] | httpx.Response] = {}

    def __call__(self, request: httpx.Request) -> httpx.Response:
        route = next(name for part, name in ROUTES.items() if part in request.url.path)
        self.calls[route] += 1
        if route in self.overrides:
            return self.overrides[route]
        if route == "league":
            puuid = request.url.path.rsplit("/", 1)[-1]
            if puuid in self.league:
                league = self.league[puuid]
                return league if isinstance(league, httpx.Response) else httpx.Response(200, json=league)
        if route == "match_ids":
            start, count = int(request.url.params["start"]), int(request.url.params["count"])
            return httpx.Response(200, json=MATCH_IDS[start:start + count])
        if route == "match":
            match_id = request.url.path.rsplit("/", 1)[-1]
            if match_id in self.match_overrides:
                return self.match_overrides[match_id]
            return httpx.Response(200, json=copy.deepcopy(self.matches[match_id]))
        return httpx.Response(200, json=DEFAULTS[route])


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


def fake_verifier(token: str) -> AuthUser:
    """Firebase FALSO: o token "token-<uid>" vale para o usuário <uid>."""
    if not token.startswith("token-"):
        raise UnauthenticatedError("token inválido")
    uid = token.removeprefix("token-")
    return AuthUser(uid=uid, name=f"Nome {uid}")


def auth(uid: str) -> dict[str, str]:
    """Cabeçalho de login para o usuário `uid` (ver fake_verifier)."""
    return {"Authorization": f"Bearer token-{uid}"}


@pytest.fixture
def store() -> InMemoryStore:
    return InMemoryStore()


@pytest.fixture
def client(riot: FakeRiot, clock: FakeClock, store: InMemoryStore) -> Iterator[TestClient]:
    # _env_file=None: o teste NÃO lê o backend/.env (roda igual no CI, sem chave).
    settings = Settings(riot_api_key="chave-de-teste", _env_file=None)  # type: ignore[call-arg]
    http = httpx.AsyncClient(transport=httpx.MockTransport(riot))
    services = build_services(http, settings, store, cache=TTLCache(clock=clock))

    # Mesma ideia do ProviderScope(overrides: [...]) do Riverpod:
    # trocamos as dependências reais (Riot, Firestore, Firebase Auth) por falsas.
    app.dependency_overrides[get_services] = lambda: services
    app.dependency_overrides[get_token_verifier] = lambda: fake_verifier
    # Por padrão, toda requisição vai logada como "uid-1".
    yield TestClient(app, headers=auth("uid-1"))
    app.dependency_overrides.clear()
