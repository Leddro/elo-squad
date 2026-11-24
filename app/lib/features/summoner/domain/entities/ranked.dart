import 'tier.dart';

/// As filas ranqueadas de um jogador.
///
/// `null` em [solo] ou [flex] = sem ranque nessa fila (dado real, não falha).
final class Ranked {
  const Ranked({this.solo, this.flex});

  final RankedEntry? solo;
  final RankedEntry? flex;
}

/// Situação do jogador em uma fila.
final class RankedEntry {
  const RankedEntry({
    required this.tier,
    required this.division,
    required this.lp,
    required this.wins,
    required this.losses,
  });

  final Tier tier;
  final Division division;
  final int lp;
  final int wins;
  final int losses;

  /// Regra de negócio derivada: não vem da API, é calculada aqui.
  int get games => wins + losses;

  /// Taxa de vitória de 0.0 a 1.0, ou `null` se ainda não há partidas.
  /// (`null` em vez de 0.0: "0%" sugeriria que perdeu todas.)
  double? get winRate => games == 0 ? null : wins / games;
}
