import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/network/json.dart';
// Sem `show`: o código gerado também usa os $...CopyWith desses DTOs.
import '../../../summoner/data/models/summoner_profile_dto.dart';
import '../../domain/entities/weekly_ranking.dart';

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

/// Documento squads/{id}/rankings/{weekId}, gravado pelo proxy.
@freezed
abstract class WeeklyRankingDto with _$WeeklyRankingDto {
  const WeeklyRankingDto._();

  const factory WeeklyRankingDto({
    required String weekId,
    @TimestampConverter() required DateTime weekStart,
    @TimestampConverter() required DateTime updatedAt,
    required bool finalResult,
    required List<RankingEntryDto> entries,
  }) = _WeeklyRankingDto;

  /// O campo no JSON chama `final` (palavra reservada no Dart): renomeado aqui.
  factory WeeklyRankingDto.fromJson(Json json) =>
      _$WeeklyRankingDtoFromJson({...json, 'finalResult': json['final']});

  WeeklyRanking toEntity() => WeeklyRanking(
    weekId: weekId,
    weekStart: weekStart,
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
  );
}
