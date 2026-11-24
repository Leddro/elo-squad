"""Cliente HTTP da API da Riot: o ÚNICO lugar que conhece URLs e a chave.

Devolve o JSON cru da Riot (dicts). Traduzir para o contrato é papel do mappers.py.
"""

from typing import Any
from urllib.parse import quote

import httpx

from app.errors import NotFoundError, RateLimitedError, UpstreamError


class RiotClient:
    def __init__(self, http: httpx.AsyncClient, api_key: str, region: str, platform: str) -> None:
        self._http = http
        self._headers = {"X-Riot-Token": api_key}
        self._region_url = f"https://{region}.api.riotgames.com"
        self._platform_url = f"https://{platform}.api.riotgames.com"

    async def get_account(self, game_name: str, tag_line: str) -> dict[str, Any]:
        # quote(): nomes podem ter espaço, acento etc. safe="" codifica até a "/".
        name, tag = quote(game_name, safe=""), quote(tag_line, safe="")
        return await self._get(f"{self._region_url}/riot/account/v1/accounts/by-riot-id/{name}/{tag}")

    async def get_summoner(self, puuid: str) -> dict[str, Any]:
        return await self._get(f"{self._platform_url}/lol/summoner/v4/summoners/by-puuid/{puuid}")

    async def get_league_entries(self, puuid: str) -> list[dict[str, Any]]:
        # Lista vazia = jogador sem ranque (não é erro).
        return await self._get(f"{self._platform_url}/lol/league/v4/entries/by-puuid/{puuid}")

    async def get_top_masteries(self, puuid: str, count: int) -> list[dict[str, Any]]:
        return await self._get(
            f"{self._platform_url}/lol/champion-mastery/v4/champion-masteries/by-puuid/{puuid}/top",
            params={"count": count},
        )

    async def _get(self, url: str, params: dict[str, Any] | None = None) -> Any:
        """Centraliza a tradução de status HTTP da Riot → exceções nossas."""
        try:
            response = await self._http.get(url, headers=self._headers, params=params)
        except httpx.HTTPError as e:  # timeout, DNS, conexão recusada...
            raise UpstreamError(f"Falha de rede ao chamar a Riot: {e!r}") from e

        status = response.status_code
        if status == 404:
            raise NotFoundError(url)
        if status == 429:
            raise RateLimitedError(retry_after=int(response.headers.get("Retry-After", "1")))
        if status in (401, 403):
            # Na prática quase sempre é a dev key que expirou (dura 24h).
            raise UpstreamError(f"Riot respondeu {status}: chave inválida ou expirada")
        if status >= 400:
            raise UpstreamError(f"Riot respondeu {status} em {url}")
        return response.json()
