"""Exceções internas. main.py traduz cada uma para um status HTTP + ErrorResponse."""


class RiotError(Exception):
    """Base: qualquer falha ao falar com a Riot ou o Data Dragon."""


class NotFoundError(RiotError):
    """404 da Riot: Riot ID inexistente ou conta sem perfil de LoL no servidor."""


class RateLimitedError(RiotError):
    """429 da Riot. `retry_after` vem do cabeçalho Retry-After (segundos)."""

    def __init__(self, retry_after: int) -> None:
        super().__init__(f"Rate limit da Riot; tentar de novo em {retry_after}s")
        self.retry_after = retry_after


class UpstreamError(RiotError):
    """Riot/Data Dragon fora do ar, timeout, chave inválida ou expirada etc."""


# ---------- Squads e autenticação (fase 3) ----------

class AppError(Exception):
    """Base dos erros do próprio app (não da Riot)."""


class UnauthenticatedError(AppError):
    """Sem token do Firebase, ou token inválido/expirado."""


class RiotIdRequiredError(AppError):
    """O usuário ainda não vinculou um Riot ID (exigido para entrar em squads)."""


class SquadNotFoundError(AppError):
    """Código de convite inválido, ou squad do qual o usuário não faz parte."""


class NotSquadOwnerError(AppError):
    """Só o líder do squad pode fazer isso."""


class SquadFullError(AppError):
    """O squad já tem o máximo de membros."""


class SquadLimitError(AppError):
    """O usuário já está no máximo de squads."""
