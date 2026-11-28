import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../summoner/domain/entities/ranked.dart';
import '../../../summoner/domain/entities/riot_id.dart';

part 'squad_ranking.freezed.dart';

/// O ranking de um squad num período: PDL ganho na Solo/Duo + bônus das
/// vitórias com Ciências.
@freezed
abstract class SquadRanking with _$SquadRanking {
  const factory SquadRanking({
    required String periodId,
    required DateTime startsAt,
    required DateTime endsAt,
    required DateTime updatedAt,

    /// true quando o período já acabou (resultado final).
    required bool isFinal,

    /// Do maior para o menor número de pontos; sem ranque no fim.
    required List<RankingEntry> entries,
  }) = _SquadRanking;
}

@freezed
abstract class RankingEntry with _$RankingEntry {
  const factory RankingEntry({
    required String uid,
    required String? displayName,
    required RiotId riotId,
    required String? profileIconUrl,

    /// Elo atual (null = sem ranque na Solo/Duo).
    required RankedEntry? current,

    /// PDL ganho no período (null = sem ranque no começo ou agora).
    required int? lpDelta,

    /// Partidas Solo/Duo no período.
    required int games,

    /// Pontos extras das vitórias com Ciências.
    @Default(0) int bonus,

    /// PDL + bônus (null = sem ranque).
    int? points,

    @Default([]) List<ScienceWin> scienceWins,
  }) = _RankingEntry;
}

/// Uma vitória com Ciência que valeu pontos extras.
@freezed
abstract class ScienceWin with _$ScienceWin {
  const factory ScienceWin({
    required String matchId,
    required DateTime playedAt,
    required String championName,
    required String title,
    required String tier,
    required int bonus,
  }) = _ScienceWin;
}
