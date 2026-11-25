import '../entities/app_user.dart';

abstract interface class AuthRepository {
  /// Emite o usuário atual na hora e a cada login/logout (null = deslogado).
  Stream<AppUser?> authStateChanges();

  /// Login com a conta Google. Devolve false se o usuário cancelou.
  /// Lança SOMENTE `Failure` (`core/error`).
  Future<bool> signInWithGoogle();

  /// Lança `AuthFailure` (credenciais erradas etc.) ou `NetworkFailure`.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  /// Cria a conta e já entra nela. [name] aparece para o squad.
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  });

  /// Manda o link de redefinir senha. Não diz se o e-mail tem conta
  /// (proteção contra descobrir e-mails cadastrados).
  Future<void> sendPasswordReset(String email);

  Future<void> signOut();

  /// Token de ID do Firebase, enviado ao proxy para provar quem é o usuário.
  /// null = ninguém logado.
  Future<String?> idToken();
}
