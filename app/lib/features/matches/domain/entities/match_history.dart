import 'package:freezed_annotation/freezed_annotation.dart';

import 'match_summary.dart';

part 'match_history.freezed.dart';

/// O histórico de partidas de um jogador, como está salvo no aparelho.
@freezed
abstract class MatchHistory with _$MatchHistory {
  const MatchHistory._();

  const factory MatchHistory({
    /// Da mais nova para a mais antiga, sem lacunas.
    required List<MatchSummary> matches,

    /// false quando a última página já chegou (não há partidas mais antigas).
    required bool hasMore,

    /// Quando a primeira página foi atualizada pela última vez.
    /// null = este jogador nunca foi buscado neste aparelho.
    required DateTime? refreshedAt,
  }) = _MatchHistory;

  /// Estado inicial de um jogador sem nada no cache.
  static const empty = MatchHistory(
    matches: [],
    hasMore: true,
    refreshedAt: null,
  );

  /// Nunca buscado: a tela mostra o esqueleto de carregamento. É diferente de
  /// "buscado e sem partidas", que mostra uma mensagem de lista vazia.
  bool get neverLoaded => refreshedAt == null;
}
