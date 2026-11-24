import '../../domain/entities/mastery.dart';
import '../../domain/entities/ranked.dart';
import '../../domain/entities/riot_id.dart';
import '../../domain/entities/summoner_profile.dart';
import '../../domain/entities/tier.dart';

// DTOs (Data Transfer Objects): espelham o JSON do proxy, campo a campo.
// Cada um sabe se ler do JSON (`fromJson`) e virar entidade (`toEntity`).
//
// Por que não ler o JSON direto na entidade? Porque o formato da API e o
// formato do app mudam por motivos diferentes. Se o proxy mudar o JSON, só
// este arquivo muda; o domain e as telas nem ficam sabendo.
//
// fromJson escrito à mão nesta fase. Na fase 2, json_serializable + freezed
// vão GERAR este código. Os `as int`, `as String` abaixo lançam TypeError se o
// JSON vier diferente do esperado; o repositório transforma isso em Failure.

typedef Json = Map<String, dynamic>;

final class SummonerProfileDto {
  const SummonerProfileDto({
    required this.gameName,
    required this.tagLine,
    required this.puuid,
    required this.level,
    required this.profileIconUrl,
    required this.ranked,
    required this.topMasteries,
    required this.fetchedAt,
  });

  factory SummonerProfileDto.fromJson(Json json) {
    final riotId = json['riotId'] as Json;
    final ranked = json['ranked'] as Json?;
    final masteries = json['topMasteries'] as List<dynamic>?;

    return SummonerProfileDto(
      gameName: riotId['gameName'] as String,
      tagLine: riotId['tagLine'] as String,
      puuid: json['puuid'] as String,
      level: json['level'] as int,
      profileIconUrl: json['profileIconUrl'] as String?,
      ranked: ranked == null ? null : RankedDto.fromJson(ranked),
      topMasteries: masteries
          ?.map((m) => MasteryDto.fromJson(m as Json))
          .toList(),
      fetchedAt: json['fetchedAt'] as String,
    );
  }

  final String gameName;
  final String tagLine;
  final String puuid;
  final int level;
  final String? profileIconUrl;
  final RankedDto? ranked;
  final List<MasteryDto>? topMasteries;
  final String fetchedAt; // ISO 8601, como veio no JSON

  // O campo `unavailable` do JSON não é lido: o proxy já manda `null` nas
  // seções que falharam, e no domínio a nulidade é o que carrega essa informação.

  SummonerProfile toEntity() => SummonerProfile(
    riotId: RiotId(gameName, tagLine),
    puuid: puuid,
    level: level,
    profileIconUrl: profileIconUrl,
    ranked: ranked?.toEntity(),
    topMasteries: topMasteries?.map((m) => m.toEntity()).toList(),
    fetchedAt: DateTime.parse(fetchedAt),
  );
}

final class RankedDto {
  const RankedDto({required this.solo, required this.flex});

  factory RankedDto.fromJson(Json json) => RankedDto(
    solo: _entryOrNull(json['solo']),
    flex: _entryOrNull(json['flex']),
  );

  static RankedEntryDto? _entryOrNull(Object? json) =>
      json == null ? null : RankedEntryDto.fromJson(json as Json);

  final RankedEntryDto? solo;
  final RankedEntryDto? flex;

  Ranked toEntity() => Ranked(solo: solo?.toEntity(), flex: flex?.toEntity());
}

final class RankedEntryDto {
  const RankedEntryDto({
    required this.tier,
    required this.division,
    required this.lp,
    required this.wins,
    required this.losses,
  });

  factory RankedEntryDto.fromJson(Json json) => RankedEntryDto(
    tier: json['tier'] as String,
    division: json['division'] as String,
    lp: json['lp'] as int,
    wins: json['wins'] as int,
    losses: json['losses'] as int,
  );

  final String tier; // "GOLD": texto, como no JSON
  final String division; // "II"
  final int lp;
  final int wins;
  final int losses;

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

final class MasteryDto {
  const MasteryDto({
    required this.championId,
    required this.championName,
    required this.championIconUrl,
    required this.level,
    required this.points,
  });

  factory MasteryDto.fromJson(Json json) => MasteryDto(
    championId: json['championId'] as int,
    championName: json['championName'] as String?,
    championIconUrl: json['championIconUrl'] as String?,
    level: json['level'] as int,
    points: json['points'] as int,
  );

  final int championId;
  final String? championName;
  final String? championIconUrl;
  final int level;
  final int points;

  Mastery toEntity() => Mastery(
    championId: championId,
    championName: championName,
    championIconUrl: championIconUrl,
    level: level,
    points: points,
  );
}
