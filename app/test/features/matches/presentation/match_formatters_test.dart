import 'package:elo_squad/features/matches/presentation/match_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/matches.dart';

void main() {
  test('matchTitle: resultado, ou colocação na Arena', () {
    expect(matchTitle(makeMatch(1)), 'Vitória');
    expect(matchTitle(makeMatch(1).copyWith(placement: 5)), '5º lugar');
  });

  test('kdaLine e formatKda (vírgula decimal)', () {
    expect(kdaLine(makeMatch(1, kills: 8)), '8/2/7');
    expect(formatKda(7.5), '7,5');
    expect(formatKda(28), '28,0');
  });

  test('formatDuration: mm:ss, e h:mm:ss acima de 1 hora', () {
    expect(formatDuration(const Duration(seconds: 1834)), '30:34');
    expect(formatDuration(const Duration(minutes: 3, seconds: 5)), '3:05');
    expect(formatDuration(const Duration(hours: 1, seconds: 125)), '1:02:05');
  });
}
