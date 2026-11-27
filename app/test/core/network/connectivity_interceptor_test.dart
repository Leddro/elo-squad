import 'package:dio/dio.dart';
import 'package:elo_squad/core/error/failure.dart';
import 'package:elo_squad/core/network/dio_client.dart';
import 'package:elo_squad/core/network/dio_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';

void main() {
  Future<Failure> failWith({required bool offline}) async {
    final dio =
        createDio(baseUrl: 'http://proxy', isOffline: () async => offline)
          ..httpClientAdapter = (FakeHttpAdapter()
            ..respond = (options) => throw DioException.connectionError(
              requestOptions: options,
              reason: 'recusada',
            ));
    try {
      await dio.get<void>('/health');
    } on DioException catch (e) {
      return failureFromDioException(e);
    }
    fail('deveria ter falhado');
  }

  test('sem rede no aparelho: NoConnectionFailure', () async {
    expect(await failWith(offline: true), isA<NoConnectionFailure>());
  });

  test('com rede, proxy fora: ServerUnreachableFailure', () async {
    expect(await failWith(offline: false), isA<ServerUnreachableFailure>());
  });
}
