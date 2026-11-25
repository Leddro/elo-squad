import 'package:elo_squad/features/summoner/data/summoner_data_providers.dart';
import 'package:elo_squad/features/summoner/domain/entities/profile_result.dart';
import 'package:elo_squad/features/summoner/domain/repositories/summoner_repository.dart';
import 'package:elo_squad/features/summoner/presentation/pages/home_page.dart';
import 'package:elo_squad/features/summoner/presentation/pages/profile_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/profiles.dart';

class MockSummonerRepository extends Mock implements SummonerRepository {}

void main() {
  late MockSummonerRepository repository;

  // `any()` precisa de um valor "reserva" do tipo para montar o matcher.
  // Tipos nativos (int, String) já vêm registrados; tipos nossos, não.
  setUpAll(() => registerFallbackValue(fulano));

  setUp(() {
    repository = MockSummonerRepository();
    when(() => repository.getProfile(fulano))
        .thenAnswer((_) async => ProfileResult(profile: makeProfile()));
  });

  Future<void> pumpHome(WidgetTester tester) => pumpApp(
    tester,
    overrides: [summonerRepositoryProvider.overrideWithValue(repository)],
  );

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpFrames(tester);
  }

  testWidgets('Riot ID inválido: erro no campo e NENHUMA requisição', (
    tester,
  ) async {
    await pumpHome(tester);

    await search(tester, 'Fulano');

    expect(
      find.text('Use o formato nome#tag. Exemplo: Fulano#BR1'),
      findsOneWidget,
    );
    expect(find.byType(ProfilePage), findsNothing);
    verifyNever(() => repository.getProfile(any()));
  });

  testWidgets('Riot ID válido: abre o perfil', (tester) async {
    await pumpHome(tester);

    await search(tester, 'Fulano#BR1');

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('Ouro II'), findsOneWidget);
  });

  testWidgets('voltar do perfil mantém o texto digitado', (tester) async {
    await pumpHome(tester);
    await search(tester, 'Fulano#BR1');

    await tester.pageBack();
    await pumpFrames(tester);

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(ProfilePage), findsNothing);
    // Lê o CONTEÚDO do campo. find.text('Fulano#BR1') seria ambíguo: o
    // hintText "Fulano#BR1" fica na árvore (invisível) mesmo com o campo cheio.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Fulano#BR1');
  });
}
