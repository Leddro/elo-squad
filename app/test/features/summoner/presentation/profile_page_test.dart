import 'dart:async';

import 'package:elo_squad/core/error/failure.dart';
import 'package:elo_squad/features/summoner/data/summoner_data_providers.dart';
import 'package:elo_squad/features/summoner/domain/entities/summoner_profile.dart';
import 'package:elo_squad/features/summoner/domain/repositories/summoner_repository.dart';
import 'package:elo_squad/features/summoner/presentation/pages/profile_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/profiles.dart';

class MockSummonerRepository extends Mock implements SummonerRepository {}

void main() {
  late MockSummonerRepository repository;

  setUp(() => repository = MockSummonerRepository());

  /// Monta a tela com o repositório FALSO no lugar do real (override).
  /// Nada de Dio nem proxy: só a camada presentation está sob teste.
  Future<void> pumpProfilePage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [summonerRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: ProfilePage(riotId: fulano)),
      ),
    );
  }

  void answer(Future<SummonerProfile> Function() result) =>
      when(() => repository.getProfile(fulano)).thenAnswer((_) => result());

  // Obs.: o skeleton pulsa para sempre, então não usamos pumpAndSettle()
  // (ele espera as animações acabarem e nunca terminaria). pump() avança um frame.

  testWidgets('enquanto carrega, mostra o skeleton', (tester) async {
    answer(() => Completer<SummonerProfile>().future); // nunca completa

    await pumpProfilePage(tester);
    await tester.pump();

    expect(find.bySemanticsLabel('Carregando perfil'), findsOneWidget);
  });

  testWidgets('sucesso: mostra elo, PDL e maestrias', (tester) async {
    answer(() async => makeProfile());

    await pumpProfilePage(tester);
    await tester.pump();

    expect(find.text('Ouro II'), findsOneWidget);
    expect(find.text('54 PDL'), findsOneWidget);
    expect(find.text('40V 35D · 53%'), findsOneWidget);
    expect(find.text('Sem ranque'), findsOneWidget); // flex
    expect(find.text('Wukong'), findsOneWidget);
    expect(find.text('Nível 12 · 245.000 pontos'), findsOneWidget);
    expect(find.text('Atualizado há 3 min'), findsOneWidget);
  });

  testWidgets('resposta parcial: só a seção que faltou mostra aviso', (
    tester,
  ) async {
    answer(() async => makeProfile(ranked: null));

    await pumpProfilePage(tester);
    await tester.pump();

    expect(find.text('Ranqueado indisponível no momento'), findsOneWidget);
    expect(find.text('Wukong'), findsOneWidget); // maestrias continuam lá
  });

  testWidgets('não encontrado: Poro e "buscar outro", sem "tentar de novo"', (
    tester,
  ) async {
    answer(() async => throw const NotFoundFailure());

    await pumpProfilePage(tester);
    await tester.pump();

    expect(find.text('Não encontramos esse jogador'), findsOneWidget);
    expect(find.text('Buscar outro jogador'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing);
  });

  testWidgets('rate limit: mostra quanto tempo esperar', (tester) async {
    answer(
      () async =>
          throw const RateLimitedFailure(retryAfter: Duration(seconds: 7)),
    );

    await pumpProfilePage(tester);
    await tester.pump();

    expect(find.text('Aguarde 7s e tente de novo.'), findsOneWidget);
  });

  testWidgets('erro NÃO é refeito sozinho (retry automático desligado)', (
    tester,
  ) async {
    answer(() async => throw const NetworkFailure());

    await pumpProfilePage(tester);
    await tester.pump();
    // O retry padrão do Riverpod 3 tentaria de novo em 200ms, 400ms, 800ms...
    await tester.pump(const Duration(seconds: 30));

    verify(() => repository.getProfile(fulano)).called(1);
  });

  testWidgets('"tentar de novo" busca outra vez e mostra o perfil', (
    tester,
  ) async {
    answer(() async => throw const NetworkFailure());
    await pumpProfilePage(tester);
    await tester.pump();
    expect(find.text('Sem conexão'), findsOneWidget);

    // Na segunda tentativa, a rede voltou.
    answer(() async => makeProfile());
    await tester.tap(find.text('Tentar de novo'));
    await tester.pump(); // reconstrói com isLoading: true → skeleton
    await tester.pump(); // a busca completa → perfil

    expect(find.text('Ouro II'), findsOneWidget);
    verify(() => repository.getProfile(fulano)).called(2);
  });
}
