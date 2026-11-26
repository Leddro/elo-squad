import 'package:elo_squad/app.dart';
import 'package:elo_squad/core/network/dio_provider.dart';
import 'package:elo_squad/features/auth/data/auth_providers.dart';
import 'package:elo_squad/features/matches/data/match_data_providers.dart';
import 'package:elo_squad/features/notifications/push_service.dart';
import 'package:elo_squad/features/sciences/presentation/providers/science_providers.dart';
import 'package:elo_squad/features/squads/data/squad_data_providers.dart';
import 'package:elo_squad/features/summoner/data/summoner_data_providers.dart';
import 'package:elo_squad/features/summoner/domain/repositories/summoner_repository.dart';
import 'package:elo_squad/features/summoner/presentation/pages/home_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Size;
import 'package:flutter_riverpod/misc.dart' show Override;

import 'fake_auth_repository.dart';
import 'fake_match_repository.dart';
import 'fake_push_service.dart';
import 'fake_science_repository.dart';
import 'fake_squad_repository.dart';
import 'fake_summoner_repository.dart';

/// Sobe o APP INTEIRO (roteador incluído) com Firebase, banco e partidas
/// trocados por fakes. [overrides] acrescenta ou troca outros providers.
Future<void> pumpApp(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakeSquadRepository? squads,
  FakePushService? push,
  FakeScienceRepository? sciences,
  SummonerRepository? summoner,
  bool askRiotId = false,
  List<Override> overrides = const [],
}) async {
  // Tela de celular (360x800 lógicos), não a 800x600 padrão do teste.
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          auth ?? FakeAuthRepository(signedInAs: testUser),
        ),
        matchRepositoryProvider.overrideWithValue(FakeMatchRepository()),
        proxyWarmUpProvider.overrideWithValue(() {}),
        if (!askRiotId)
          askRiotIdOnFirstAccessProvider.overrideWithBuild((_, _) => false),
        pushServiceProvider.overrideWithValue(push ?? FakePushService()),
        scienceRepositoryProvider.overrideWithValue(
          sciences ?? FakeScienceRepository(),
        ),
        summonerRepositoryProvider.overrideWithValue(
          summoner ?? FakeSummonerRepository(),
        ),
        squadRepositoryProvider.overrideWithValue(
          squads ?? FakeSquadRepository(),
        ),
        ...overrides,
      ],
      child: const EloSquadApp(),
    ),
  );
  await pumpFrames(tester);
}

/// Avança 1s em frames de 100ms. Cada pump() é UM frame: a navegação precisa
/// de vários. Não dá para usar pumpAndSettle(): indicadores de carregamento
/// giram para sempre.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
