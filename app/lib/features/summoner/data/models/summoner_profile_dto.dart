import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/mastery.dart';
import '../../domain/entities/ranked.dart';
import '../../domain/entities/riot_id.dart';
import '../../domain/entities/summoner_profile.dart';
import '../../domain/entities/tier.dart';

// Dois arquivos gerados: o do freezed (==, copyWith...) e o do
// json_serializable (fromJson/toJson).
part 'summoner_profile_dto.freezed.dart';
part 'summoner_profile_dto.g.dart';

// DTOs (Data Transfer Objects): espelham o JSON do proxy, campo a campo e com
// o mesmo aninhamento. Cada um sabe virar entidade (`toEntity`).
//
// O fromJson é GERADO pelo json_serializable a partir dos nomes e tipos dos
// campos. Se o JSON vier diferente do esperado, o código gerado lança
// TypeError, e o repositório transforma isso em Failure.

typedef Json = Map<String, dynamic>;

@freezed
abstract class SummonerProfileDto with _$SummonerProfileDto {
  const SummonerProfileDto._(); // para o método toEntity

  const factory SummonerProfileDto({
    required RiotIdDto riotId,
    required String puuid,
    required int level,
    required String? profileIconUrl,
    required RankedDto? ranked,
    required List<MasteryDto>? topMasteries,
    required DateTime fetchedAt, // o gerador converte o texto ISO 8601
    // O campo `unavailable` do JSON não é lido: o proxy já manda `null` nas
    // seções que falharam, e no domínio a nulidade carrega essa informação.
  }) = _SummonerProfileDto;

  factory SummonerProfileDto.fromJson(Json json) =>
      _$SummonerProfileDtoFromJson(json);

  SummonerProfile toEntity() => SummonerProfile(
    riotId: riotId.toEntity(),
    puuid: puuid,
    level: level,
    profileIconUrl: profileIconUrl,
    ranked: ranked?.toEntity(),
    topMasteries: topMasteries?.map((m) => m.toEntity()).toList(),
    fetchedAt: fetchedAt,
  );
}

@freezed
abstract class RiotIdDto with _$RiotIdDto {
  const RiotIdDto._();

  const factory RiotIdDto({required String gameName, required String tagLine}) =
      _RiotIdDto;

  factory RiotIdDto.fromJson(Json json) => _$RiotIdDtoFromJson(json);

  RiotId toEntity() => RiotId(gameName, tagLine);
}

@freezed
abstract class RankedDto with _$RankedDto {
  const RankedDto._();

  const factory RankedDto({RankedEntryDto? solo, RankedEntryDto? flex}) =
      _RankedDto;

  factory RankedDto.fromJson(Json json) => _$RankedDtoFromJson(json);

  Ranked toEntity() => Ranked(solo: solo?.toEntity(), flex: flex?.toEntity());
}

@freezed
abstract class RankedEntryDto with _$RankedEntryDto {
  const RankedEntryDto._();

  const factory RankedEntryDto({
    required String tier, // "GOLD": texto, como no JSON
    required String division, // "II"
    required int lp,
    required int wins,
    required int losses,
  }) = _RankedEntryDto;

  factory RankedEntryDto.fromJson(Json json) => _$RankedEntryDtoFromJson(json);

  /// Texto → enum. `byName` lança ArgumentError para um valor desconhecido
  /// (ex.: a Riot cria um tier novo), e o repositório vira UnexpectedFailure.
  RankedEntry toEntity() => RankedEntry(
    tier: Tier.values.byName(tier.toLowerCase()), // "GOLD" → Tier.gold
    division: Division.values.byName(division.toLowerCase()), // "II" → .ii
    lp: lp,
    wins: wins,
    losses: losses,
  );
}

@freezed
abstract class MasteryDto with _$MasteryDto {
  const MasteryDto._();

  const factory MasteryDto({
    required int championId,
    required String? championName,
    required String? championIconUrl,
    required int level,
    required int points,
  }) = _MasteryDto;

  factory MasteryDto.fromJson(Json json) => _$MasteryDtoFromJson(json);

  Mastery toEntity() => Mastery(
    championId: championId,
    championName: championName,
    championIconUrl: championIconUrl,
    level: level,
    points: points,
  );
}
