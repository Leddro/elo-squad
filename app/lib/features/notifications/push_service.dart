import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';

/// Uma notificação recebida com o app aberto.
typedef PushMessage = ({String title, String body, String? squadId});

/// Notificações push (FCM): registro do aparelho e mensagens recebidas.
abstract interface class PushService {
  /// Pede permissão, registra o aparelho no FCM, manda o Installation ID ao
  /// proxy e acompanha a troca dele. Nunca lança: sem permissão ou sem rede, o app segue sem push.
  Future<void> register();

  /// Chamado ANTES do logout (ainda autenticado): desliga o aparelho da conta
  /// no proxy e cancela o registro local, para a próxima conta ganhar outro.
  /// Nunca lança: sem rede, o logout segue (o proxy limpa o token antigo
  /// quando o ID trocar de conta ou deixar de valer).
  Future<void> unregister();

  /// Notificações que chegam com o app ABERTO (o sistema não mostra nada
  /// sozinho nesse caso; o app mostra um aviso).
  Stream<PushMessage> get foreground;

  /// Squads das notificações tocadas pelo usuário (para abrir o squad).
  Stream<String> get openedSquads;
}

final class FcmPushService implements PushService {
  FcmPushService(this._messaging, this._dio, {required this.installationId});

  final FirebaseMessaging _messaging;
  final Dio _dio;

  /// Installation ID (FID) do app neste aparelho: o alvo do envio no FCM.
  final Future<String> Function() installationId;

  StreamSubscription<String>? _registered;
  String? _target; // o último ID enviado ao proxy

  @override
  Future<void> register() async {
    try {
      // Android 13+: mostra o pedido de permissão (uma vez).
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      // onRegistered avisa quando o FCM troca o ID; escuta antes de registrar.
      _registered ??= _messaging.onRegistered.listen(_send);
      await _messaging.register();
      // O evento pode ter saído antes de o Dart escutar (o Android guarda o
      // último): pedir o ID direto garante o envio.
      await _send(await installationId());
    } on Object catch (error) {
      debugPrint('Push: registro falhou ($error)');
    }
  }

  @override
  Future<void> unregister() async {
    await _registered?.cancel();
    _registered = null;
    final target = _target;
    _target = null;
    if (target == null) return; // nunca registrou (sem permissão, por ex.)

    try {
      await _dio
          .delete<void>('/me/fcm-tokens/${Uri.encodeComponent(target)}')
          .timeout(_unregisterTimeout);
    } on Object catch (error) {
      debugPrint('Push: não consegui remover o ID no proxy ($error)');
    }
    try {
      // O FCM para de entregar neste aparelho: mesmo que o proxy não tenha
      // sido avisado, o envio falha e o proxy apaga o ID.
      await _messaging.unregister().timeout(_unregisterTimeout);
    } on Object catch (error) {
      debugPrint('Push: não consegui cancelar o registro local ($error)');
    }
  }

  static const _unregisterTimeout = Duration(seconds: 5);

  Future<void> _send(String id) async {
    if (id == _target) return; // onRegistered e o pedido direto dão o mesmo
    try {
      await _dio.post<void>('/me/fcm-tokens', data: {'token': id});
      _target = id;
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
  (ref) => FcmPushService(
    FirebaseMessaging.instance,
    ref.watch(dioProvider),
    installationId: FirebaseInstallations.instance.getId,
  ),
);

extension<T> on Stream<T> {
  Stream<S> whereType<S>() => where((e) => e is S).cast<S>();
}
