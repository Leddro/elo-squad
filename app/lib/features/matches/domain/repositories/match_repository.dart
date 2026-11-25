import '../entities/match_history.dart';

/// Contrato do histórico de partidas, no padrão FONTE ÚNICA DA VERDADE
/// (single source of truth): a tela só LÊ do banco local, e a rede só ESCREVE
/// no banco.
///
///   proxy ──refresh/loadMore──▶ banco local ──watchHistory──▶ tela
///
/// Por isso [refresh] e [loadMore] devolvem `Future<void>`: o resultado não
/// volta por eles, e sim pelo [watchHistory], que emite de novo a cada escrita.
/// Sem internet, a tela continua mostrando o que já estava salvo.
abstract interface class MatchRepository {
  /// O histórico salvo de [puuid]. Emite na hora e a cada mudança no banco.
  Stream<MatchHistory> watchHistory(String puuid);

  /// Busca as partidas mais recentes no proxy e grava no banco.
  ///
  /// Lança SOMENTE `Failure` (`core/error`). Se falhar, o que já estava
  /// salvo continua lá.
  Future<void> refresh(String puuid);

  /// Busca a próxima página (partidas mais antigas) e grava no banco.
  /// Não faz nada se o histórico já acabou ou se nunca houve um [refresh].
  ///
  /// Lança SOMENTE `Failure` (`core/error`).
  Future<void> loadMore(String puuid);
}
