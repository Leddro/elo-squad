"""Login (token do Firebase), vínculo do Riot ID e squads."""

import httpx
from fastapi.testclient import TestClient

from app.squad_service import MAX_MEMBERS, MAX_SQUADS_PER_USER
from conftest import FakeRiot, auth
from fake_store import InMemoryStore


def link(client: TestClient, uid: str) -> None:
    r = client.put("/me/riot-id", json={"gameName": "fulano", "tagLine": "br1"}, headers=auth(uid))
    assert r.status_code == 200, r.text


def create(client: TestClient, uid: str, name: str = "Os Brabos") -> dict:
    r = client.post("/squads", json={"name": name}, headers=auth(uid))
    assert r.status_code == 201, r.text
    return r.json()


def join(client: TestClient, uid: str, code: str) -> httpx.Response:
    return client.post("/squads/join", json={"inviteCode": code}, headers=auth(uid))


# ---------- Autenticação ----------

def test_sem_token_401(client: TestClient) -> None:
    r = client.get("/summoner/Fulano/BR1", headers={"Authorization": ""})
    assert r.status_code == 401
    assert r.json()["code"] == "UNAUTHENTICATED"


def test_token_invalido_401_e_nao_gasta_cota_da_riot(client: TestClient, riot: FakeRiot) -> None:
    r = client.get("/summoner/Fulano/BR1", headers={"Authorization": "Bearer lixo"})
    assert r.status_code == 401
    assert sum(riot.calls.values()) == 0


def test_historico_tambem_exige_login(client: TestClient) -> None:
    r = client.get("/matches/puuid-123", headers={"Authorization": ""})
    assert r.status_code == 401


def test_health_continua_aberto(client: TestClient) -> None:
    assert client.get("/health", headers={"Authorization": ""}).status_code == 200


# ---------- Riot ID ----------

def test_vincular_riot_id_salva_a_grafia_oficial(client: TestClient, store: InMemoryStore) -> None:
    r = client.put("/me/riot-id", json={"gameName": "fulano", "tagLine": "br1"}, headers=auth("a"))

    assert r.status_code == 200
    assert r.json() == {"riotId": {"gameName": "Fulano", "tagLine": "BR1"}, "puuid": "puuid-123"}
    user = store.users["a"]
    assert user.puuid == "puuid-123"
    assert user.display_name == "Nome a"
    assert user.profile_icon_url is not None


def test_vincular_riot_id_inexistente_404(client: TestClient, riot: FakeRiot) -> None:
    riot.overrides["account"] = httpx.Response(404, json={})
    r = client.put("/me/riot-id", json={"gameName": "Ninguem", "tagLine": "BR1"}, headers=auth("a"))
    assert r.status_code == 404
    assert r.json()["code"] == "SUMMONER_NOT_FOUND"


def test_revincular_riot_id_atualiza_a_copia_nos_squads(
    client: TestClient, store: InMemoryStore, riot: FakeRiot,
) -> None:
    link(client, "a")
    ref = create(client, "a")
    riot.overrides["account"] = httpx.Response(
        200, json={"puuid": "puuid-novo", "gameName": "Novo", "tagLine": "BR2"},
    )

    client.put("/me/riot-id", json={"gameName": "Novo", "tagLine": "BR2"}, headers=auth("a"))

    member = store.squads[ref["id"]].members["a"]
    assert member.riot_id.game_name == "Novo"
    assert member.puuid == "puuid-novo"


# ---------- Squads ----------

def test_criar_squad_exige_riot_id(client: TestClient) -> None:
    r = client.post("/squads", json={"name": "Os Brabos"}, headers=auth("a"))
    assert r.status_code == 409
    assert r.json()["code"] == "RIOT_ID_REQUIRED"


def test_criar_squad(client: TestClient, store: InMemoryStore) -> None:
    link(client, "a")
    ref = create(client, "a")

    squad = store.squads[ref["id"]]
    assert squad.name == "Os Brabos"
    assert squad.owner_uid == "a"
    assert squad.member_uids == ["a"]
    assert squad.members["a"].riot_id.game_name == "Fulano"
    assert squad.members["a"].profile_icon_url is not None
    assert len(ref["inviteCode"]) == 6
    assert store.users["a"].squad_ids == [ref["id"]]


def test_entrar_pelo_codigo_ignora_maiusculas_e_espacos(client: TestClient, store: InMemoryStore) -> None:
    link(client, "a")
    link(client, "b")
    ref = create(client, "a")

    r = join(client, "b", f"  {ref['inviteCode'].lower()} ")

    assert r.status_code == 200
    assert r.json()["id"] == ref["id"]
    assert store.squads[ref["id"]].member_uids == ["a", "b"]
    assert store.users["b"].squad_ids == [ref["id"]]


def test_entrar_exige_riot_id(client: TestClient) -> None:
    link(client, "a")
    ref = create(client, "a")
    r = join(client, "b", ref["inviteCode"])
    assert r.status_code == 409
    assert r.json()["code"] == "RIOT_ID_REQUIRED"


def test_entrar_duas_vezes_nao_duplica(client: TestClient, store: InMemoryStore) -> None:
    link(client, "a")
    ref = create(client, "a")

    r = join(client, "a", ref["inviteCode"])

    assert r.status_code == 200
    assert store.squads[ref["id"]].member_uids == ["a"]


def test_codigo_invalido_404(client: TestClient) -> None:
    link(client, "b")
    r = join(client, "b", "ZZZZZZ")
    assert r.status_code == 404
    assert r.json()["code"] == "SQUAD_NOT_FOUND"


