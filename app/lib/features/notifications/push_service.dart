import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';

/// Uma notificação recebida com o app aberto.
typedef PushMessage = ({String title, String body, String? squadId});

/// Notificações push (FCM): registro do aparelho e mensagens recebidas.
abstract interface class PushService {
  /// Pede permissão, manda o token do aparelho ao proxy e acompanha a troca
  /// de token. Nunca lança: sem permissão ou sem rede, o app segue sem push.
  Future<void> register();

  /// Notificações que chegam com o app ABERTO (o sistema não mostra nada
  /// sozinho nesse caso; o app mostra um aviso).
  Stream<PushMessage> get foreground;

  /// Squads das notificações tocadas pelo usuário (para abrir o squad).
  Stream<String> get openedSquads;
}

final class FcmPushService implements PushService {
  FcmPushService(this._messaging, this._dio);

  final FirebaseMessaging _messaging;
  final Dio _dio;
  StreamSubscription<String>? _tokenRefresh;

  @override
  Future<void> register() async {
    try {
      // Android 13+: mostra o pedido de permissão (uma vez).
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      // getToken/onTokenRefresh estão descontinuados no firebase_messaging 17
      // (a API nova, register/onRegistered, usa o Installation ID). O proxy
      // envia pelo token clássico do firebase-admin, que segue funcionando.
      // TODO: migrar quando o envio por Installation ID for confirmado no proxy.
      // ignore: deprecated_member_use
      final token = await _messaging.getToken();
      if (token != null) await _send(token);
      // ignore: deprecated_member_use
      _tokenRefresh ??= _messaging.onTokenRefresh.listen(_send);
    } on Object catch (error) {
      debugPrint('Push: registro falhou ($error)');
    }
  }

  Future<void> _send(String token) async {
    try {
      await _dio.post<void>('/me/fcm-tokens', data: {'token': token});
    } on Object catch (error) {
      debugPrint('Push: não consegui enviar o token ($error)');
    }
  }

  @override
  Stream<PushMessage> get foreground => FirebaseMessaging.onMessage.map(
    (m) => (
      title: m.notification?.title ?? 'Elo Squad',
      body: m.notification?.body ?? '',
      squadId: m.data['squadId'] as String?,
    ),
  );

  @override
  Stream<String> get openedSquads async* {
    // App aberto a partir de uma notificação (estava fechado)...
    final initial = await _messaging.getInitialMessage();
    if (initial?.data['squadId'] case final String id) yield id;
    // ...ou tocada com o app em segundo plano.
    yield* FirebaseMessaging.onMessageOpenedApp
        .map((m) => m.data['squadId'])
        .whereType<String>();
  }
}

final pushServiceProvider = Provider<PushService>(
  (ref) => FcmPushService(FirebaseMessaging.instance, ref.watch(dioProvider)),
);

extension<T> on Stream<T> {
  Stream<S> whereType<S>() => where((e) => e is S).cast<S>();
}
