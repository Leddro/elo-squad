import '../error/failure.dart';

/// Mensagem CURTA para um erro, para avisos dentro de uma tela que continua
/// funcionando (a seção de partidas, o aviso de perfil salvo). A tela de erro
/// grande, de página inteira, é a FailureView.
String shortFailureMessage(Object error) {
  final failure = error is Failure ? error : UnexpectedFailure(error);
  // Exaustivo e sem curinga, como na FailureView.
  return switch (failure) {
    NetworkFailure() => 'Sem conexão. Verifique sua internet.',
    RateLimitedFailure(:final retryAfter) =>
      'Muitas requisições. Aguarde ${retryAfter.inSeconds}s.',
    UpstreamUnavailableFailure() => 'Os servidores da Riot não responderam.',
    NotFoundFailure() => 'Não encontrado.',
    UnauthenticatedFailure() => 'Sua sessão expirou. Entre de novo.',
    SquadFailure(:final problem) => switch (problem) {
      SquadProblem.riotIdRequired => 'Vincule o seu Riot ID primeiro.',
      SquadProblem.notFound => 'Código de convite inválido.',
      SquadProblem.full => 'Este squad já está cheio.',
      SquadProblem.limit => 'Você já está no número máximo de squads.',
    },
    UnexpectedFailure() => 'Algo deu errado.',
  };
}
