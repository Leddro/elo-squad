"""Autenticação: o app manda o token de ID do Firebase (Authorization: Bearer),
e o proxy confere a assinatura antes de gastar a cota da Riot."""

from dataclasses import dataclass
from typing import Annotated, Protocol

from fastapi import Depends, Header, Request
from fastapi.concurrency import run_in_threadpool

from app.errors import UnauthenticatedError


@dataclass(frozen=True, slots=True)
class AuthUser:
    uid: str
    name: str | None


class TokenVerifier(Protocol):
    """Recebe o token cru e devolve o usuário, ou lança UnauthenticatedError."""

    def __call__(self, token: str) -> AuthUser: ...


class FirebaseTokenVerifier:
    """Confere o token com as chaves públicas do Google (baixadas e cacheadas
    pelo firebase-admin). Não precisa de credencial de serviço: só do projectId."""

    def __init__(self, firebase_app: object) -> None:
        self._app = firebase_app

    def __call__(self, token: str) -> AuthUser:
        from firebase_admin import auth  # import tardio: os testes nem carregam o SDK

        try:
            claims = auth.verify_id_token(token, app=self._app)
        except (ValueError, auth.InvalidIdTokenError, auth.CertificateFetchError) as e:
            # ExpiredIdTokenError e RevokedIdTokenError herdam de InvalidIdTokenError.
            raise UnauthenticatedError(str(e)) from e
        return AuthUser(uid=claims["uid"], name=claims.get("name"))


def get_token_verifier(request: Request) -> TokenVerifier:
    """Dependência; os testes trocam por um verificador falso."""
    return request.app.state.token_verifier


async def get_current_user(
    verifier: Annotated[TokenVerifier, Depends(get_token_verifier)],
    authorization: Annotated[str | None, Header()] = None,
) -> AuthUser:
    if not authorization or not authorization.startswith("Bearer "):
        raise UnauthenticatedError("sem token")
    token = authorization.removeprefix("Bearer ").strip()
    # A verificação é síncrona (e pode baixar as chaves): fora do event loop.
    return await run_in_threadpool(verifier, token)


CurrentUser = Annotated[AuthUser, Depends(get_current_user)]
