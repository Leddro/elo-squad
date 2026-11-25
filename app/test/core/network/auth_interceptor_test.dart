import 'package:dio/dio.dart';
import 'package:elo_squad/core/network/auth_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_http.dart';

void main() {
  late FakeHttpAdapter adapter;

  Dio dioWith(Future<String?> Function() token) =>
      Dio(BaseOptions(baseUrl: 'http://proxy.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(token));

  setUp(() {
    adapter = FakeHttpAdapter()..respond = (_) => jsonResponse({'ok': true});
  });

  test('logado: manda o token no cabeçalho Authorization', () async {
    await dioWith(() async => 'abc').get<dynamic>('/x');

    expect(adapter.requests.single.headers['Authorization'], 'Bearer abc');
  });

  test('deslogado: segue sem o cabeçalho', () async {
    await dioWith(() async => null).get<dynamic>('/x');

    expect(adapter.requests.single.headers, isNot(contains('Authorization')));
  });

  test('erro ao pegar o token: segue sem o cabeçalho', () async {
    await dioWith(() async => throw StateError('offline')).get<dynamic>('/x');

    expect(adapter.requests.single.headers, isNot(contains('Authorization')));
  });
}
