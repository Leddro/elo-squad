import '../entities/app_user.dart';

abstract interface class AuthRepository {
  /// Emite o usuário atual na hora e a cada login/logout (null = deslogado).
  Stream<AppUser?> authStateChanges();

  /// Login com a conta Google. Devolve false se o usuário cancelou.
  /// Lança SOMENTE `Failure` (`core/error`).
  Future<bool> signInWithGoogle();

  Future<void> signOut();

  /// Token de ID do Firebase, enviado ao proxy para provar quem é o usuário.
  /// null = ninguém logado.
  Future<String?> idToken();
}
