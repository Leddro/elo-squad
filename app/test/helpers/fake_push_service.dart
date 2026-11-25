import 'dart:async';

import 'package:elo_squad/features/notifications/push_service.dart';

/// FAKE do push: conta os registros e deixa o teste "entregar" notificações.
class FakePushService implements PushService {
  int registerCalls = 0;
  final _foreground = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<String>.broadcast();

  void receive(PushMessage message) => _foreground.add(message);
  void tap(String squadId) => _opened.add(squadId);

  @override
  Future<void> register() async => registerCalls++;

  @override
  Stream<PushMessage> get foreground => _foreground.stream;

  @override
  Stream<String> get openedSquads => _opened.stream;
}
