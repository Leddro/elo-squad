"""Notificações push (Firebase Cloud Messaging) para os aparelhos dos usuários."""

import logging
from typing import Protocol

from fastapi.concurrency import run_in_threadpool

from app.store import Store

logger = logging.getLogger(__name__)


class Notifier(Protocol):
    async def notify(self, uids: list[str], title: str, body: str, data: dict[str, str]) -> None: ...


class FcmNotifier:
    """Manda para todos os aparelhos (tokens) de cada usuário e apaga os tokens
    que o FCM diz que não existem mais (app desinstalado, token trocado)."""

    def __init__(self, store: Store, firebase_app: object) -> None:
        self._store = store
        self._app = firebase_app

    async def notify(self, uids: list[str], title: str, body: str, data: dict[str, str]) -> None:
        from firebase_admin import messaging

        tokens_by_uid = await self._store.get_fcm_tokens(uids)
        pairs = [(uid, token) for uid, tokens in tokens_by_uid.items() for token in tokens]
        if not pairs:
            return

        message = messaging.MulticastMessage(
            tokens=[token for _, token in pairs],
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
