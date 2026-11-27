import 'dart:async';

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
  late StreamController<String> registered;

  setUp(() {
    registered = StreamController<String>.broadcast();
    messaging = MockMessaging();
    final settings = MockSettings();
    when(() => settings.authorizationStatus)
        .thenReturn(AuthorizationStatus.authorized);
    when(() => messaging.requestPermission()).thenAnswer((_) async => settings);
    when(() => messaging.onRegistered).thenAnswer((_) => registered.stream);
    when(() => messaging.register()).thenAnswer((_) async {});
    when(() => messaging.unregister()).thenAnswer((_) async {});

    http = FakeHttpAdapter()..respond = (_) => ResponseBody.fromString('', 204);
    push = FcmPushService(
      messaging,
      Dio(BaseOptions(baseUrl: 'http://proxy'))..httpClientAdapter = http,
      installationId: () async => 'fid/1',
    );
  });

  test('logout remove o ID no proxy e cancela o registro local', () async {
    await push.register();
    await push.unregister();

    expect(http.requests.map((r) => '${r.method} ${r.path}'), [
      'POST /me/fcm-tokens',
      'DELETE /me/fcm-tokens/fid%2F1',
    ]);
    verify(() => messaging.unregister()).called(1);
  });

  test('sem rede: o logout segue e o registro local é cancelado', () async {
    await push.register();
    http.respond = (options) => throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline',
    );

    await push.unregister(); // não lança

    verify(() => messaging.unregister()).called(1);
  });

  test('nunca registrou (sem permissão): não chama nada', () async {
    await push.unregister();

    expect(http.requests, isEmpty);
    verifyNever(() => messaging.unregister());
  });

  test('manda o ID uma vez e de novo quando o FCM troca', () async {
    await push.register();
    registered.add('fid/1'); // o mesmo do pedido direto: não reenvia
    registered.add('fid/2');
    await pumpEventQueue();

    expect(http.requests.map((r) => (r.data as Map)['token']), [
      'fid/1',
      'fid/2',
    ]);
  });
}
