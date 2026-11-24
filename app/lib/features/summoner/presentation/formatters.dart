import '../domain/entities/ranked.dart';
import '../domain/entities/tier.dart';

// Textos de exibição. Ficam na presentation: o proxy e o domain entregam
// dados ("GOLD", Tier.gold); transformar em "Ouro" é decisão de apresentação.

String tierLabel(Tier tier) => switch (tier) {
  Tier.iron => 'Ferro',
  Tier.bronze => 'Bronze',
  Tier.silver => 'Prata',
  Tier.gold => 'Ouro',
  Tier.platinum => 'Platina',
  Tier.emerald => 'Esmeralda',
  Tier.diamond => 'Diamante',
  Tier.master => 'Mestre',
  Tier.grandmaster => 'Grão-Mestre',
  Tier.challenger => 'Desafiante',
};

String divisionLabel(Division division) => switch (division) {
  Division.i => 'I',
  Division.ii => 'II',
  Division.iii => 'III',
  Division.iv => 'IV',
};

/// "Ouro II", ou só "Mestre" para tiers sem divisão.
String rankLabel(RankedEntry entry) => entry.tier.hasDivisions
    ? '${tierLabel(entry.tier)} ${divisionLabel(entry.division)}'
    : tierLabel(entry.tier);

/// 245000 → "245.000".
String formatThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 0.533 → "53%". Sem partidas → "—".
String formatWinRate(double? winRate) =>
    winRate == null ? '—' : '${(winRate * 100).round()}%';

/// "agora mesmo", "há 3 min", "há 2 h", "há 4 dias".
String formatUpdatedAgo(DateTime fetchedAt, {required DateTime now}) {
  final elapsed = now.difference(fetchedAt);
  if (elapsed.inMinutes < 1) return 'agora mesmo';
  if (elapsed.inHours < 1) return 'há ${elapsed.inMinutes} min';
  if (elapsed.inDays < 1) return 'há ${elapsed.inHours} h';
  return elapsed.inDays == 1 ? 'há 1 dia' : 'há ${elapsed.inDays} dias';
}
