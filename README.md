# Elo Squad

[![App (Flutter)](https://github.com/Leddro/elo-squad/actions/workflows/app.yml/badge.svg)](https://github.com/Leddro/elo-squad/actions/workflows/app.yml)
[![Backend (FastAPI)](https://github.com/Leddro/elo-squad/actions/workflows/backend.yml/badge.svg)](https://github.com/Leddro/elo-squad/actions/workflows/backend.yml)

App Flutter para acompanhar o elo, o histórico de partidas e os campeões mais jogados de um grupo de amigos, com um ranking semanal entre eles. Também tem suporte a TFT.

> 🚧 Em desenvolvimento. Fase 1 (busca de invocador) concluída; próxima: histórico de partidas.

## Stack

| Área | Tecnologia |
|---|---|
| App | Flutter (Android primeiro, Windows na fase 5) |
| Arquitetura | Clean Architecture por feature (`data` / `domain` / `presentation`) |
| Estado | Riverpod |
| HTTP | Dio + interceptors |
| Modelos | freezed + json_serializable |
| Cache offline | drift (SQLite) |
| Backend proxy | FastAPI: guarda a chave da API |
| Social | Firebase (Firestore + FCM) |
| Navegação | go_router |
| Testes / CI | flutter_test + mocktail, GitHub Actions |

## Arquitetura (visão geral)

```
App Flutter  ──HTTP──▶  Backend proxy (FastAPI)  ──HTTP + chave──▶  API da Riot
                         • guarda a chave
                         • cache / rate limit
```

O app **nunca** tem acesso à chave da API. Se ela estivesse no APK, qualquer pessoa poderia extraí-la.

## Roadmap

- [x] **Fase 1**: busca de invocador (Riot ID → elo, nível, maestrias)
- [ ] **Fase 2**: histórico de partidas com paginação e cache offline
- [ ] **Fase 3**: grupo de amigos, ranking semanal e notificações push
- [ ] **Fase 4**: TFT, go_router e teste fechado na Play Store
- [ ] **Fase 5**: versão desktop (Windows) com LCU API e Live Client Data API

## Desenvolvimento

**Pré-requisitos:** Flutter 3.50.0, [uv](https://docs.astral.sh/uv/) (instala o Python 3.15 sozinho), GitHub CLI (`gh auth login`) e Android SDK (para o `adb`).

```powershell
git clone https://github.com/Leddro/elo-squad.git
cd elo-squad

# Backend: crie o .env com a sua chave (dev key da Riot expira em 24h)
cd backend
copy .env.example .env            # edite e cole a RIOT_API_KEY
uv sync
uv run python -m pytest           # 60 testes
uv run fastapi dev app/main.py    # http://127.0.0.1:8000/docs

# App (em outro terminal)
cd app
flutter pub get
dart run build_runner build       # gera *.g.dart e *.freezed.dart
flutter test                      # 163 testes
```

**Rodar no celular por USB** (com o proxy rodando no PC):

```powershell
adb reverse tcp:8000 tcp:8000     # o 127.0.0.1:8000 do celular vira o do PC
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

No emulador Android, basta `flutter run`: o padrão `10.0.2.2` já aponta para o PC.

## Aviso legal

Elo Squad isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games or anyone officially involved in producing or managing Riot Games properties. Riot Games, and all associated properties are trademarks or registered trademarks of Riot Games, Inc.
