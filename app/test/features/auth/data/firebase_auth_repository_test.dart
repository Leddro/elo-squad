import 'package:elo_squad/core/error/failure.dart';
import 'package:elo_squad/features/auth/data/firebase_auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

class MockAuth extends Mock implements FirebaseAuth {}

class MockGoogle extends Mock implements GoogleSignIn {}

void main() {
  late MockAuth auth;
  late FirebaseAuthRepository repository;

  setUp(() {
    auth = MockAuth();
    repository = FirebaseAuthRepository(auth, MockGoogle());
  });

  void firebaseFails(String code) => when(
    () => auth.signInWithEmailAndPassword(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenThrow(FirebaseAuthException(code: code));

  final cases = {
    'invalid-credential': const AuthFailure(AuthProblem.invalidCredentials),
    'wrong-password': const AuthFailure(AuthProblem.invalidCredentials),
    'invalid-email': const AuthFailure(AuthProblem.invalidEmail),
    'too-many-requests': const AuthFailure(AuthProblem.tooManyAttempts),
  };
  for (final MapEntry(key: code, value: expected) in cases.entries) {
    test('Firebase "$code" vira $expected', () {
      firebaseFails(code);
      expect(
        repository.signInWithEmail(email: 'a@b.c', password: 'x'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.problem,
            'problem',
            expected.problem,
          ),
        ),
      );
    });
  }

  test('sem rede vira NetworkFailure', () {
    firebaseFails('network-request-failed');
    expect(
      repository.signInWithEmail(email: 'a@b.c', password: 'x'),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('código desconhecido vira UnexpectedFailure', () {
    firebaseFails('algo-novo');
    expect(
      repository.signInWithEmail(email: 'a@b.c', password: 'x'),
      throwsA(isA<UnexpectedFailure>()),
    );
  });
}
