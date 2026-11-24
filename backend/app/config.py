"""Configuração tipada, lida do backend/.env (ou de variáveis de ambiente)."""

from functools import lru_cache

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # SecretStr: aparece como '**********' em print/log. Para usar: .get_secret_value()
    riot_api_key: SecretStr

    # Roteamento da Riot: account-v1 usa a REGIÃO; summoner/league/mastery usam a PLATAFORMA.
    riot_region: str = "americas"
    riot_platform: str = "br1"

    ddragon_language: str = "pt_BR"
    top_masteries_count: int = 3

    # TTLs do cache, em segundos (um por tipo de dado).
    ttl_account_s: int = 24 * 3600     # nome#tag → PUUID (o jogador pode trocar de nome)
    ttl_summoner_s: int = 3600         # nível e ícone mudam devagar
    ttl_ranked_s: int = 5 * 60         # elo muda a cada ranqueada
    ttl_masteries_s: int = 3600
    ttl_ddragon_version_s: int = 6 * 3600


@lru_cache
def get_settings() -> Settings:
    """Lê o .env uma vez só. Fica numa função (e não num global) para os testes
    poderem rodar sem .env, criando o próprio Settings."""
    return Settings()  # type: ignore[call-arg]  # riot_api_key vem do .env
