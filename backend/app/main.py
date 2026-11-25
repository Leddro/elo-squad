"""Entrada do FastAPI: rotas, injeção de dependência e tradução de erros → HTTP.

Rodar (dentro de backend/):  uv run fastapi dev app/main.py
Documentação interativa:     http://127.0.0.1:8000/docs
"""

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import dataclass
from typing import Annotated

import httpx
from fastapi import Depends, FastAPI, Request
from fastapi.responses import JSONResponse

from app.cache import TTLCache
from app.config import Settings, get_settings
from app.ddragon import DataDragon
from app.errors import NotFoundError, RateLimitedError, UpstreamError
from app.models import ErrorCode, ErrorResponse, SummonerProfile
from app.riot_client import RiotClient
from app.service import SummonerService

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class Services:
    summoner: SummonerService


def build_services(http: httpx.AsyncClient, settings: Settings, cache: TTLCache | None = None) -> Services:
    """Monta o grafo de objetos. Os testes chamam isto com um http falso.

    Os serviços COMPARTILHAM o cliente da Riot, o Data Dragon e o cache.
    """
    cache = cache or TTLCache()
    riot = RiotClient(http, settings.riot_api_key.get_secret_value(), settings.riot_region, settings.riot_platform)
    ddragon = DataDragon(http, cache, settings.ddragon_language, settings.ttl_ddragon_version_s)
    return Services(
        summoner=SummonerService(riot, ddragon, cache, settings),
    )


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    # Roda UMA vez ao subir o servidor: um único AsyncClient reaproveita conexões
    # (keep-alive) com a Riot em vez de abrir uma nova a cada requisição.
    async with httpx.AsyncClient(timeout=10.0) as http:
        app.state.services = build_services(http, get_settings())
        yield
    # Ao sair do `async with`, as conexões são fechadas (servidor desligando).


app = FastAPI(title="Elo Squad Proxy", version="0.1.0", lifespan=lifespan)


def get_services(request: Request) -> Services:
    """Dependência: as rotas pedem os serviços por aqui, nunca criam os próprios.
    Nos testes, `app.dependency_overrides` troca esta função por uma versão falsa."""
    return request.app.state.services


ServicesDep = Annotated[Services, Depends(get_services)]

_ERROR_RESPONSES = {
    404: {"model": ErrorResponse, "description": "Riot ID não encontrado"},
    429: {"model": ErrorResponse, "description": "Rate limit da Riot (ver Retry-After)"},
    503: {"model": ErrorResponse, "description": "Riot fora do ar ou chave expirada"},
}


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/summoner/{game_name}/{tag_line}", response_model=SummonerProfile, responses=_ERROR_RESPONSES)
async def get_summoner(game_name: str, tag_line: str, services: ServicesDep) -> SummonerProfile:
    return await services.summoner.get_profile(game_name, tag_line)


# ---------- Exceções internas → status HTTP + ErrorResponse ----------

def _error(status: int, code: ErrorCode, message: str, headers: dict[str, str] | None = None) -> JSONResponse:
    body = ErrorResponse(code=code, message=message).model_dump(by_alias=True)
    return JSONResponse(status_code=status, content=body, headers=headers)


@app.exception_handler(NotFoundError)
async def _on_not_found(_: Request, exc: NotFoundError) -> JSONResponse:
    return _error(404, "SUMMONER_NOT_FOUND", "Riot ID não encontrado ou sem perfil no servidor.")


@app.exception_handler(RateLimitedError)
async def _on_rate_limited(_: Request, exc: RateLimitedError) -> JSONResponse:
    return _error(429, "RATE_LIMITED", "Limite de requisições da Riot atingido.",
                  headers={"Retry-After": str(exc.retry_after)})


@app.exception_handler(UpstreamError)
async def _on_upstream(_: Request, exc: UpstreamError) -> JSONResponse:
    # O detalhe (ex.: "chave expirada") vai para o LOG do servidor, não para o app:
    # o cliente não precisa (nem deve) saber detalhes internos.
    logger.error("Falha na Riot: %s", exc)
    return _error(503, "UPSTREAM_UNAVAILABLE", "Serviço da Riot indisponível no momento.")
