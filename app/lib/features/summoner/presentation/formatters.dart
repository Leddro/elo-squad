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
