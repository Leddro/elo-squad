import 'dart:async';

import 'package:elo_squad/core/error/failure.dart';
import 'package:elo_squad/features/matches/data/match_data_providers.dart';
import 'package:elo_squad/features/matches/domain/entities/match_history.dart';
import 'package:elo_squad/features/matches/domain/entities/match_summary.dart';
import 'package:elo_squad/features/matches/presentation/widgets/match_history_sliver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/fake_match_repository.dart';
import '../../../helpers/matches.dart';

void main() {
  late FakeMatchRepository repository;

  MatchHistory saved(List<MatchSummary> matches, {bool hasMore = true}) =>
      MatchHistory(
        matches: matches,
        hasMore: hasMore,
        refreshedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

  /// Nunca termina: simula uma requisição em andamento.
  Future<void> pending() => Completer<void>().future;

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [matchRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [MatchHistorySliver(puuid: 'puuid-123')],
            ),
          ),
        ),
      ),
    );
    // Alguns frames: o Stream emite, o refresh responde, o sentinela dispara.
    // (Sem pumpAndSettle: o indicador de carregamento gira para sempre.)
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  testWidgets('cache aparece na hora, enquanto o refresh ainda roda', (
    tester,
  ) async {
    repository = FakeMatchRepository(saved(pageOf([2, 1])))
      ..onRefresh = pending;

    await pumpSection(tester);

    expect(find.textContaining('Vitória'), findsNWidgets(2));
    expect(repository.refreshCalls, 1); // abrir a tela já atualiza
  });

  testWidgets('quando o refresh grava, a lista troca sozinha (Stream)', (
    tester,
  ) async {
    repository = FakeMatchRepository(saved([makeMatch(1)]))
      ..onRefresh = pending;
    await pumpSection(tester);

    repository.emit(saved(pageOf([3, 2, 1])));
    await tester.pump();

    expect(find.textContaining('Vitória'), findsNWidgets(3));
  });

  testWidgets('nunca buscado e refresh em andamento: esqueleto', (
    tester,
  ) async {
    repository = FakeMatchRepository()..onRefresh = pending;

    await pumpSection(tester);

    expect(find.bySemanticsLabel('Carregando partidas'), findsOneWidget);
  });

  testWidgets('nunca buscado e refresh falhou: mensagem e "tentar de novo"', (
    tester,
  ) async {
    repository = FakeMatchRepository()
      ..onRefresh = () async => throw const NetworkFailure();

    await pumpSection(tester);
    expect(find.text('Sem conexão. Verifique sua internet.'), findsOneWidget);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();

    expect(repository.refreshCalls, 2);
  });

  testWidgets('com cache e refresh falhou: mantém a lista e avisa', (
    tester,
  ) async {
    repository = FakeMatchRepository(saved(pageOf([2, 1])))
      ..onRefresh = () async => throw const NetworkFailure();

    await pumpSection(tester);

    expect(
      find.textContaining('Vitória'),
      findsNWidgets(2),
    ); // o cache continua
    expect(find.textContaining('Mostrando as partidas salvas'), findsOneWidget);
  });

  testWidgets('buscado e sem partidas: mensagem de lista vazia', (
    tester,
  ) async {
    repository = FakeMatchRepository(saved([], hasMore: false));

    await pumpSection(tester);

    expect(find.text('Nenhuma partida recente.'), findsOneWidget);
  });

  group('rolagem infinita', () {
    testWidgets('chegar ao fim da lista pede a próxima página UMA vez', (
      tester,
    ) async {
      repository = FakeMatchRepository(saved(pageOf([3, 2, 1])));

      await pumpSection(tester);

      expect(repository.loadMoreCalls, 1);
    });

    testWidgets('última página: não pede mais e mostra o fim', (tester) async {
      repository = FakeMatchRepository(
        saved(pageOf([3, 2, 1]), hasMore: false),
      );

      await pumpSection(tester);

      expect(repository.loadMoreCalls, 0);
      expect(find.text('Fim do histórico'), findsOneWidget);
    });

    testWidgets('página nova chegou: o sentinela dispara de novo', (
      tester,
    ) async {
      repository = FakeMatchRepository(saved(pageOf([6, 5, 4])));
      await pumpSection(tester);
      expect(repository.loadMoreCalls, 1);

      repository.emit(saved(pageOf([6, 5, 4, 3, 2, 1])));
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }

      expect(repository.loadMoreCalls, 2);
    });

    testWidgets('falhou: botão de tentar de novo, sem repetir sozinho', (
      tester,
    ) async {
      repository = FakeMatchRepository(saved(pageOf([3, 2, 1])))
        ..onLoadMore = () async =>
            throw const RateLimitedFailure(retryAfter: Duration(seconds: 2));

      await pumpSection(tester);
      await tester.pump();

      expect(find.text('Muitas requisições. Aguarde 2s.'), findsOneWidget);
      expect(repository.loadMoreCalls, 1); // não entrou em loop

      await tester.tap(find.text('Tentar de novo'));
      await tester.pump();

      expect(repository.loadMoreCalls, 2);
    });
  });

  testWidgets('partida da Arena mostra a colocação, KDA e duração', (
    tester,
  ) async {
    final arena = makeMatch(1, kills: 6).copyWith(
      queue: QueueType.arena,
      result: MatchResult.loss,
      placement: 5,
      deaths: 4,
      assists: 3,
      duration: const Duration(minutes: 20),
    );
    repository = FakeMatchRepository(saved([arena], hasMore: false));

    await pumpSection(tester);

    expect(find.textContaining('5º lugar'), findsOneWidget);
    expect(find.textContaining('Arena'), findsOneWidget);
    expect(find.text('6/4/3 · KDA 2,3 · 180 CS'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
  });
}
