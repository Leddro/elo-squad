import 'package:elo_squad/app.dart';
import 'package:elo_squad/core/network/dio_provider.dart';
import 'package:elo_squad/features/auth/data/auth_providers.dart';
import 'package:elo_squad/features/matches/data/match_data_providers.dart';
import 'package:elo_squad/features/notifications/push_service.dart';
import 'package:elo_squad/features/sciences/presentation/providers/science_providers.dart';
import 'package:elo_squad/features/squads/data/squad_data_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'fake_auth_repository.dart';
import 'fake_match_repository.dart';
import 'fake_push_service.dart';
import 'fake_science_repository.dart';
import 'fake_squad_repository.dart';

/// Sobe o APP INTEIRO (roteador incluído) com Firebase, banco e partidas
/// trocados por fakes. [overrides] acrescenta ou troca outros providers.
Future<void> pumpApp(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakeSquadRepository? squads,
  FakePushService? push,
  FakeScienceRepository? sciences,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          auth ?? FakeAuthRepository(signedInAs: testUser),
        ),
        matchRepositoryProvider.overrideWithValue(FakeMatchRepository()),
        proxyWarmUpProvider.overrideWithValue(() {}),
        pushServiceProvider.overrideWithValue(push ?? FakePushService()),
        scienceRepositoryProvider.overrideWithValue(
          sciences ?? FakeScienceRepository(),
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
