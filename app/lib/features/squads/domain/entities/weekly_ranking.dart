import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../summoner/domain/entities/ranked.dart';
import '../../../summoner/domain/entities/riot_id.dart';

part 'weekly_ranking.freezed.dart';

/// O ranking da semana de um squad: PDL ganho na Solo/Duo desde segunda.
@freezed
abstract class WeeklyRanking with _$WeeklyRanking {
  const factory WeeklyRanking({
    required String weekId, // "2026-W48"
    required DateTime weekStart,
    required DateTime updatedAt,

    /// true quando a semana já acabou (resultado final).
    required bool isFinal,

    /// Do maior para o menor PDL ganho; sem ranque no fim.
    required List<RankingEntry> entries,
  }) = _WeeklyRanking;
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

    /// PDL ganho na semana (null = sem ranque no começo ou agora).
    required int? lpDelta,

    /// Partidas Solo/Duo na semana.
    required int games,
  }) = _RankingEntry;
}
