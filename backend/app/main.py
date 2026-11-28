"""Entrada do FastAPI: rotas, injeção de dependência e tradução de erros → HTTP.

Rodar (dentro de backend/):  uv run fastapi dev app/main.py
Documentação interativa:     http://127.0.0.1:8000/docs
"""

import logging
import os
import secrets
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import dataclass
from typing import Annotated

import httpx
from fastapi import HTTPException, Depends, FastAPI, Header, Query, Request, Response
from fastapi.responses import JSONResponse

from app.auth import CurrentUser, FirebaseTokenVerifier, get_current_user
from app.cache import TTLCache
from app.config import Settings, get_settings
from app.ddragon import DataDragon
from app.errors import (
    NotFoundError,
    NotSquadOwnerError,
    RateLimitedError,
    RiotIdRequiredError,
    SquadFullError,
    SquadLimitError,
    SquadNotFoundError,
    UnauthenticatedError,
    UpstreamError,
)
from app.match_service import MatchService
from app.notifier import FcmNotifier, NoNotifier, Notifier
from app.models import (
    CreateSquadRequest,
    ErrorCode,
    ErrorResponse,
    FcmTokenRequest,
    JoinSquadRequest,
    LinkRiotIdRequest,
    LinkRiotIdResponse,
    MatchPage,
    SquadIconRequest,
    SquadInfoRequest,
    SquadPeriod,
    SquadPeriodRequest,
    SquadRef,
    SummonerProfile,
)
from app.ranking_service import RankingService
from app.riot_client import RiotClient
from app.service import SummonerService
from app.squad_service import SquadService
from app.store import FirestoreStore, Store

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class Services:
    summoner: SummonerService
    matches: MatchService
    squads: SquadService
    ranking: RankingService


def build_services(
    http: httpx.AsyncClient,
    settings: Settings,
    store: Store,
    cache: TTLCache | None = None,
    notifier: Notifier | None = None,
) -> Services:
    """Monta o grafo de objetos. Os testes chamam isto com um http falso.

    Os dois serviços COMPARTILHAM o cliente da Riot, o Data Dragon e o cache: a
    lista de campeões baixada para o perfil serve também para o histórico.
    """
    cache = cache or TTLCache()
    riot = RiotClient(http, settings.riot_api_key.get_secret_value(), settings.riot_region, settings.riot_platform)
    ddragon = DataDragon(http, cache, settings.ddragon_language, settings.ttl_ddragon_version_s)
    summoner = SummonerService(riot, ddragon, cache, settings)
    return Services(
        summoner=summoner,
        matches=MatchService(riot, ddragon, cache, settings),
        squads=SquadService(store, summoner),
        ranking=RankingService(store, riot, cache, settings, notifier or NoNotifier()),
    )


class _UnavailableStore:
    """Sem credencial do Firestore (ex.: PC sem emulador): o proxy sobe mesmo
    assim, e só as rotas de squad respondem 503."""

    def __getattr__(self, name: str):  # noqa: ANN204
        async def unavailable(*_: object, **__: object) -> None:
            raise UpstreamError("Firestore não configurado (credencial ou emulador)")

        return unavailable


def _firebase(settings: Settings) -> tuple[object, Store, Notifier]:
    if "K_SERVICE" not in os.environ:  # fora do Google Cloud (PC, Render)
        # Não procurar o servidor de metadados do Google Cloud: sem ele, a
        # busca pela credencial demora ~20 s antes de desistir.
        os.environ.setdefault("NO_GCE_CHECK", "true")
    import firebase_admin
    from firebase_admin import credentials
    from firebase_admin import firestore_async
    from google.auth.exceptions import DefaultCredentialsError

    credential = (
        credentials.Certificate(settings.firebase_credentials_file) if settings.firebase_credentials_file else None
    )
    fb_app = firebase_admin.initialize_app(credential, options={"projectId": settings.firebase_project_id})
    try:
        store: Store = FirestoreStore(firestore_async.client(fb_app))
    except DefaultCredentialsError:
        logger.warning("Firestore sem credencial: rotas de squad desativadas.")
        return fb_app, _UnavailableStore(), NoNotifier()  # type: ignore[return-value]
    return fb_app, store, FcmNotifier(store, fb_app)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    # Roda UMA vez ao subir o servidor: um único AsyncClient reaproveita conexões
    # (keep-alive) com a Riot em vez de abrir uma nova a cada requisição.
    async with httpx.AsyncClient(timeout=10.0) as http:
        settings = get_settings()
        fb_app, store, notifier = _firebase(settings)
        app.state.services = build_services(http, settings, store, notifier=notifier)
        app.state.token_verifier = FirebaseTokenVerifier(fb_app)
        app.state.jobs_secret = settings.jobs_secret.get_secret_value() if settings.jobs_secret else None
        yield
    # Ao sair do `async with`, as conexões são fechadas (servidor desligando).


