import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:elo_squad/core/database/app_database.dart';
import 'package:elo_squad/core/error/failure.dart';
import 'package:elo_squad/features/summoner/data/datasources/summoner_remote_data_source.dart';
import 'package:elo_squad/features/summoner/data/local/profile_local_data_source.dart';
import 'package:elo_squad/features/summoner/data/repositories/summoner_repository_impl.dart';
import 'package:elo_squad/features/summoner/domain/entities/riot_id.dart';
import 'package:elo_squad/features/summoner/domain/entities/tier.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http.dart';
import '../../../helpers/fixtures.dart';

void main() {
  late FakeHttpAdapter adapter;
  late AppDatabase db;
  late SummonerRepositoryImpl repository;
  const fulano = RiotId('Fulano', 'BR1');

  setUp(() {
    adapter = FakeHttpAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://proxy.test'))
      ..httpClientAdapter = adapter;
    // Banco em memória e VAZIO: nos testes de erro abaixo não há cópia
    // salva, então o erro original tem de chegar à tela.
    db = AppDatabase(NativeDatabase.memory());
    repository = SummonerRepositoryImpl(
      SummonerRemoteDataSource(dio),
      ProfileLocalDataSource(db),
    );
  });

  tearDown(() => db.close());

  test('sucesso: devolve a entidade convertida', () async {
    adapter.respond = (_) => jsonResponse(loadFixture('summoner_profile.json'));

    final result = await repository.getProfile(fulano);

    expect(result.isStale, isFalse);
    expect(result.profile.riotId, fulano);
    expect(result.profile.ranked!.solo!.tier, Tier.gold);
  });

  test('codifica espaços e acentos na URL', () async {
    adapter.respond = (_) => jsonResponse(loadFixture('summoner_profile.json'));

    await repository.getProfile(const RiotId('Nome Com Espaço', 'BR1'));

    expect(
      adapter.requests.single.uri.toString(),
      'http://proxy.test/summoner/Nome%20Com%20Espa%C3%A7o/BR1',
    );
  });

  group('erros viram Failure (nada de DioException escapa)', () {
    Future<void> expectFailure<T extends Failure>() =>
        expectLater(repository.getProfile(fulano), throwsA(isA<T>()));

    test('404 do proxy → NotFoundFailure', () async {
      adapter.respond = (_) => jsonResponse({
        'code': 'SUMMONER_NOT_FOUND',
        'message': '...',
      }, status: 404);

      await expectFailure<NotFoundFailure>();
    });

    test('429 → RateLimitedFailure com o Retry-After', () async {
      adapter.respond = (_) => jsonResponse(
        {'code': 'RATE_LIMITED', 'message': '...'},
        status: 429,
        headers: {
          'retry-after': ['7'],
        },
      );

      await expectLater(
        repository.getProfile(fulano),
        throwsA(
          isA<RateLimitedFailure>().having(
            (f) => f.retryAfter.inSeconds,
            'retryAfter',
            7,
          ),
        ),
      );
    });

    test('503 → UpstreamUnavailableFailure', () async {
      adapter.respond = (_) => jsonResponse({
        'code': 'UPSTREAM_UNAVAILABLE',
        'message': '...',
      }, status: 503);

      await expectFailure<UpstreamUnavailableFailure>();
    });

    test('sem conexão com o proxy → NetworkFailure', () async {
      adapter.respond = (options) => throw DioException.connectionError(
        requestOptions: options,
        reason: 'Connection refused',
      );

      await expectFailure<NetworkFailure>();
    });

    test('JSON com tipo errado → UnexpectedFailure', () async {
      final json = loadFixture('summoner_profile.json')..['level'] = '347';
      adapter.respond = (_) => jsonResponse(json);

      await expectFailure<UnexpectedFailure>();
    });

    test('tier desconhecido → UnexpectedFailure', () async {
      final json = loadFixture('summoner_profile.json');
      ((json['ranked'] as Map)['solo'] as Map)['tier'] = 'MYTHIC';
      adapter.respond = (_) => jsonResponse(json);

      await expectFailure<UnexpectedFailure>();
    });
  });

  group('cache offline (network-first com fallback)', () {
    void respondWithProfile() =>
        adapter.respond = (_) =>
            jsonResponse(loadFixture('summoner_profile.json'));

    void failWith(ResponseBody Function() response) =>
        adapter.respond = (_) => response();

    void dropConnection() => adapter.respond = (options) =>
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'Connection refused',
        );

    test('sem conexão, com cópia salva: devolve a cópia e o motivo', () async {
      respondWithProfile();
      await repository.getProfile(fulano); // salva a cópia

      dropConnection();
      final result = await repository.getProfile(fulano);

      expect(result.isStale, isTrue);
      expect(result.staleBecause, isA<NetworkFailure>());
      expect(result.profile.ranked!.solo!.tier, Tier.gold);
    });

    test('a cópia é achada com outra caixa (mesma regra do ==)', () async {
      respondWithProfile();
      await repository.getProfile(fulano);

      dropConnection();
      final result = await repository.getProfile(const RiotId('fulano', 'br1'));

      expect(result.isStale, isTrue);
    });

    test('rate limit, com cópia: devolve a cópia', () async {
      respondWithProfile();
      await repository.getProfile(fulano);

      failWith(
        () => jsonResponse({
          'code': 'RATE_LIMITED',
          'message': '...',
        }, status: 429),
      );
      final result = await repository.getProfile(fulano);

      expect(result.staleBecause, isA<RateLimitedFailure>());
    });

    test('"jogador não existe" NÃO usa a cópia', () async {
      respondWithProfile();
      await repository.getProfile(fulano);

      failWith(
        () => jsonResponse({
          'code': 'SUMMONER_NOT_FOUND',
          'message': '...',
        }, status: 404),
      );

      await expectLater(
        repository.getProfile(fulano),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('sem conexão e sem cópia: o erro original chega à tela', () async {
      dropConnection();

      await expectLater(
        repository.getProfile(fulano),
        throwsA(isA<NetworkFailure>()),
      );
    });
    test('perfil que não vira entidade NÃO vai para o cache', () async {
      final json = loadFixture('summoner_profile.json');
      ((json['ranked'] as Map)['solo'] as Map)['tier'] = 'MYTHIC';
      adapter.respond = (_) => jsonResponse(json);
      await expectLater(
        repository.getProfile(fulano),
        throwsA(isA<UnexpectedFailure>()),
      );

      dropConnection();

      // Se a cópia inválida tivesse sido salva, viria aqui como "stale".
      await expectLater(
        repository.getProfile(fulano),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
