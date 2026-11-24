"""Data Dragon: CDN pública da Riot com nomes e imagens (não usa a chave da API)."""

from dataclasses import dataclass
from typing import Any

import httpx

from app.cache import TTLCache
from app.errors import UpstreamError

DDRAGON_URL = "https://ddragon.leagueoflegends.com"

# A lista de campeões de uma versão nunca muda, então o TTL pode ser longo.
# A chave do cache inclui a versão: patch novo → chave nova → download novo.
_CHAMPIONS_TTL_S = 7 * 24 * 3600


@dataclass(frozen=True, slots=True)
class Champion:
    image_id: str  # usado na URL da imagem. Ex.: "MonkeyKing"
    name: str      # nome exibido.            Ex.: "Wukong"


def profile_icon_url(version: str, icon_id: int) -> str:
    return f"{DDRAGON_URL}/cdn/{version}/img/profileicon/{icon_id}.png"


def champion_icon_url(version: str, image_id: str) -> str:
    return f"{DDRAGON_URL}/cdn/{version}/img/champion/{image_id}.png"


class DataDragon:
    def __init__(self, http: httpx.AsyncClient, cache: TTLCache, language: str, version_ttl_s: int) -> None:
        self._http = http
        self._cache = cache
        self._language = language
        self._version_ttl_s = version_ttl_s

    async def latest_version(self) -> str:
        entry = await self._cache.get_or_set("ddragon:version", self._version_ttl_s, self._fetch_latest_version)
        return entry.value

    async def champions(self, version: str) -> dict[int, Champion]:
        entry = await self._cache.get_or_set(
            f"ddragon:champions:{version}:{self._language}",
            _CHAMPIONS_TTL_S,
            lambda: self._fetch_champions(version),
        )
        return entry.value

    async def _fetch_latest_version(self) -> str:
        versions = await self._get_json(f"{DDRAGON_URL}/api/versions.json")
        return versions[0]  # a lista vem da mais nova para a mais antiga

    async def _fetch_champions(self, version: str) -> dict[int, Champion]:
        data = await self._get_json(f"{DDRAGON_URL}/cdn/{version}/data/{self._language}/champion.json")
        # O JSON é indexado pelo NOME e o ID numérico vem como texto em "key":
        #   "MonkeyKing": {"id": "MonkeyKing", "key": "62", "name": "Wukong"}
        # A Riot nos manda só o número (62), então invertemos: {62: Champion(...)}.
        return {
            int(c["key"]): Champion(image_id=c["id"], name=c["name"])
            for c in data["data"].values()
        }

    async def _get_json(self, url: str) -> Any:
        try:
            response = await self._http.get(url)
            response.raise_for_status()
        except httpx.HTTPError as e:
            raise UpstreamError(f"Data Dragon indisponível: {e!r}") from e
        return response.json()
