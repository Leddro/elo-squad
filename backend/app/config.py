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

    # Firebase (fase 3). Em produção (Cloud Run) a credencial vem do ambiente;
    # no PC, rode o emulador e defina FIRESTORE_EMULATOR_HOST=127.0.0.1:8080.
    firebase_project_id: str = "elo-squad-app"

    ddragon_language: str = "pt_BR"
    top_masteries_count: int = 3

    # TTLs do cache, em segundos (um por tipo de dado).
    ttl_account_s: int = 24 * 3600     # nome#tag → PUUID (o jogador pode trocar de nome)
    ttl_summoner_s: int = 3600         # nível e ícone mudam devagar
    ttl_ranked_s: int = 5 * 60         # elo muda a cada ranqueada
    ttl_masteries_s: int = 3600
    ttl_ddragon_version_s: int = 6 * 3600
    # Lista de IDs: muda a cada partida nova, mas uma partida dura no mínimo uns 15 min.
    ttl_match_ids_s: int = 2 * 60
    # Uma partida terminada NUNCA muda (dado imutável). O TTL só limita a memória usada.
    ttl_match_s: int = 24 * 3600


@lru_cache
def get_settings() -> Settings:
    """Lê o .env uma vez só. Fica numa função (e não num global) para os testes
    poderem rodar sem .env, criando o próprio Settings."""
    return Settings()  # type: ignore[call-arg]  # riot_api_key vem do .env
