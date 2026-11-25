import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:elo_squad/core/database/app_database.dart';
import 'package:elo_squad/core/error/failure.dart';
import 'package:elo_squad/features/matches/data/datasources/match_remote_data_source.dart';
import 'package:elo_squad/features/matches/data/local/match_local_data_source.dart';
import 'package:elo_squad/features/matches/data/repositories/match_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http.dart';
import '../../../helpers/fixtures.dart';

// Teste de INTEGRAÇÃO da camada data: Dio (com a rede falsa), DTO, banco em
// memória e repositório, todos de verdade.

void main() {
  late FakeHttpAdapter adapter;
  late AppDatabase db;
  late MatchRepositoryImpl repository;
  const fulano = 'puuid-fulano';
  final now = DateTime.utc(2026, 11, 25, 9);

  setUp(() {
    adapter = FakeHttpAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://proxy.test'))
      ..httpClientAdapter = adapter;
    db = AppDatabase(NativeDatabase.memory());
    repository = MatchRepositoryImpl(
      MatchRemoteDataSource(dio),
      MatchLocalDataSource(db),
      clock: () => now,
    );
  });

  tearDown(() => db.close());

  /// Uma página com os [ids] pedidos (o resto dos campos vem da fixture).
  Map<String, dynamic> pageJson(List<String> ids, int? nextStart) {
    final json = loadFixture('match_page.json');
    final template = (json['matches'] as List).first as Map<String, dynamic>;
    return json
      ..['matches'] = [
        for (final id in ids) {...template, 'matchId': id},
      ]
      ..['nextStart'] = nextStart;
  }

  /// Responde com a fixture (3 partidas); [nextStart] controla se há mais.
  void respondWithPage({int? nextStart = 3}) => adapter.respond = (_) =>
      jsonResponse(loadFixture('match_page.json')..['nextStart'] = nextStart);

  test('refresh: pede a página 0 e grava no banco', () async {
    respondWithPage();

    await repository.refresh(fulano);

    expect(
      adapter.requests.single.uri.toString(),
      'http://proxy.test/matches/puuid-fulano?start=0&count=$matchPageSize',
    );
    final history = await repository.watchHistory(fulano).first;
    expect(history.matches, hasLength(3));
    expect(history.refreshedAt, now); // relógio injetado
    expect(history.hasMore, isTrue);
  });

  test('loadMore: continua de onde o banco parou', () async {
    respondWithPage();
    await repository.refresh(fulano);

    await repository.loadMore(fulano);

    expect(adapter.requests.last.uri.queryParameters['start'], '3');
  });

  test('loadMore sem refresh antes: não chama a rede', () async {
    await repository.loadMore(fulano);

    expect(adapter.requests, isEmpty);
  });

  test('loadMore depois da última página: não chama a rede', () async {
    respondWithPage(nextStart: null);
    await repository.refresh(fulano);

    await repository.loadMore(fulano);

    expect(adapter.requests, hasLength(1)); // só o refresh
  });

  test('refresh falhou (sem internet): o cache continua lá', () async {
    respondWithPage();
    await repository.refresh(fulano);

    adapter.respond = (options) => throw DioException.connectionError(
      requestOptions: options,
      reason: 'Connection refused',
    );

    await expectLater(
      repository.refresh(fulano),
      throwsA(isA<NetworkFailure>()),
    );
    expect((await repository.watchHistory(fulano).first).matches, hasLength(3));
  });

  test('429 → RateLimitedFailure', () async {
    adapter.respond = (_) => jsonResponse(
      {'code': 'RATE_LIMITED', 'message': '...'},
      status: 429,
      headers: {
        'retry-after': ['2'],
      },
    );

    await expectLater(
      repository.refresh(fulano),
      throwsA(isA<RateLimitedFailure>()),
    );
  });

  test('loadMore durante um refresh espera o refresh (sem corrida)', () async {
    // Cache com 6 partidas, em duas páginas de 3.
    adapter.respond = (_) => jsonResponse(pageJson(['A6', 'A5', 'A4'], 3));
    await repository.refresh(fulano);
    adapter.respond = (_) => jsonResponse(pageJson(['A3', 'A2', 'A1'], 6));
    await repository.loadMore(fulano);

    // Refresh LENTO e sem partida em comum: vai descartar as 6 e ficar com 3.
    final slowFirstPage = Completer<ResponseBody>();
    adapter.respond = (options) {
      if (options.uri.queryParameters['start'] == '0') {
        return slowFirstPage.future;
      }
      return jsonResponse(pageJson(['N4', 'N3', 'N2'], 6));
    };

    final refreshing = repository.refresh(fulano);
    final loading = repository.loadMore(fulano); // começa ANTES do refresh
    slowFirstPage.complete(jsonResponse(pageJson(['N7', 'N6', 'N5'], 3)));
    await Future.wait([refreshing, loading]);

    // Sem a fila, o loadMore teria lido a contagem velha (6) e pedido
    // start=6, gravando a página depois de um buraco.
    expect(adapter.requests.last.uri.queryParameters['start'], '3');
    expect((await repository.watchHistory(fulano).first).matches, hasLength(6));
  });

  test('JSON fora do contrato → UnexpectedFailure, e nada é gravado', () async {
    final json = loadFixture('match_page.json');
    (json['matches'] as List).last['result'] = 'DRAW';
    adapter.respond = (_) => jsonResponse(json);

    await expectLater(
      repository.refresh(fulano),
      throwsA(isA<UnexpectedFailure>()),
    );
    expect((await repository.watchHistory(fulano).first).neverLoaded, isTrue);
  });
}
