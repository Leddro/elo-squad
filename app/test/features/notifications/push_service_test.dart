// O FcmPushService usa a API clássica de token (getToken/deleteToken).
// ignore_for_file: deprecated_member_use

import 'package:dio/dio.dart';
import 'package:elo_squad/features/notifications/push_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_http.dart';

class MockMessaging extends Mock implements FirebaseMessaging {}

class MockSettings extends Mock implements NotificationSettings {}

void main() {
  late MockMessaging messaging;
  late FakeHttpAdapter http;
  late FcmPushService push;

  setUp(() {
    messaging = MockMessaging();
    final settings = MockSettings();
    when(() => settings.authorizationStatus)
        .thenReturn(AuthorizationStatus.authorized);
    when(() => messaging.requestPermission()).thenAnswer((_) async => settings);
    when(() => messaging.getToken()).thenAnswer((_) async => 'tok:en-1');
    when(() => messaging.onTokenRefresh)
        .thenAnswer((_) => const Stream.empty());
    when(() => messaging.deleteToken()).thenAnswer((_) async {});

    http = FakeHttpAdapter()..respond = (_) => ResponseBody.fromString('', 204);
    push = FcmPushService(
      messaging,
      Dio(BaseOptions(baseUrl: 'http://proxy'))..httpClientAdapter = http,
    );
  });

  test('logout remove o token no proxy e descarta o token local', () async {
    await push.register();
    await push.unregister();

    expect(http.requests.map((r) => '${r.method} ${r.path}'), [
      'POST /me/fcm-tokens',
      'DELETE /me/fcm-tokens/tok%3Aen-1',
    ]);
    verify(() => messaging.deleteToken()).called(1);
  });

  test('sem rede: o logout segue e o token local é descartado', () async {
    await push.register();
    http.respond = (options) => throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline',
    );

    await push.unregister(); // não lança

    verify(() => messaging.deleteToken()).called(1);
  });

  test('nunca registrou (sem permissão): não chama nada', () async {
    await push.unregister();

    expect(http.requests, isEmpty);
    verifyNever(() => messaging.deleteToken());
  });
}