app = FastAPI(title="Elo Squad Proxy", version="0.1.0", lifespan=lifespan)


def get_services(request: Request) -> Services:
    """Dependência: as rotas pedem os serviços por aqui, nunca criam os próprios.
    Nos testes, `app.dependency_overrides` troca esta função por uma versão falsa."""
    return request.app.state.services


ServicesDep = Annotated[Services, Depends(get_services)]

_ERROR_RESPONSES = {
    401: {"model": ErrorResponse, "description": "Sem token do Firebase, ou token inválido"},
    404: {"model": ErrorResponse, "description": "Riot ID não encontrado"},
    429: {"model": ErrorResponse, "description": "Rate limit da Riot (ver Retry-After)"},
    503: {"model": ErrorResponse, "description": "Riot fora do ar ou chave expirada"},
}


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


# Toda rota que gasta cota da Riot exige login (token do Firebase).
_AUTH = [Depends(get_current_user)]


@app.get("/summoner/{game_name}/{tag_line}", response_model=SummonerProfile, responses=_ERROR_RESPONSES,
         dependencies=_AUTH)
async def get_summoner(game_name: str, tag_line: str, services: ServicesDep) -> SummonerProfile:
    return await services.summoner.get_profile(game_name, tag_line)


@app.get("/matches/{puuid}", response_model=MatchPage, responses=_ERROR_RESPONSES, dependencies=_AUTH)
async def get_matches(
    puuid: str,
    services: ServicesDep,
    start: Annotated[int, Query(ge=0, description="Posição da 1ª partida (0 = a mais recente)")] = 0,
    # Teto baixo de propósito: cada partida é 1 chamada à Riot (dev key: 20 por segundo).
    count: Annotated[int, Query(ge=1, le=20, description="Partidas por página")] = 10,
) -> MatchPage:
    # O PUUID vem do perfil (GET /summoner): o app já o tem, então pulamos o account-v1.
    return await services.matches.get_matches(puuid, start, count)


# ---------- Usuário e squads (fase 3) ----------
# O app LÊ squads e usuários direto do Firestore; as ESCRITAS passam por aqui.

_SQUAD_ERRORS = {
    **_ERROR_RESPONSES,
    409: {"model": ErrorResponse, "description": "Riot ID não vinculado, squad cheio ou limite de squads"},
}


@app.put("/me/riot-id", response_model=LinkRiotIdResponse, responses=_SQUAD_ERRORS)
async def link_riot_id(body: LinkRiotIdRequest, user: CurrentUser, services: ServicesDep) -> LinkRiotIdResponse:
    return await services.squads.link_riot_id(user, body.game_name, body.tag_line)


@app.post("/me/fcm-tokens", status_code=204, responses=_SQUAD_ERRORS)
async def add_fcm_token(body: FcmTokenRequest, user: CurrentUser, services: ServicesDep) -> Response:
    await services.squads.add_fcm_token(user, body.token)
    return Response(status_code=204)


@app.delete("/me/fcm-tokens/{token}", status_code=204, responses=_SQUAD_ERRORS)
async def remove_fcm_token(token: str, user: CurrentUser, services: ServicesDep) -> Response:
    """Chamada no logout: o aparelho para de receber push desta conta."""
    await services.squads.remove_fcm_token(user, token)
    return Response(status_code=204)


@app.post("/squads", status_code=201, response_model=SquadRef, responses=_SQUAD_ERRORS)
async def create_squad(body: CreateSquadRequest, user: CurrentUser, services: ServicesDep) -> SquadRef:
    return await services.squads.create(user, body.name)


@app.post("/squads/join", response_model=SquadRef, responses=_SQUAD_ERRORS)
async def join_squad(body: JoinSquadRequest, user: CurrentUser, services: ServicesDep) -> SquadRef:
    return await services.squads.join(user, body.invite_code)


