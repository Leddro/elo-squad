import 'package:dio/dio.dart';
import 'package:elo_squad/core/error/failure.dart';
import 'package:elo_squad/core/network/dio_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

final _request = RequestOptions(path: '/summoner/Fulano/BR1');

DioException _error(DioExceptionType type) =>
    DioException(requestOptions: _request, type: type);

DioException _response(int status, Object? body, {String? retryAfter}) =>
    DioException(
      requestOptions: _request,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: _request,
        statusCode: status,
        data: body,
        headers: Headers.fromMap({
          if (retryAfter != null) 'retry-after': [retryAfter],
        }),
      ),
    );

void main() {
  group('falhas de conexão viram NetworkFailure', () {
    const tipos = [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.transformTimeout,
      DioExceptionType.connectionError,
    ];

    for (final tipo in tipos) {
      test(tipo.name, () {
        expect(failureFromDioException(_error(tipo)), isA<NetworkFailure>());
      });
    }
  });

  group('outros tipos viram UnexpectedFailure', () {
    const tipos = [
      DioExceptionType.badCertificate,
      DioExceptionType.cancel,
      DioExceptionType.unknown,
    ];

    for (final tipo in tipos) {
      test(tipo.name, () {
        expect(failureFromDioException(_error(tipo)), isA<UnexpectedFailure>());
      });
    }
  });

  group('respostas de erro do proxy (decididas pelo `code`)', () {
    test('404 SUMMONER_NOT_FOUND → NotFoundFailure', () {
      final failure = failureFromDioException(
        _response(404, {'code': 'SUMMONER_NOT_FOUND', 'message': '...'}),
      );

      expect(failure, isA<NotFoundFailure>());
    });

    test('404 sem `code` (rota errada, bug nosso) → UnexpectedFailure', () {
      final failure = failureFromDioException(
        _response(404, {'detail': 'Not Found'}),
      );

      expect(failure, isA<UnexpectedFailure>());
    });

    test('429 RATE_LIMITED lê o Retry-After', () {
      final failure = failureFromDioException(
        _response(429, {'code': 'RATE_LIMITED'}, retryAfter: '7'),
      );

      expect(
        failure,
        isA<RateLimitedFailure>().having(
          (f) => f.retryAfter,
          'retryAfter',
          const Duration(seconds: 7),
        ),
      );
    });

    test('429 sem Retry-After espera 1s', () {
      final failure = failureFromDioException(
        _response(429, {'code': 'RATE_LIMITED'}),
      );

      expect(
        (failure as RateLimitedFailure).retryAfter,
        const Duration(seconds: 1),
      );
    });

    test('503 UPSTREAM_UNAVAILABLE → UpstreamUnavailableFailure', () {
      final failure = failureFromDioException(
        _response(503, {'code': 'UPSTREAM_UNAVAILABLE'}),
      );

      expect(failure, isA<UpstreamUnavailableFailure>());
    });

    test('500 com corpo em texto (não JSON) → UnexpectedFailure', () {
      final failure = failureFromDioException(
        _response(500, 'Internal Server Error'),
      );

      expect(failure, isA<UnexpectedFailure>());
    });
  });
}
