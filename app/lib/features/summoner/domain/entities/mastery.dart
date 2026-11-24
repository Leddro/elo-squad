/// Maestria do jogador com um campeão.
final class Mastery {
  const Mastery({
    required this.championId,
    required this.championName,
    required this.championIconUrl,
    required this.level,
    required this.points,
  });

  final int championId;

  /// `null` se o proxy não conseguiu resolver (campeão recém-lançado ou
  /// Data Dragon fora do ar): a tela mostra um placeholder.
  final String? championName;
  final String? championIconUrl;

  /// Sem teto: desde 2024 a maestria passa do nível 7.
  final int level;
  final int points;
}
