"""Histórico de partidas: 1 chamada para a lista de IDs + 1 por partida (em paralelo).

Paginação por deslocamento (offset): ?start=0&count=10, depois ?start=10... É o modelo
da própria Riot. Ponto fraco conhecido: se o jogador terminar uma partida entre uma
página e outra, tudo "escorrega" uma posição e a primeira da página seguinte repete a
última da anterior. O app tira duplicadas pelo `matchId`.
"""

import asyncio
import logging

from app import mappers
from app.cache import TTLCache
from app.config import Settings
from app.ddragon import DataDragon
from app.errors import NotFoundError, RateLimitedError
from app.mappers import MatchRecord
from app.models import MatchPage
from app.riot_client import RiotClient

logger = logging.getLogger(__name__)


class MatchService:
    def __init__(self, riot: RiotClient, ddragon: DataDragon, cache: TTLCache, settings: Settings) -> None:
        self._riot = riot
        self._ddragon = ddragon
        self._cache = cache
        self._s = settings

    async def get_matches(self, puuid: str, start: int, count: int) -> MatchPage:
        # 1) Quais partidas? Se isto falhar, não há o que mostrar: a exceção sobe (404/429/503).
        ids_entry = await self._cache.get_or_set(
            f"match-ids:{puuid}:{start}:{count}",
            self._s.ttl_match_ids_s,
            lambda: self._riot.get_match_ids(puuid, start, count),
        )
        ids: list[str] = ids_entry.value

        # 2) Detalhes em paralelo. Partidas já vistas saem do cache sem gastar rate limit.
        results = await asyncio.gather(
            *(self._load_match(match_id) for match_id in ids),
            self._ddragon.load(),
            return_exceptions=True,
        )
        *records, static = results

        # 3) Uma partida falhou → a página inteira falha. As que deram certo JÁ ficaram
        #    no cache, então tentar de novo custa só as que faltaram.
        #    Prioridade ao 429: é o único erro em que "espere N segundos" ajuda o app.
        errors = [r for r in results if isinstance(r, BaseException)]
        if errors:
            raise next((e for e in errors if isinstance(e, RateLimitedError)), errors[0])

        matches = [
            mappers.to_match_summary(record, puuid, static)
            for record in records
            if record is not None  # partida que sumiu da Riot (404): pula
        ]
        # Veio menos do que o pedido → era a última página.
        next_start = start + len(ids) if len(ids) == count else None
        return MatchPage(matches=matches, next_start=next_start)

    async def _load_match(self, match_id: str) -> MatchRecord | None:
        try:
            entry = await self._cache.get_or_set(
                f"match:{match_id}",
                self._s.ttl_match_s,
                # O JSON cru é reduzido ANTES de ir para o cache (~78 KB → ~1 KB).
                lambda: self._fetch_record(match_id),
            )
        except NotFoundError:
            # Raro, mas acontece (partida removida). Um 404 aqui NÃO significa
            # "jogador não encontrado", então não deixamos virar SUMMONER_NOT_FOUND.
            logger.warning("Partida %s não encontrada na Riot; pulando", match_id)
            return None
        return entry.value

    async def _fetch_record(self, match_id: str) -> MatchRecord:
        return mappers.to_match_record(await self._riot.get_match(match_id))
