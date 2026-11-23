# Elo Squad

App Flutter para acompanhar o elo, o histórico de partidas e os campeões mais jogados de um grupo de amigos, com um ranking semanal entre eles. Também tem suporte a TFT.

> 🚧 Em desenvolvimento: fase 1 (busca de invocador).

## Stack

| Área | Tecnologia |
|---|---|
| App | Flutter (Android primeiro, Windows na fase 5) |
| Arquitetura | Clean Architecture por feature (`data` / `domain` / `presentation`) |
| Estado | Riverpod |
| HTTP | Dio + interceptors |
| Modelos | freezed + json_serializable |
| Cache offline | Hive ou Isar (a definir) |
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

- [ ] **Fase 1**: busca de invocador (Riot ID → elo, nível, maestrias)
- [ ] **Fase 2**: histórico de partidas com paginação e cache offline
- [ ] **Fase 3**: grupo de amigos, ranking semanal e notificações push
- [ ] **Fase 4**: TFT, go_router e teste fechado na Play Store
- [ ] **Fase 5**: versão desktop (Windows) com LCU API e Live Client Data API

## Aviso legal

Elo Squad isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games or anyone officially involved in producing or managing Riot Games properties. Riot Games, and all associated properties are trademarks or registered trademarks of Riot Games, Inc.
