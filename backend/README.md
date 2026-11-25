# Elo Squad: backend proxy

BFF (Backend for Frontend) em FastAPI: guarda a chave da Riot, junta várias chamadas numa resposta só e faz cache.

## Rodar

```powershell
cd backend
copy .env.example .env          # e preencha RIOT_API_KEY
uv sync
uv run fastapi dev app/main.py  # http://127.0.0.1:8000/docs
```

Testes: `uv run python -m pytest`

> A dev key da Riot expira a cada 24h. Se o proxy começar a responder 503 com
> "chave inválida ou expirada" no log, gere outra no portal e atualize o `.env`.

## Endpoints

| Método | Rota | Resposta |
|---|---|---|
| GET | `/health` | `{"status": "ok"}` |
| GET | `/summoner/{gameName}/{tagLine}` | `SummonerProfile` (ver `app/models.py`) |
| GET | `/matches/{puuid}?start=0&count=10` | `MatchPage`: partidas da mais nova para a mais antiga; `nextStart` é o `start` da próxima página (`null` = fim). `count` de 1 a 20 |

Erros: `{"code": "...", "message": "..."}` com 404 `SUMMONER_NOT_FOUND`, 429 `RATE_LIMITED` (com `Retry-After`) e 503 `UPSTREAM_UNAVAILABLE`.

## Onde está cada coisa

| Arquivo | Responsabilidade |
|---|---|
| `app/models.py` | Contrato JSON com o app (camelCase) |
| `app/config.py` | Configuração e TTLs, lidos do `.env` |
| `app/riot_client.py` | Único lugar que conhece URLs e a chave da Riot |
| `app/ddragon.py` | Nomes e imagens de campeões/ícones |
| `app/mappers.py` | Tradução Riot → contrato (camada anticorrupção) |
| `app/cache.py` | Cache em memória com TTL |
| `app/service.py` | Perfil: chamadas paralelas e resposta parcial |
| `app/match_service.py` | Histórico: lista de IDs + detalhes em paralelo, paginação |
| `app/main.py` | Rotas, injeção de dependência, erros → HTTP |
| `tests/conftest.py` | Riot simulada (`httpx.MockTransport`), compartilhada pelos testes |
| `tests/test_*.py` | Testes de cada endpoint |
