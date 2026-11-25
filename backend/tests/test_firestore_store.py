"""FirestoreStore contra o EMULADOR do Firestore (teste de integração).

Pulado se o emulador não estiver rodando. Para rodar (dentro de firebase/):
    firebase emulators:exec --only firestore "cd ../backend && uv run python -m pytest tests/test_firestore_store.py"
"""

import asyncio
import os
from datetime import UTC, datetime

import pytest

from app.models import RiotId, Squad, SquadMember
from app.store import FirestoreStore

pytestmark = pytest.mark.skipif(
    "FIRESTORE_EMULATOR_HOST" not in os.environ, reason="emulador do Firestore não está rodando",
)


def member(uid: str) -> SquadMember:
    return SquadMember(
        uid=uid, display_name=f"Nome {uid}", riot_id=RiotId(game_name="Fulano", tag_line="BR1"),
        puuid=f"puuid-{uid}", profile_icon_url=None,
    )


async def scenario() -> None:
    from google.cloud.firestore import AsyncClient

    # "demo-": projeto de demonstração, que só existe no emulador.
    store = FirestoreStore(AsyncClient(project="demo-elo-squad"))

    await store.set_user_riot_id("a", "Nome a", RiotId(game_name="Fulano", tag_line="BR1"), "puuid-a", None)
    await store.add_fcm_token("a", "fcm-1")
    await store.add_fcm_token("a", "fcm-1")  # ArrayUnion: não duplica
    user = await store.get_user("a")
    assert user is not None and user.puuid == "puuid-a" and user.fcm_tokens == ["fcm-1"]

    squad = Squad(
        name="Os Brabos", invite_code="ABC234", owner_uid="a", member_uids=["a"],
        members={"a": member("a")}, created_at=datetime.now(UTC),
    )
    squad_id = await store.create_squad(squad)
    assert await store.invite_code_exists("ABC234")
    assert await store.squad_id_for_code("ABC234") == squad_id
    assert (await store.get_user("a")).squad_ids == [squad_id]  # type: ignore[union-attr]
    # O set com merge do create_squad não apagou o Riot ID salvo antes.
    assert (await store.get_user("a")).puuid == "puuid-a"  # type: ignore[union-attr]

    await store.add_member(squad_id, member("b"))
    saved = await store.get_squad(squad_id)
    assert saved is not None
    assert saved.member_uids == ["a", "b"]
    assert saved.members["b"].puuid == "puuid-b"
    assert (await store.get_user("b")).squad_ids == [squad_id]  # type: ignore[union-attr]

    await store.update_member(squad_id, member("b").model_copy(update={"puuid": "puuid-novo"}))
    await store.set_owner(squad_id, "b")
    await store.remove_member(squad_id, "a")
    saved = await store.get_squad(squad_id)
    assert saved is not None
    assert saved.member_uids == ["b"] and "a" not in saved.members
    assert saved.owner_uid == "b" and saved.members["b"].puuid == "puuid-novo"
    assert (await store.get_user("a")).squad_ids == []  # type: ignore[union-attr]

    await store.delete_squad(squad_id, "ABC234")
    assert await store.get_squad(squad_id) is None
    assert not await store.invite_code_exists("ABC234")


def test_firestore_store_no_emulador() -> None:
    asyncio.run(scenario())
