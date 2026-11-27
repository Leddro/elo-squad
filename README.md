# Elo Squad

[![App (Flutter)](https://github.com/Leddro/elo-squad/actions/workflows/app.yml/badge.svg)](https://github.com/Leddro/elo-squad/actions/workflows/app.yml)
[![Backend (FastAPI)](https://github.com/Leddro/elo-squad/actions/workflows/backend.yml/badge.svg)](https://github.com/Leddro/elo-squad/actions/workflows/backend.yml)

App Android particular, feito para um grupo pequeno de amigos que jogam League of Legends juntos. É gratuito, sem anúncios, e é instalado por APK só pelos membros do grupo (não está em nenhuma loja).

> 🚧 Em desenvolvimento. Fases 1 a 3 concluídas e em uso; próximo passo: fase 4 (TFT e teste fechado na Play Store).

## Funcionalidades

- **Busca por Riot ID**: elo, nível do invocador e maestrias de campeões.
- **Histórico de partidas**: rolagem infinita com cache offline.
- **Squads**: cada pessoa vincula o próprio Riot ID e entra num grupo por código de convite. O grupo tem um ranking semanal, e uma notificação push anuncia o vencedor da semana.
- **Ciências**: uma vez por dia, uma coleta analisa as partidas ranqueadas recentes de monochamps Desafiante e Grão-Mestre de 12 regiões e destaca builds incomuns que estão ganhando (itens, ordem de habilidades, runa).

## Arquitetura

```
App Flutter ──HTTP──▶ Backend proxy (FastAPI) ──HTTP + chave──▶ API da Riot
     │                  • guarda a chave
     │                  • cache e rate limit por rota
     │                  • squads e ranking (Firestore)
     └── Firebase: login, leitura do Firestore, notificações (FCM)

GitHub Actions (agendado) ──▶ proxy: atualiza o ranking de hora em hora e fecha a semana
GitHub Actions (06:30 BRT) ──▶ coleta das Ciências ──▶ Firestore (sciences/current)
```

O app **nunca** tem acesso à chave da API: se ela estivesse no APK, qualquer pessoa poderia extraí-la. Todos os pedidos à Riot passam pelo proxy, publicado no Render.

## Stack

| Área | Tecnologia |
|---|---|
| App | Flutter (Android primeiro, Windows na fase 5) |
| Arquitetura | Clean Architecture por feature (`data` / `domain` / `presentation`) |
| Estado | Riverpod |
| HTTP | Dio + interceptors |
| Modelos | freezed + json_serializable |
| Cache offline | drift (SQLite) |
| Navegação | go_router |
| Backend proxy | FastAPI (Python), em container no Render |
| Social | Firebase (Auth, Firestore, FCM) |
| Testes / CI | flutter_test + mocktail, pytest, GitHub Actions |

**Endpoints da Riot usados:** account-v1, summoner-v4, league-v4, champion-mastery-v4 e match-v5 (com timeline).

## Roadmap

- [x] **Fase 1**: busca de invocador (Riot ID → elo, nível, maestrias)
- [x] **Fase 2**: histórico de partidas com paginação e cache offline
- [x] **Fase 3**: squads, ranking semanal, notificações push e Ciências
- [ ] **Fase 4**: TFT e teste fechado na Play Store
- [ ] **Fase 5**: versão desktop (Windows) com LCU API e Live Client Data API

## Desenvolvimento

**Pré-requisitos:** Flutter 3.50.0, [uv](https://docs.astral.sh/uv/) (instala o Python sozinho), GitHub CLI (`gh auth login`) e Android SDK (para o `adb`).

```powershell
git clone https://github.com/Leddro/elo-squad.git
cd elo-squad

# Backend: crie o .env com a chave da Riot e as credenciais do Firebase
cd backend
copy .env.example .env            # edite e cole a RIOT_API_KEY
uv sync
uv run python -m pytest           # 89 testes
uv run fastapi dev app/main.py    # http://127.0.0.1:8000/docs

# App (em outro terminal)
cd app
flutter pub get
dart run build_runner build       # gera *.g.dart e *.freezed.dart
flutter test                      # 204 testes
```

**Publicar o proxy** (Render gratuito + GitHub Actions): veja [docs/deploy.md](docs/deploy.md).

**Rodar no celular contra o proxy publicado:**

```powershell
flutter run --dart-define=API_BASE_URL=https://elo-squad-proxy.onrender.com
```

**Rodar no celular por USB com o proxy no PC:**

```powershell
adb reverse tcp:8000 tcp:8000     # o 127.0.0.1:8000 do celular vira o do PC
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

No emulador Android, basta `flutter run`: o padrão `10.0.2.2` já aponta para o PC.

**Coleta das Ciências à mão:**

```powershell
cd backend
uv run python -m app.science.collect --minutes 45   # coleta e publica
uv run python -m app.science.collect --publish-only # só refaz a lista, sem chamar a Riot
```

## Aviso legal

Elo Squad isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games or anyone officially involved in producing or managing Riot Games properties. Riot Games, and all associated properties are trademarks or registered trademarks of Riot Games, Inc.
