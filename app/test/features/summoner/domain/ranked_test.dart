import 'package:elo_squad/features/summoner/domain/entities/ranked.dart';
import 'package:elo_squad/features/summoner/domain/entities/tier.dart';
import 'package:flutter_test/flutter_test.dart';

RankedEntry entry({int wins = 0, int losses = 0, Tier tier = Tier.gold}) =>
    RankedEntry(
      tier: tier,
      division: Division.ii,
      lp: 50,
      wins: wins,
      losses: losses,
    );

void main() {
  group('RankedEntry', () {
    test('games soma vitórias e derrotas', () {
      expect(entry(wins: 40, losses: 35).games, 75);
    });

    test('winRate calcula a proporção de vitórias', () {
      expect(entry(wins: 3, losses: 1).winRate, 0.75);
    });

    test('winRate é null sem partidas (e não 0%)', () {
      expect(entry().winRate, isNull);
    });
  });

  group('Tier', () {
    test('a ordem do enum segue a escada do ranqueado', () {
      expect(Tier.gold.index, lessThan(Tier.diamond.index));
      expect(Tier.values.first, Tier.iron);
      expect(Tier.values.last, Tier.challenger);
    });

    test('só tiers abaixo de Mestre têm divisões', () {
      final semDivisao = Tier.values.where((t) => !t.hasDivisions);

      expect(semDivisao, [Tier.master, Tier.grandmaster, Tier.challenger]);
    });
  });
}
