/// Todos os erros que o app sabe tratar.
///
/// `sealed`: o conjunto de subclasses é FECHADO (só as deste arquivo). Por isso
/// o compilador consegue exigir que um `switch` sobre [Failure] trate todas elas.
/// Se um dia surgir uma Failure nova, todo `switch` que esquecer dela vira erro
/// de compilação, e não um bug descoberto em produção.
///
/// Fica em `core/` porque é compartilhada por todas as features (perfil,
/// partidas, ranking...). É Dart puro, como o domain.
///
/// Sem mensagem de texto: o que mostrar ao usuário é decisão da presentation.
sealed class Failure implements Exception {
  const Failure();

  @override
  String toString() => '$runtimeType';
}

/// Riot ID não existe (ou não tem perfil no servidor). Tentar de novo não adianta.
final class NotFoundFailure extends Failure {
  const NotFoundFailure();
}

/// Sem internet, proxy fora do ar ou timeout: o celular não obteve resposta.
///
/// TODO(quando o proxy for publicado): separar em `NoConnectionFailure`
/// (aparelho offline: "verifique sua conexão") e `ServerUnreachableFailure`
/// (aparelho online, mas o proxy não respondeu: problema nosso). Na camada
/// data, usar `connectivity_plus` para distinguir os dois casos.
final class NetworkFailure extends Failure {
  const NetworkFailure();
}

/// Muitas buscas em pouco tempo. [retryAfter] diz quanto esperar.
final class RateLimitedFailure extends Failure {
  const RateLimitedFailure({required this.retryAfter});

  final Duration retryAfter;

  @override
  String toString() => 'RateLimitedFailure(retryAfter: $retryAfter)';
}

/// O proxy respondeu, mas a Riot está indisponível. Temporário.
final class UpstreamUnavailableFailure extends Failure {
  const UpstreamUnavailableFailure();
}

/// Qualquer coisa fora do previsto (resposta em formato errado, bug...).
/// [cause] guarda o erro original para log/debug.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([this.cause]);

  final Object? cause;

  @override
  String toString() => 'UnexpectedFailure($cause)';
}
