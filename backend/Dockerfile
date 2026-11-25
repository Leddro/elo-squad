# Imagem do proxy (Render e Google Cloud Run).
# Build na nuvem, sem Docker local:  gcloud run deploy --source backend ...

FROM python:3.15-slim

# uv na MESMA versão usada no desenvolvimento.
COPY --from=ghcr.io/astral-sh/uv:0.13.8 /uv /bin/uv

WORKDIR /app
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PYTHONUNBUFFERED=1

# Dependências primeiro (camada em cache enquanto o uv.lock não mudar).
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev --no-install-project

COPY app ./app

# Cloud Run informa a porta pela variável PORT (8080 por padrão).
# Sem usuário root dentro do container. Não pode se chamar "proxy": esse
# usuário já existe na imagem base do Debian (useradd sai com código 9).
RUN useradd --create-home elosquad
USER elosquad
CMD ["sh", "-c", "exec /app/.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}"]
