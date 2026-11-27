"""Riot para a coleta: várias regiões, respeitando o limite de cada uma.

O limite da chave vale POR ROTA (cada plataforma e cada região tem o seu):
20 pedidos/s e 100 a cada 2 min. O RateLimiter espera antes de passar disso,
e um 429 (excedeu mesmo assim) espera o Retry-After e tenta de novo.
"""

import asyncio
import logging
import time
from collections import deque
from collections.abc import Awaitable, Callable
from typing import Any
from urllib.parse import quote

import httpx

from app.errors import NotFoundError, UpstreamError

logger = logging.getLogger(__name__)

# Plataforma (ranque, maestria) → região (partidas).
PLATFORMS: dict[str, str] = {
    "br1": "americas", "na1": "americas", "la1": "americas", "la2": "americas",
    "euw1": "europe", "eun1": "europe",
    "kr": "asia", "jp1": "asia",
    "oc1": "sea", "sg2": "sea", "tw2": "sea", "vn2": "sea",
}
LIMITS = ((20, 1.0), (100, 120.0))  # (pedidos, janela em s) da chave de desenvolvimento
MAX_RETRIES = 3


class KeyRejectedError(UpstreamError):
    """401/403: a chave venceu (dev key dura 24 h). Não adianta continuar."""


class BadRequestError(UpstreamError):
    """400: na prática, um PUUID gerado por outra chave (não dá para decifrar)."""


class RateLimiter:
    def __init__(
        self,
        limits: tuple[tuple[int, float], ...] = LIMITS,
        clock: Callable[[], float] = time.monotonic,
        sleep: Callable[[float], Awaitable[None]] = asyncio.sleep,
    ) -> None:
        self._limits = limits
        self._clock = clock
        self._sleep = sleep
        self._sent: deque[float] = deque()
        self._lock = asyncio.Lock()

    async def acquire(self) -> None:
        async with self._lock:
            while True:
                now = self._clock()
                longest = max(w for _, w in self._limits)
                while self._sent and now - self._sent[0] >= longest:
                    self._sent.popleft()
                wait = 0.0
                for count, window in self._limits:
                    recent = [t for t in self._sent if now - t < window]
                    if len(recent) >= count:
                        wait = max(wait, recent[-count] + window - now)
                if wait <= 0:
                    self._sent.append(now)
                    return
                await self._sleep(wait + 0.05)


class ScienceRiot:
    def __init__(
        self,
        http: httpx.AsyncClient,
        api_key: str,
        sleep: Callable[[float], Awaitable[None]] = asyncio.sleep,
        limiter_factory: Callable[[], RateLimiter] | None = None,
    ) -> None:
        self._http = http
        self._headers = {"X-Riot-Token": api_key}
        self._sleep = sleep
        self._limiter_factory = limiter_factory or (lambda: RateLimiter(sleep=sleep))
        self._limiters: dict[str, RateLimiter] = {}
        self.calls = 0
        self.throttled = 0

    async def apex_puuids(self, platform: str) -> list[str]:
        """Desafiante + Grão-Mestre da Solo/Duo, do maior PDL para o menor."""
        entries: list[dict[str, Any]] = []
        for tier in ("challengerleagues", "grandmasterleagues"):
            data = await self._get(platform, f"/lol/league/v4/{tier}/by-queue/RANKED_SOLO_5x5")
            entries += data.get("entries", [])
        entries.sort(key=lambda e: e.get("leaguePoints", 0), reverse=True)
        return [e["puuid"] for e in entries if e.get("puuid")]

    async def top_masteries(self, platform: str, puuid: str, count: int = 2) -> list[dict[str, Any]]:
        return await self._get(
            platform, f"/lol/champion-mastery/v4/champion-masteries/by-puuid/{puuid}/top", {"count": count},
        )

    async def ranked_match_ids(self, region: str, puuid: str, start_time: int, count: int) -> list[str]:
        return await self._get(
            region, f"/lol/match/v5/matches/by-puuid/{puuid}/ids",
            {"queue": 420, "type": "ranked", "startTime": start_time, "count": count},
        )

    async def match(self, region: str, match_id: str) -> dict[str, Any]:
        return await self._get(region, f"/lol/match/v5/matches/{quote(match_id, safe='')}")

    async def timeline(self, region: str, match_id: str) -> dict[str, Any]:
        return await self._get(region, f"/lol/match/v5/matches/{quote(match_id, safe='')}/timeline")

    async def _get(self, route: str, path: str, params: dict[str, Any] | None = None) -> Any:
        limiter = self._limiters.setdefault(route, self._limiter_factory())
        for _ in range(MAX_RETRIES + 1):
            await limiter.acquire()
            self.calls += 1
            try:
                response = await self._http.get(
                    f"https://{route}.api.riotgames.com{path}", headers=self._headers, params=params,
                )
            except httpx.HTTPError as e:
                raise UpstreamError(f"Falha de rede ao chamar a Riot: {e!r}") from e
            status = response.status_code
            if status == 429:
                retry = float(response.headers.get("Retry-After", "5"))
                self.throttled += 1
                logger.warning("429 em %s (%s): esperando %.0f s", route, response.headers.get("X-Rate-Limit-Type"), retry)
                await self._sleep(retry)
                continue
            if status in (401, 403):
                raise KeyRejectedError(f"Riot respondeu {status}: chave inválida ou expirada")
            if status == 404:
                raise NotFoundError(path)
            if status == 400:
                raise BadRequestError(f"Riot respondeu 400 em {path}")
            if status >= 500:
                await self._sleep(2)
                continue
            if status >= 400:
                raise UpstreamError(f"Riot respondeu {status} em {path}")
            return response.json()
        raise UpstreamError(f"Riot não respondeu após {MAX_RETRIES} tentativas: {path}")
