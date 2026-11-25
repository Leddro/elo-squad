import 'package:dio/dio.dart';

import '../network/dio_error_mapper.dart';
import 'failure.dart';

/// Executa [body] e garante que SÓ [Failure] escape dele.
///
/// É a fronteira da camada data, reaproveitada por todos os repositórios:
/// - erro do Dio (rede, HTTP) → a Failure certa (tratamento centralizado);
/// - Failure → passa adiante como está;
/// - qualquer outra coisa (JSON fora do formato, enum desconhecido, erro do
///   banco local...) → [UnexpectedFailure].
///
/// `Error.throwWithStackTrace` preserva o stack trace ORIGINAL: no log, você vê
/// a linha que quebrou de verdade, e não esta função.
Future<T> guardFailures<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on DioException catch (e, stackTrace) {
    Error.throwWithStackTrace(failureFromDioException(e), stackTrace);
  } on Failure {
    rethrow;
  } catch (e, stackTrace) {
    Error.throwWithStackTrace(UnexpectedFailure(e), stackTrace);
  }
}
