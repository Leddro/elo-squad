import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/error/failure.dart';
import '../domain/entities/app_user.dart';
import '../domain/repositories/auth_repository.dart';

/// Login com Google: o google_sign_in pega a conta no aparelho (Credential
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
  Stream<AppUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toAppUser);

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
      final failure = e.code == 'network-request-failed'
          ? const NetworkFailure()
          : UnexpectedFailure(e);
      Error.throwWithStackTrace(failure, stackTrace);
    }
  }

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