@app.post("/squads/{squad_id}/leave", status_code=204, responses=_SQUAD_ERRORS)
async def leave_squad(squad_id: str, user: CurrentUser, services: ServicesDep) -> Response:
    await services.squads.leave(user, squad_id)
    return Response(status_code=204)


@app.put("/squads/{squad_id}/icon", status_code=204, responses=_SQUAD_ERRORS)
async def set_squad_icon(
    squad_id: str, body: SquadIconRequest, user: CurrentUser, services: ServicesDep,
) -> Response:
    await services.squads.set_icon(user, squad_id, body.icon)
    return Response(status_code=204)


@app.put("/squads/{squad_id}/info", status_code=204, responses=_SQUAD_ERRORS)
async def set_squad_info(
    squad_id: str, body: SquadInfoRequest, user: CurrentUser, services: ServicesDep,
) -> Response:
    await services.squads.set_info(user, squad_id, body.name, body.description)
    return Response(status_code=204)


@app.put("/squads/{squad_id}/period", response_model=SquadPeriod, responses=_SQUAD_ERRORS)
async def set_squad_period(
    squad_id: str, body: SquadPeriodRequest, user: CurrentUser, services: ServicesDep,
) -> SquadPeriod:
    """Só o líder. O período em andamento acaba sem troféus e o novo começa já."""
    try:
        return await services.ranking.set_period(user, squad_id, body)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e)) from e


@app.delete("/squads/{squad_id}/members/{member_uid}", status_code=204, responses=_SQUAD_ERRORS)
async def remove_squad_member(
    squad_id: str, member_uid: str, user: CurrentUser, services: ServicesDep,
) -> Response:
    await services.squads.remove_member(user, squad_id, member_uid)
    return Response(status_code=204)


# ---------- Tarefas agendadas (Cloud Scheduler) ----------

def get_jobs_secret(request: Request) -> str | None:
    """Dependência; os testes trocam pelo segredo deles."""
    return getattr(request.app.state, "jobs_secret", None)


async def require_jobs_secret(
    expected: Annotated[str | None, Depends(get_jobs_secret)],
    x_jobs_secret: Annotated[str | None, Header()] = None,
) -> None:
    # compare_digest: compara em tempo constante (não vaza o segredo pelo tempo).
    if expected is None or x_jobs_secret is None or not secrets.compare_digest(x_jobs_secret, expected):
        raise UnauthenticatedError("segredo das tarefas inválido")


_JOBS = [Depends(require_jobs_secret)]


@app.post("/jobs/refresh-rankings", dependencies=_JOBS, include_in_schema=False)
async def job_refresh_rankings(services: ServicesDep) -> dict[str, int]:
    return {"squads": await services.ranking.refresh()}


@app.post("/jobs/close-week", dependencies=_JOBS, include_in_schema=False)
async def job_close_week(services: ServicesDep) -> dict[str, int]:
    return {"squads": await services.ranking.close_week()}


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


@app.exception_handler(UnauthenticatedError)
async def _on_unauthenticated(_: Request, exc: UnauthenticatedError) -> JSONResponse:
    return _error(401, "UNAUTHENTICATED", "Faça login de novo.", headers={"WWW-Authenticate": "Bearer"})


@app.exception_handler(RiotIdRequiredError)
async def _on_riot_id_required(_: Request, exc: RiotIdRequiredError) -> JSONResponse:
    return _error(409, "RIOT_ID_REQUIRED", "Vincule o seu Riot ID antes de entrar em squads.")


@app.exception_handler(NotSquadOwnerError)
async def _on_not_owner(_: Request, exc: NotSquadOwnerError) -> JSONResponse:
    return _error(403, "NOT_SQUAD_OWNER", "Só o líder do squad pode fazer isso.")


@app.exception_handler(SquadNotFoundError)
async def _on_squad_not_found(_: Request, exc: SquadNotFoundError) -> JSONResponse:
    return _error(404, "SQUAD_NOT_FOUND", "Squad não encontrado (confira o código de convite).")


@app.exception_handler(SquadFullError)
async def _on_squad_full(_: Request, exc: SquadFullError) -> JSONResponse:
    return _error(409, "SQUAD_FULL", "Este squad já está cheio.")


@app.exception_handler(SquadLimitError)
async def _on_squad_limit(_: Request, exc: SquadLimitError) -> JSONResponse:
    return _error(409, "SQUAD_LIMIT", "Você já está no número máximo de squads.")
