"""Testes do endpoint /matches com a Riot SIMULADA (ver conftest.py)."""

from typing import Any

import httpx
import pytest
from fastapi.testclient import TestClient

from conftest import PUUID, FakeClock, FakeRiot


def get_page(client: TestClient, start: int = 0, count: int = 10) -> httpx.Response:
    return client.get(f"/matches/{PUUID}", params={"start": start, "count": count})


def test_pagina_no_formato_do_contrato(client: TestClient) -> None:
    response = get_page(client, count=2)

    assert response.status_code == 200
    body = response.json()
    assert [m["matchId"] for m in body["matches"]] == ["BR1_1024", "BR1_1023"]  # mais nova primeiro
    assert body["nextStart"] == 2

    match = body["matches"][0]
    assert match["queue"] == "RANKED_SOLO"
    assert match["result"] == "WIN"
    assert match["placement"] is None
    assert match["championName"] == "Wukong"  # resolvido pelo ID, não pelo "MonkeyKing" da Riot
    assert match["championIconUrl"].endswith("/cdn/16.23.1/img/champion/MonkeyKing.png")
    assert (match["kills"], match["deaths"], match["assists"]) == (7, 2, 9)
    assert match["cs"] == 180  # 150 tropas + 30 monstros
    assert match["durationSeconds"] == 1702
    assert match["playedAt"].startswith("2026-11-24")


def test_itens_sao_posicionais_e_usam_a_imagem_do_patch_da_partida(client: TestClient) -> None:
    match = get_page(client, count=1).json()["matches"][0]

    assert [i and i["itemId"] for i in match["items"]] == [3111, None, 6676, None, None, None]
    # Partida do 16.22: a imagem vem do 16.22.1, mesmo existindo o 16.23.1.
    assert match["items"][0]["iconUrl"].endswith("/cdn/16.22.1/img/item/3111.png")
    assert match["trinket"]["itemId"] == 3340


def test_ultima_pagina_tem_next_start_nulo(client: TestClient) -> None:
    body = get_page(client, start=20, count=10).json()

    assert len(body["matches"]) == 5  # só existem 25 partidas
    assert body["nextStart"] is None


@pytest.mark.parametrize(
    ("queue_id", "placement", "expected_queue", "expected_placement"),
    [
        (420, 0, "RANKED_SOLO", None),
        (440, 0, "RANKED_FLEX", None),
        (490, 0, "NORMAL", None),
        (450, 0, "ARAM", None),
        (1700, 3, "ARENA", 3),
        (9999, 0, "OTHER", None),  # fila nova que ainda não conhecemos: não quebra
    ],
)
def test_fila_vira_nome_nosso(
    client: TestClient, riot: FakeRiot,
    queue_id: int, placement: int, expected_queue: str, expected_placement: int | None,
) -> None:
    raw: dict[str, Any] = riot.matches["BR1_1024"]
    raw["info"]["queueId"] = queue_id
    raw["info"]["participants"][0]["placement"] = placement

    match = get_page(client, count=1).json()["matches"][0]

    assert match["queue"] == expected_queue
    assert match["placement"] == expected_placement


def test_remake_nao_conta_como_vitoria_nem_derrota(client: TestClient, riot: FakeRiot) -> None:
    for player in riot.matches["BR1_1024"]["info"]["participants"]:
        player["gameEndedInEarlySurrender"] = True

    assert get_page(client, count=1).json()["matches"][0]["result"] == "REMAKE"


def test_partidas_ja_vistas_nao_gastam_rate_limit(
    client: TestClient, riot: FakeRiot, clock: FakeClock
) -> None:
    get_page(client, count=3)
    clock.now += 3 * 60  # a LISTA de IDs expirou (2 min)...
    get_page(client, count=3)

    assert riot.calls["match_ids"] == 2
    assert riot.calls["match"] == 3  # ...mas os detalhes não mudam: continuam no cache


def test_rate_limit_numa_partida_falha_a_pagina_e_o_retry_so_busca_o_que_faltou(
    client: TestClient, riot: FakeRiot
) -> None:
    riot.match_overrides["BR1_1023"] = httpx.Response(429, headers={"Retry-After": "3"})

    response = get_page(client, count=3)

    assert response.status_code == 429
    assert response.headers["Retry-After"] == "3"
    assert response.json()["code"] == "RATE_LIMITED"

    riot.match_overrides.clear()
    retry = get_page(client, count=3)

    assert retry.status_code == 200
    assert len(retry.json()["matches"]) == 3
    assert riot.calls["match"] == 4  # 3 na 1ª tentativa + só a que faltou


def test_partida_removida_e_pulada_sem_virar_jogador_nao_encontrado(
    client: TestClient, riot: FakeRiot
) -> None:
    riot.match_overrides["BR1_1023"] = httpx.Response(404)

    body = get_page(client, count=3).json()

    assert [m["matchId"] for m in body["matches"]] == ["BR1_1024", "BR1_1022"]
    assert body["nextStart"] == 3  # a paginação segue a lista de IDs, não as partidas devolvidas


def test_data_dragon_fora_do_ar_mantem_os_dados_da_partida(client: TestClient, riot: FakeRiot) -> None:
    riot.overrides["versions"] = httpx.Response(503)

    match = get_page(client, count=1).json()["matches"][0]

    assert match["championName"] is None
    assert match["items"][0] == {"itemId": 3111, "iconUrl": None}
    assert match["kills"] == 7


def test_perfil_e_historico_compartilham_o_data_dragon(client: TestClient, riot: FakeRiot) -> None:
    client.get("/summoner/Fulano/BR1")
    get_page(client, count=2)

    assert riot.calls["versions"] == 1
    assert riot.calls["champions"] == 1


@pytest.mark.parametrize("count", [0, 21])
def test_count_fora_do_limite_e_rejeitado_sem_chamar_a_riot(
    client: TestClient, riot: FakeRiot, count: int
) -> None:
    response = get_page(client, count=count)

    assert response.status_code == 422  # validação do FastAPI (Query ge/le)
    assert riot.calls.total() == 0