def test_squad_cheio_409(client: TestClient, store: InMemoryStore) -> None:
    link(client, "a")
    ref = create(client, "a")
    store.squads[ref["id"]].member_uids += [f"x{i}" for i in range(MAX_MEMBERS - 1)]

    link(client, "b")
    r = join(client, "b", ref["inviteCode"])
    assert r.status_code == 409
    assert r.json()["code"] == "SQUAD_FULL"


def test_limite_de_squads_por_usuario_409(client: TestClient) -> None:
    link(client, "a")
    for i in range(MAX_SQUADS_PER_USER):
        create(client, "a", f"Squad {i}")

    r = client.post("/squads", json={"name": "Mais um"}, headers=auth("a"))
    assert r.status_code == 409
    assert r.json()["code"] == "SQUAD_LIMIT"


def test_nome_vazio_422(client: TestClient) -> None:
    link(client, "a")
    r = client.post("/squads", json={"name": ""}, headers=auth("a"))
    assert r.status_code == 422


def test_sair_passa_a_lideranca_para_o_mais_antigo(client: TestClient, store: InMemoryStore) -> None:
    for uid in ("a", "b", "c"):
        link(client, uid)
    ref = create(client, "a")
    for uid in ("b", "c"):
        join(client, uid, ref["inviteCode"])

    r = client.post(f"/squads/{ref['id']}/leave", headers=auth("a"))

    assert r.status_code == 204
    squad = store.squads[ref["id"]]
    assert squad.member_uids == ["b", "c"]
    assert squad.owner_uid == "b"
    assert "a" not in squad.members
    assert store.users["a"].squad_ids == []


def test_ultimo_a_sair_apaga_o_squad_e_o_codigo(client: TestClient, store: InMemoryStore) -> None:
    link(client, "a")
    ref = create(client, "a")

    client.post(f"/squads/{ref['id']}/leave", headers=auth("a"))

    assert ref["id"] not in store.squads
    assert ref["inviteCode"] not in store.codes


def test_sair_de_squad_alheio_404(client: TestClient) -> None:
    link(client, "a")
    ref = create(client, "a")
    r = client.post(f"/squads/{ref['id']}/leave", headers=auth("intruso"))
    assert r.status_code == 404


def test_token_fcm_sem_duplicar(client: TestClient, store: InMemoryStore) -> None:
    for _ in range(2):
        r = client.post("/me/fcm-tokens", json={"token": "fcm-1"}, headers=auth("a"))
        assert r.status_code == 204
    assert store.users["a"].fcm_tokens == ["fcm-1"]


def test_token_fcm_removido_no_logout(client: TestClient, store: InMemoryStore) -> None:
    client.post("/me/fcm-tokens", json={"token": "fcm-1"}, headers=auth("a"))
    client.post("/me/fcm-tokens", json={"token": "fcm-2"}, headers=auth("a"))

    r = client.delete("/me/fcm-tokens/fcm-1", headers=auth("a"))

    assert r.status_code == 204
    assert store.users["a"].fcm_tokens == ["fcm-2"]


def test_remover_token_exige_login(client: TestClient) -> None:
    r = client.delete("/me/fcm-tokens/fcm-1", headers={"Authorization": ""})
    assert r.status_code == 401


def test_token_fcm_muda_de_conta(client: TestClient, store: InMemoryStore) -> None:
    # Mesmo aparelho, outra conta: a conta antiga deixa de receber push nele.
    client.post("/me/fcm-tokens", json={"token": "fcm-1"}, headers=auth("a"))
    client.post("/me/fcm-tokens", json={"token": "fcm-1"}, headers=auth("b"))

    assert store.users["a"].fcm_tokens == []
    assert store.users["b"].fcm_tokens == ["fcm-1"]


# ---------- Ícone ----------

def test_membro_escolhe_o_icone(client: TestClient, store: InMemoryStore) -> None:
    link(client, "a")
    ref = create(client, "a")
    r = client.put(f"/squads/{ref['id']}/icon", json={"icon": "castle"}, headers=auth("a"))
    assert r.status_code == 204
    assert store.squads[ref["id"]].icon == "castle"


def test_icone_desconhecido_422(client: TestClient) -> None:
    link(client, "a")
    ref = create(client, "a")
    r = client.put(f"/squads/{ref['id']}/icon", json={"icon": "banana"}, headers=auth("a"))
    assert r.status_code == 422


def test_icone_de_squad_alheio_404(client: TestClient) -> None:
    link(client, "a")
    ref = create(client, "a")
    r = client.put(f"/squads/{ref['id']}/icon", json={"icon": "star"}, headers=auth("b"))
    assert r.status_code == 404


# ---------- Remover membro ----------

def test_lider_remove_um_membro(client: TestClient, store: InMemoryStore) -> None:
    link(client, "a"); link(client, "b")
    ref = create(client, "a")
    join(client, "b", ref["inviteCode"])
    r = client.delete(f"/squads/{ref['id']}/members/b", headers=auth("a"))
    assert r.status_code == 204
    assert store.squads[ref["id"]].member_uids == ["a"]


def test_quem_nao_e_lider_nao_remove_403(client: TestClient) -> None:
    link(client, "a"); link(client, "b")
    ref = create(client, "a")
    join(client, "b", ref["inviteCode"])
    r = client.delete(f"/squads/{ref['id']}/members/a", headers=auth("b"))
    assert r.status_code == 403
    assert r.json()["code"] == "NOT_SQUAD_OWNER"
