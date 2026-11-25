import 'dart:async';

import 'package:elo_squad/features/auth/domain/entities/app_user.dart';
import 'package:elo_squad/features/auth/domain/repositories/auth_repository.dart';

const testUser = AppUser(
  uid: 'uid-1',
  displayName: 'Jogador',
  email: 'jogador@example.com',
  photoUrl: null,
);

/// FAKE do login: o teste decide se começa logado e o que o login faz.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? signedInAs}) : _user = signedInAs;

  AppUser? _user;
  final _changes = StreamController<AppUser?>.broadcast();

  /// Por padrão o login dá certo. O teste pode trocar (cancelar, falhar).
  Future<bool> Function() onSignIn = () async => true;

  void _set(AppUser? user) {
    _user = user;
    _changes.add(user);
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  Future<bool> signInWithGoogle() async {
    final ok = await onSignIn();
    if (ok) _set(testUser);
    return ok;
  }

  @override
  Future<void> signOut() async {
    onSignOut?.call();
    _set(null);
  }

  /// Para o teste saber QUANDO o logout aconteceu.
  void Function()? onSignOut;

  @override
  Future<String?> idToken() async =>
      _user == null ? null : 'token-${_user!.uid}';
}
