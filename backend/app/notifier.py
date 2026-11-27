"""Notificações push (Firebase Cloud Messaging) para os aparelhos dos usuários."""

import logging
import warnings
from typing import Protocol

from fastapi.concurrency import run_in_threadpool

from app.store import Store

logger = logging.getLogger(__name__)


def is_installation_id(target: str) -> bool:
    """Installation ID (FID, a API nova do FCM) ou token de registro clássico?

    O FID tem 22 caracteres base64url; o token clássico é bem mais longo e tem
    ":" (formato "<id>:<assinatura>"). Os dois convivem enquanto houver APK
    antigo instalado.
    """
    return ":" not in target and len(target) <= 64


class Notifier(Protocol):
    async def notify(self, uids: list[str], title: str, body: str, data: dict[str, str]) -> None: ...


class FcmNotifier:
    """Manda para todos os aparelhos de cada usuário e apaga os alvos que o FCM
    diz que não existem mais (app desinstalado, token trocado). Alvo é um
    Installation ID (app novo) ou um token clássico (APK antigo)."""

    def __init__(self, store: Store, firebase_app: object) -> None:
        self._store = store
        self._app = firebase_app

    async def notify(self, uids: list[str], title: str, body: str, data: dict[str, str]) -> None:
        from firebase_admin import messaging

        tokens_by_uid = await self._store.get_fcm_tokens(uids)
        pairs = [(uid, token) for uid, tokens in tokens_by_uid.items() for token in tokens]
        if not pairs:
            return

        # A ordem das respostas segue a do envio: primeiro os tokens, depois os FIDs.
        pairs.sort(key=lambda pair: is_installation_id(pair[1]))  # estável
        tokens = [t for _, t in pairs if not is_installation_id(t)]
        fids = [t for _, t in pairs if is_installation_id(t)]
        # `tokens` está descontinuado, mas os APKs antigos ainda usam.
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", DeprecationWarning)
            message = messaging.MulticastMessage(
                tokens=tokens or None,
                fids=fids or None,
                notification=messaging.Notification(title=title, body=body),
                data=data,
                android=messaging.AndroidConfig(priority="high"),
            )
        # O SDK é síncrono (HTTP bloqueante): fora do event loop.
        batch = await run_in_threadpool(messaging.send_each_for_multicast, message, app=self._app)

        dead: dict[str, list[str]] = {}
        for (uid, token), response in zip(pairs, batch.responses, strict=True):
            if not response.success and isinstance(response.exception, messaging.UnregisteredError):
                dead.setdefault(uid, []).append(token)
        for uid, tokens in dead.items():
            await self._store.remove_fcm_tokens(uid, tokens)
        if batch.failure_count:
            logger.warning("FCM: %d de %d envios falharam", batch.failure_count, len(pairs))


class NoNotifier:
    """Sem Firebase configurado (dev local): só registra no log."""

    async def notify(self, uids: list[str], title: str, body: str, data: dict[str, str]) -> None:
        logger.info("Notificação (não enviada) para %s: %s — %s", uids, title, body)
