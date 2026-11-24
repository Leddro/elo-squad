import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elo_squad/core/error/failure.dart';
import 'package:elo_squad/features/summoner/data/datasources/summoner_remote_data_source.dart';
import 'package:elo_squad/features/summoner/data/repositories/summoner_repository_impl.dart';
import 'package:elo_squad/features/summoner/domain/entities/riot_id.dart';
import 'package:elo_squad/features/summoner/domain/entities/tier.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';

/// FAKE (não mock): uma implementação simplificada, mas funcional, do
/// "motor de rede" do Dio. Em vez de abrir uma conexão, devolve a resposta
/// que o teste mandar. Todo o resto do Dio (status, JSON, exceções) roda de
/// verdade, então estes testes cobrem datasource + mapper + repositório juntos.
class FakeHttpAdapter implements HttpClientAdapter {
  ResponseBody Function(RequestOptions options) respond = (_) =>
      throw StateError('Configure `respond` no teste');
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(
  Object body, {
  int status = 200,
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...headers,
  },
);

void main() {
  late FakeHttpAdapter adapter;
  late SummonerRepositoryImpl repository;
  const fulano = RiotId('Fulano', 'BR1');

  setUp(() {
    adapter = FakeHttpAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://proxy.test'))
      ..httpClientAdapter = adapter;
    repository = SummonerRepositoryImpl(SummonerRemoteDataSource(dio));
  });

  test('sucesso: devolve a entidade convertida', () async {
    adapter.respond = (_) => jsonResponse(loadFixture('summoner_profile.json'));

    final profile = await repository.getProfile(fulano);

    expect(profile.riotId, fulano);
    expect(profile.ranked!.solo!.tier, Tier.gold);
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
}
