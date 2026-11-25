import 'package:dio/dio.dart';

import '../error/failure.dart';

/// Tratamento de erros CENTRALIZADO: traduz qualquer erro do Dio para a
/// [Failure] certa. Todo repositório do app usa esta mesma função.
///
/// Por que uma função e não um interceptor? O Dio SEMPRE entrega um
/// `DioException` a quem chamou, mesmo que um interceptor tente lançar outra
/// coisa. Então a tradução para Failure precisa acontecer depois, no
/// repositório. Uma função pura também é trivial de testar.
Failure failureFromDioException(DioException e) {
  return switch (e.type) {
    // O celular não conseguiu falar com o proxy.
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout || // demorou para decodificar a resposta
    DioExceptionType.connectionError => const NetworkFailure(),

    // O proxy respondeu com status de erro (4xx/5xx).
    DioExceptionType.badResponse => _fromResponse(e.response),

    // Certificado inválido, requisição cancelada ou erro desconhecido.
    DioExceptionType.badCertificate ||
    DioExceptionType.cancel ||
    DioExceptionType.unknown => UnexpectedFailure(e),
  };
}

/// Decide pelo `code` do corpo (o contrato do proxy), e não só pelo status.
///
/// Exemplo do porquê: um 404 pode ser "jogador não existe"
/// (`{"code": "SUMMONER_NOT_FOUND"}`) ou "rota errada" (`{"detail": "Not Found"}`,
/// um bug nosso). Pelo status, os dois seriam "jogador não encontrado".
Failure _fromResponse(Response<dynamic>? response) {
  final body = response?.data;
  final code = body is Map ? body['code'] : null;

  return switch (code) {
    'SUMMONER_NOT_FOUND' => const NotFoundFailure(),
    'RATE_LIMITED' => RateLimitedFailure(retryAfter: _retryAfter(response)),
    'UPSTREAM_UNAVAILABLE' => const UpstreamUnavailableFailure(),
    'UNAUTHENTICATED' => const UnauthenticatedFailure(),
    'RIOT_ID_REQUIRED' => const SquadFailure(SquadProblem.riotIdRequired),
    'SQUAD_NOT_FOUND' => const SquadFailure(SquadProblem.notFound),
    'SQUAD_FULL' => const SquadFailure(SquadProblem.full),
    'SQUAD_LIMIT' => const SquadFailure(SquadProblem.limit),
    _ => UnexpectedFailure('HTTP ${response?.statusCode}: $body'),
  };
}

/// Lê o cabeçalho Retry-After (em segundos). Sem ele, espera 1s.
Duration _retryAfter(Response<dynamic>? response) {
  final value = response?.headers.value('retry-after');
  return Duration(seconds: int.tryParse(value ?? '') ?? 1);
}
