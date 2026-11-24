/// Tier do ranqueado, do menor para o maior.
///
/// A ORDEM importa: `Tier.gold.index < Tier.diamond.index`. Na fase 3, o
/// ranking de amigos vai comparar tiers por aqui.
///
/// "Enhanced enum": cada valor carrega dados ([hasDivisions]), em vez de
/// espalhar `if (tier == master || tier == grandmaster || ...)` pelo app.
enum Tier {
  iron(hasDivisions: true),
  bronze(hasDivisions: true),
  silver(hasDivisions: true),
  gold(hasDivisions: true),
  platinum(hasDivisions: true),
  emerald(hasDivisions: true),
  diamond(hasDivisions: true),
  master(hasDivisions: false),
  grandmaster(hasDivisions: false),
  challenger(hasDivisions: false);

  const Tier({required this.hasDivisions});

  /// Mestre, Grão-Mestre e Desafiante não têm divisões: a Riot sempre manda
  /// "I" para eles, e o app deve mostrar só "Mestre", não "Mestre I".
  final bool hasDivisions;
}

/// Divisão dentro do tier. `i` é a mais alta (Ouro I > Ouro IV).
enum Division { i, ii, iii, iv }
