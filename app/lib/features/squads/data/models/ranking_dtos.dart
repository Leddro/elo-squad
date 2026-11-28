import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/network/json.dart';
// Sem `show`: o código gerado também usa os $...CopyWith desses DTOs.
import '../../../summoner/data/models/summoner_profile_dto.dart';
import '../../domain/entities/squad_ranking.dart';

part 'ranking_dtos.freezed.dart';
part 'ranking_dtos.g.dart';

/// Datas do Firestore chegam como `Timestamp`, e não como texto ISO.
class TimestampConverter implements JsonConverter<DateTime, Object> {
  const TimestampConverter();

  @override
  DateTime fromJson(Object json) => switch (json) {
    Timestamp() => json.toDate().toUtc(),
    DateTime() => json.toUtc(),
    String() => DateTime.parse(json).toUtc(),
    _ => throw FormatException('Data inválida: $json'),
  };

  @override
  Object toJson(DateTime date) => Timestamp.fromDate(date);
}

/// Documento squads/{id}/rankings/{periodId}, gravado pelo proxy.
@freezed
abstract class SquadRankingDto with _$SquadRankingDto {
  const SquadRankingDto._();

  const factory SquadRankingDto({
    required String periodId,
    @TimestampConverter() required DateTime startsAt,
    @TimestampConverter() required DateTime endsAt,
    @TimestampConverter() required DateTime updatedAt,
    required bool finalResult,
    required List<RankingEntryDto> entries,
  }) = _SquadRankingDto;

  /// O campo no JSON chama `final` (palavra reservada no Dart): renomeado aqui.
  factory SquadRankingDto.fromJson(Json json) =>
      _$SquadRankingDtoFromJson({...json, 'finalResult': json['final']});

  SquadRanking toEntity() => SquadRanking(
    periodId: periodId,
    startsAt: startsAt,
    endsAt: endsAt,
    updatedAt: updatedAt,
    isFinal: finalResult,
    entries: [for (final e in entries) e.toEntity()],
  );
}

@freezed
abstract class RankingEntryDto with _$RankingEntryDto {
  const RankingEntryDto._();

  const factory RankingEntryDto({
    required String uid,
    String? displayName,
    required RiotIdDto riotId,
    String? profileIconUrl,
    RankedEntryDto? current,
    int? lpDelta,
    required int games,
    @Default(0) int bonus,
    int? points,
    @Default([]) List<ScienceWinDto> scienceWins,
  }) = _RankingEntryDto;

  factory RankingEntryDto.fromJson(Json json) =>
      _$RankingEntryDtoFromJson(json);

  RankingEntry toEntity() => RankingEntry(
    uid: uid,
    displayName: displayName,
    riotId: riotId.toEntity(),
    profileIconUrl: profileIconUrl,
    current: current?.toEntity(),
    lpDelta: lpDelta,
    games: games,
    bonus: bonus,
    // Documento antigo (sem pontos): os pontos são o PDL.
    points: points ?? lpDelta,
    scienceWins: [for (final w in scienceWins) w.toEntity()],
  );
}

@freezed
abstract class ScienceWinDto with _$ScienceWinDto {
  const ScienceWinDto._();

  const factory ScienceWinDto({
    required String matchId,
    @TimestampConverter() required DateTime playedAt,
    required String championName,
    required String title,
    required String tier,
    required int bonus,
  }) = _ScienceWinDto;

  factory ScienceWinDto.fromJson(Json json) => _$ScienceWinDtoFromJson(json);

  ScienceWin toEntity() => ScienceWin(
    matchId: matchId,
    playedAt: playedAt,
    championName: championName,
    title: title,
    tier: tier,
    bonus: bonus,
  );
}
