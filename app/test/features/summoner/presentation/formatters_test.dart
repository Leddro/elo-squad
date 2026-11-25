import 'package:elo_squad/core/presentation/formatters.dart';
import 'package:elo_squad/features/summoner/domain/entities/ranked.dart';
import 'package:elo_squad/features/summoner/domain/entities/tier.dart';
import 'package:elo_squad/features/summoner/presentation/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

RankedEntry entry(Tier tier, Division division) =>
    RankedEntry(tier: tier, division: division, lp: 0, wins: 0, losses: 0);

void main() {
  group('rankLabel', () {
    test('tier com divisão mostra os dois', () {
      expect(rankLabel(entry(Tier.gold, Division.ii)), 'Ouro II');
    });

    test('Mestre+ mostra só o tier (a Riot manda "I", o app esconde)', () {
      expect(rankLabel(entry(Tier.master, Division.i)), 'Mestre');
      expect(rankLabel(entry(Tier.challenger, Division.i)), 'Desafiante');
    });
  });

  test('formatThousands separa milhares com ponto', () {
    expect(formatThousands(7), '7');
    expect(formatThousands(999), '999');
    expect(formatThousands(1000), '1.000');
    expect(formatThousands(245000), '245.000');
    expect(formatThousands(1234567), '1.234.567');
  });

  test('formatWinRate arredonda e trata "sem partidas"', () {
    expect(formatWinRate(0.533), '53%');
    expect(formatWinRate(null), '—');
  });

  group('formatTimeAgo', () {
    final now = DateTime(2026, 11, 24, 15);
    String ago(Duration d) => formatTimeAgo(now.subtract(d), now: now);

    test(
      'menos de 1 minuto',
      () => expect(ago(const Duration(seconds: 30)), 'agora mesmo'),
    );
    test('minutos', () => expect(ago(const Duration(minutes: 3)), 'há 3 min'));
    test('horas', () => expect(ago(const Duration(hours: 2)), 'há 2 h'));
    test(
      '1 dia (singular)',
      () => expect(ago(const Duration(days: 1)), 'há 1 dia'),
    );
    test('dias', () => expect(ago(const Duration(days: 4)), 'há 4 dias'));
  });
}
