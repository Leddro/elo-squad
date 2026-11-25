import 'package:elo_squad/features/summoner/data/models/summoner_profile_dto.dart';
import 'package:elo_squad/features/summoner/domain/entities/riot_id.dart';
import 'package:elo_squad/features/summoner/domain/entities/tier.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';

void main() {
  // A fixture foi gerada pelos modelos Pydantic do proxy: é o formato REAL.
  late Map<String, dynamic> json;

  setUp(() => json = loadFixture('summoner_profile.json'));

  test('ida e volta: fromJson(dto.toJson()) reconstrói o mesmo DTO', () {
    // Vai importar no cache offline: o que for salvo como JSON tem de voltar igual.
    final dto = SummonerProfileDto.fromJson(json);

    expect(SummonerProfileDto.fromJson(dto.toJson()), dto);
  });

  test('o JSON gerado usa os mesmos nomes de campo do proxy (camelCase)', () {
    final gerado = SummonerProfileDto.fromJson(json).toJson();

    expect(
      gerado.keys,
      containsAll(['riotId', 'profileIconUrl', 'topMasteries', 'fetchedAt']),
    );
    expect(
      (gerado['riotId'] as Map)['gameName'],
      'Fulano',
    ); // aninhado virou Map
  });

  test('JSON completo → entidade com enums e datas convertidos', () {
    final profile = SummonerProfileDto.fromJson(json).toEntity();

    expect(profile.riotId, const RiotId('Fulano', 'BR1'));
    expect(profile.level, 347);
    expect(profile.fetchedAt, DateTime.utc(2026, 11, 24, 14, 3));
    expect(profile.isPartial, isFalse);

    final solo = profile.ranked!.solo!;
    expect(solo.tier, Tier.gold); // "GOLD" → enum
    expect(solo.division, Division.ii); // "II" → enum
    expect(solo.winRate, closeTo(0.533, 0.001));
    expect(profile.ranked!.flex, isNull); // sem ranque na flex

    final wukong = profile.topMasteries!.single;
    expect(wukong.championName, 'Wukong');
    expect(wukong.championIconUrl, endsWith('/MonkeyKing.png'));
  });

  test('resposta parcial: seções que falharam viram null na entidade', () {
    json
      ..['ranked'] = null
      ..['topMasteries'] = null
      ..['unavailable'] = ['ranked', 'masteries'];

    final profile = SummonerProfileDto.fromJson(json).toEntity();

    expect(profile.ranked, isNull);
    expect(profile.topMasteries, isNull);
    expect(profile.isPartial, isTrue);
  });

  test(
    'Data Dragon fora do ar: nomes e imagens null não quebram a leitura',
    () {
      json['profileIconUrl'] = null;
      (json['topMasteries'] as List).first
        ..['championName'] = null
        ..['championIconUrl'] = null;

      final profile = SummonerProfileDto.fromJson(json).toEntity();

      expect(profile.profileIconUrl, isNull);
      expect(profile.topMasteries!.single.championName, isNull);
    },
  );

  test('tiers sem divisão (MASTER+) são lidos normalmente', () {
    (json['ranked'] as Map)['solo'] = {
      'tier': 'CHALLENGER',
      'division': 'I',
      'lp': 1200,
      'wins': 300,
      'losses': 200,
    };

    final solo = SummonerProfileDto.fromJson(json).toEntity().ranked!.solo!;

    expect(solo.tier, Tier.challenger);
    expect(solo.tier.hasDivisions, isFalse);
  });
}
