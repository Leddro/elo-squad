import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/error/failure.dart';
import '../domain/entities/app_user.dart';
import '../domain/repositories/auth_repository.dart';

/// Login com e-mail e senha (Firebase Auth direto) ou com Google: o google_sign_in pega a conta no aparelho (Credential
/// Manager) e o Firebase Auth troca o token do Google por uma sessão nossa.
final class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._google);

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  /// O google_sign_in 7 exige `initialize()` uma única vez antes de usar.
  /// No Android, o client ID vem do google-services.json (default_web_client_id).
  Future<void>? _initialization;
  Future<void> _ensureInitialized() => _initialization ??= _google.initialize();

  @override
  // userChanges (e não authStateChanges): emite também quando o nome muda,
  // logo depois do cadastro.
  Stream<AppUser?> authStateChanges() => _auth.userChanges().map(_toAppUser);

  @override
  Future<bool> signInWithGoogle() async {
    try {
      await _ensureInitialized();
      final account = await _google.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );
      await _auth.signInWithCredential(credential);
      return true;
    } on GoogleSignInException catch (e, stackTrace) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      Error.throwWithStackTrace(UnexpectedFailure(e), stackTrace);
    } on FirebaseAuthException catch (e, stackTrace) {
      Error.throwWithStackTrace(_toFailure(e), stackTrace);
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _guard(
    () => _auth.signInWithEmailAndPassword(email: email, password: password),
  );

  @override
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) => _guard(() async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = result.user!;
    await user.updateDisplayName(name);
    // Token novo, já com o nome: o proxy o usa ao pôr a pessoa num squad.
    await user.getIdToken(true);
  });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email));

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e, stackTrace) {
      Error.throwWithStackTrace(_toFailure(e), stackTrace);
    }
  }

  static Failure _toFailure(FirebaseAuthException e) => switch (e.code) {
    'network-request-failed' => const NoConnectionFailure(),
    // Com a proteção de enumeração de e-mails (padrão em projetos novos),
    // o Firebase responde invalid-credential; os outros dois são da versão antiga.
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'user-disabled' => const AuthFailure(AuthProblem.invalidCredentials),
    'email-already-in-use' => const AuthFailure(AuthProblem.emailInUse),
    'weak-password' => const AuthFailure(AuthProblem.weakPassword),
    'invalid-email' => const AuthFailure(AuthProblem.invalidEmail),
    'too-many-requests' => const AuthFailure(AuthProblem.tooManyAttempts),
    _ => UnexpectedFailure(e),
  };

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    // Os dois: sem o do Google, o próximo login entraria direto na mesma
    // conta, sem deixar escolher outra.
    await _google.signOut();
    await _auth.signOut();
  }

  @override
  Future<String?> idToken() async => _auth.currentUser?.getIdToken();

  static AppUser? _toAppUser(User? user) => user == null
      ? null
      : AppUser(
          uid: user.uid,
          displayName: user.displayName,
          email: user.email,
          photoUrl: user.photoURL,
        );
}
