"""Envio de push: Installation IDs (app novo) e tokens clássicos (APK antigo)."""

from types import SimpleNamespace

import pytest
from firebase_admin import messaging

from app.notifier import FcmNotifier, is_installation_id
from fake_store import InMemoryStore

FID = "cXk9Qz1vT2pLbW5vcHFyc3"
TOKEN = "dGVzdGU:APA91b" + "x" * 140


def test_distingue_fid_de_token() -> None:
    assert is_installation_id(FID)
    assert not is_installation_id(TOKEN)


@pytest.mark.anyio
async def test_envia_para_fids_e_tokens_e_apaga_os_mortos(monkeypatch: pytest.MonkeyPatch) -> None:
    store = InMemoryStore()
    await store.add_fcm_token("a", FID)
    await store.add_fcm_token("b", TOKEN)
    sent: list[messaging.MulticastMessage] = []

    def fake_send(message: messaging.MulticastMessage, app: object) -> SimpleNamespace:
        sent.append(message)
        # Ordem das respostas: tokens primeiro, depois FIDs. O token morreu.
        dead = SimpleNamespace(success=False, exception=messaging.UnregisteredError("x"))
        ok = SimpleNamespace(success=True, exception=None)
        return SimpleNamespace(responses=[dead, ok], failure_count=1)

    monkeypatch.setattr(messaging, "send_each_for_multicast", fake_send)

    await FcmNotifier(store, object()).notify(["a", "b"], "t", "c", {})

    [message] = sent
    assert message.tokens == [TOKEN]
    assert message.fids == [FID]
    assert await store.get_fcm_tokens(["a", "b"]) == {"a": [FID]}
