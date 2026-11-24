"""Testes do endpoint /summoner com a Riot SIMULADA.

httpx.MockTransport intercepta as requisições: nenhuma chamada sai para a internet,
os testes não gastam rate limit e rodam no CI sem a chave da Riot.
"""

from collections import Counter
from collections.abc import Callable, Iterator

import httpx
import pytest
from fastapi.testclient import TestClient

from app.cache import TTLCache
from app.config import Settings
from app.main import app, build_service, get_summoner_service

# ---------- Respostas falsas no formato REAL da Riot ----------

ACCOUNT = {"puuid": "puuid-123", "gameName": "Fulano", "tagLine": "BR1"}
SUMMONER = {"puuid": "puuid-123", "profileIconId": 4568, "revisionDate": 0, "summonerLevel": 347}
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
    service = build_service(http, settings, cache=TTLCache(clock=clock))

    # Mesma ideia do ProviderScope(overrides: [...]) do Riverpod:
    # trocamos a dependência real por uma montada com a Riot falsa.
    app.dependency_overrides[get_summoner_service] = lambda: service
    yield TestClient(app)
    app.dependency_overrides.clear()


def get_fulano(client: TestClient, name: str = "Fulano", tag: str = "BR1") -> httpx.Response:
    return client.get(f"/summoner/{name}/{tag}")


# ---------- Testes ----------

def test_perfil_completo_no_formato_do_contrato(client: TestClient) -> None:
    response = get_fulano(client)

    assert response.status_code == 200
    body = response.json()
    assert body["riotId"] == {"gameName": "Fulano", "tagLine": "BR1"}  # camelCase
    assert body["level"] == 347
    assert body["profileIconUrl"].endswith("/cdn/16.23.1/img/profileicon/4568.png")
    assert body["ranked"]["solo"] == {"tier": "GOLD", "division": "II", "lp": 54, "wins": 40, "losses": 35}
    assert body["ranked"]["flex"] is None  # sem ranque na flex ≠ falha
    assert body["unavailable"] == []
    assert "fetchedAt" in body


def test_campeao_usa_id_de_imagem_e_nome_de_exibicao(client: TestClient) -> None:
    wukong = get_fulano(client).json()["topMasteries"][1]

    assert wukong["championName"] == "Wukong"
    assert wukong["championIconUrl"].endswith("/img/champion/MonkeyKing.png")
    assert wukong["level"] == 7


def test_riot_id_inexistente_retorna_404(client: TestClient, riot: FakeRiot) -> None:
    riot.overrides["account"] = httpx.Response(404)

    response = get_fulano(client)

    assert response.status_code == 404
    assert response.json()["code"] == "SUMMONER_NOT_FOUND"


def test_maestria_falhando_vira_sucesso_parcial(client: TestClient, riot: FakeRiot) -> None:
    riot.overrides["masteries"] = httpx.Response(500)

    response = get_fulano(client)

    assert response.status_code == 200
    body = response.json()
    assert body["topMasteries"] is None
    assert body["unavailable"] == ["masteries"]
    assert body["ranked"]["solo"]["tier"] == "GOLD"  # o resto continua lá


def test_rate_limit_repassa_retry_after(client: TestClient, riot: FakeRiot) -> None:
    riot.overrides["account"] = httpx.Response(429, headers={"Retry-After": "7"})

    response = get_fulano(client)

    assert response.status_code == 429
    assert response.headers["Retry-After"] == "7"
    assert response.json()["code"] == "RATE_LIMITED"


def test_chave_expirada_vira_503_sem_vazar_detalhes(client: TestClient, riot: FakeRiot) -> None:
    riot.overrides["account"] = httpx.Response(403)

    response = get_fulano(client)

    assert response.status_code == 503
    assert response.json()["code"] == "UPSTREAM_UNAVAILABLE"
    assert "chave" not in response.json()["message"]


def test_data_dragon_fora_do_ar_nao_derruba_o_perfil(client: TestClient, riot: FakeRiot) -> None:
    riot.overrides["versions"] = httpx.Response(503)

    body = get_fulano(client).json()

    assert body["profileIconUrl"] is None
    assert body["topMasteries"][0]["championName"] is None
    assert body["topMasteries"][0]["points"] == 245000  # o dado da Riot continua


def test_segunda_busca_usa_cache_mesmo_com_caixa_diferente(client: TestClient, riot: FakeRiot) -> None:
    get_fulano(client, "Fulano", "BR1")
    get_fulano(client, "fulano", "br1")

    assert riot.calls["account"] == 1
    assert riot.calls["league"] == 1
    assert riot.calls["champions"] == 1


@pytest.mark.parametrize(("minutes", "expected_league_calls"), [(4, 1), (6, 2)])
def test_elo_expira_depois_de_5_minutos(
    client: TestClient, riot: FakeRiot, clock: FakeClock, minutes: int, expected_league_calls: int
) -> None:
    get_fulano(client)
    clock.now += minutes * 60
    get_fulano(client)

    assert riot.calls["league"] == expected_league_calls
    assert riot.calls["account"] == 1  # o PUUID (24h) continua em cache
