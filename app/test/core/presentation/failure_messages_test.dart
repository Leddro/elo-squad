import 'package:elo_squad/core/error/failure.dart';
import 'package:elo_squad/core/presentation/failure_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shortFailureMessage: uma mensagem por Failure', () {
    expect(shortFailureMessage(const NetworkFailure()), contains('conexão'));
    expect(
      shortFailureMessage(
        const RateLimitedFailure(retryAfter: Duration(seconds: 7)),
      ),
      contains('7s'),
    );
    // Algo que não é Failure (um bug) também tem mensagem.
    expect(shortFailureMessage(StateError('bug')), 'Algo deu errado.');
  });
}
