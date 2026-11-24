"""Orquestração (o "BFF" de fato): junta 4 chamadas da Riot numa resposta só."""

import asyncio
import logging
from typing import Any

from app import mappers
from app.cache import CacheEntry, TTLCache
from app.config import Settings
from app.ddragon import Champion, DataDragon, profile_icon_url
from app.errors import RiotError
from app.models import SummonerProfile, UnavailableSection
from app.riot_client import RiotClient

logger = logging.getLogger(__name__)


class SummonerService:
    def __init__(self, riot: RiotClient, ddragon: DataDragon, cache: TTLCache, settings: Settings) -> None:
        self._riot = riot
        self._ddragon = ddragon
        self._cache = cache
        self._s = settings

    async def get_profile(self, game_name: str, tag_line: str) -> SummonerProfile:
        # 1) Riot ID → PUUID. Precisa vir ANTES: todo o resto depende do PUUID.
        #    casefold(): "Fulano#BR1" e "fulano#br1" são a mesma conta → mesma chave de cache.
        account = await self._cache.get_or_set(
            f"account:{game_name.casefold()}#{tag_line.casefold()}",
            self._s.ttl_account_s,
            lambda: self._riot.get_account(game_name, tag_line),
        )
        puuid: str = account.value["puuid"]

        # 2) O resto não depende entre si → em PARALELO.
        #    return_exceptions=True: uma falha não cancela as outras; ela volta como
        #    valor e decidimos abaixo o que é essencial e o que vira resposta parcial.
        summoner, ranked, masteries, ddragon = await asyncio.gather(
            self._cache.get_or_set(f"summoner:{puuid}", self._s.ttl_summoner_s,
                                   lambda: self._riot.get_summoner(puuid)),
            self._cache.get_or_set(f"ranked:{puuid}", self._s.ttl_ranked_s,
                                   lambda: self._riot.get_league_entries(puuid)),
            self._cache.get_or_set(f"masteries:{puuid}", self._s.ttl_masteries_s,
                                   lambda: self._riot.get_top_masteries(puuid, self._s.top_masteries_count)),
            self._load_ddragon(),
            return_exceptions=True,
        )

        # 3) Summoner é ESSENCIAL: sem ele não há perfil → a exceção sobe e vira 404/429/503.
        if isinstance(summoner, BaseException):
            raise summoner
        if isinstance(ddragon, BaseException):  # _load_ddragon já trata RiotError; aqui só bug
            raise ddragon
        version, champions = ddragon

        # 4) Ranked e masteries são OPCIONAIS: falha da Riot → null + aviso em `unavailable`.
        unavailable: list[UnavailableSection] = []
        ranked_raw = self._optional(ranked, "ranked", unavailable)
        masteries_raw = self._optional(masteries, "masteries", unavailable)

        return SummonerProfile(
            riot_id=mappers.to_riot_id(account.value),
            puuid=puuid,
            level=summoner.value["summonerLevel"],
            profile_icon_url=profile_icon_url(version, summoner.value["profileIconId"]) if version else None,
            ranked=mappers.to_ranked(ranked_raw.value) if ranked_raw else None,
            top_masteries=(
                mappers.to_masteries(masteries_raw.value, champions, version) if masteries_raw else None
            ),
            unavailable=unavailable,
            # O elo é o dado mais volátil, então é a "idade" dele que importa mostrar.
            fetched_at=(ranked_raw or summoner).stored_at,
        )

    @staticmethod
    def _optional(
        result: CacheEntry[Any] | BaseException,
        section: UnavailableSection,
        unavailable: list[UnavailableSection],
    ) -> CacheEntry[Any] | None:
        if isinstance(result, RiotError):
            logger.warning("Seção '%s' indisponível: %s", section, result)
            unavailable.append(section)
            return None
        if isinstance(result, BaseException):
            raise result  # bug nosso (KeyError etc.): não esconder como "indisponível"
        return result

    async def _load_ddragon(self) -> tuple[str | None, dict[int, Champion]]:
        """Data Dragon fora do ar não derruba a resposta: só ficam sem imagens/nomes."""
        try:
            version = await self._ddragon.latest_version()
            return version, await self._ddragon.champions(version)
        except RiotError as e:
            logger.warning("Data Dragon indisponível: %s", e)
            return None, {}
