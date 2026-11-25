"""Testes do endpoint /summoner com a Riot SIMULADA (ver conftest.py)."""

import httpx
import pytest
from fastapi.testclient import TestClient

from conftest import FakeClock, FakeRiot


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
