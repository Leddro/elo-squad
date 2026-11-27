import 'package:freezed_annotation/freezed_annotation.dart';

part 'science.freezed.dart';

/// As Ciências do patch: builds incomuns de monochamps de elite que ganham.
@freezed
abstract class SciencesBoard with _$SciencesBoard {
  const factory SciencesBoard({
    required String patch, // "16.23"
    required DateTime updatedAt,
    required List<ScienceBuild> builds, // da melhor para a pior
  }) = _SciencesBoard;
}

@freezed
abstract class ScienceBuild with _$ScienceBuild {
  const factory ScienceBuild({
    required String title, // "Malphite AP no Mid"
    required String championName,
    required String? championIconUrl,
    required ScienceRole role,
    required List<ScienceItem> items, // itens completos, na ordem de compra
    required ScienceItem? boots,
    required String skills, // habilidade de cada nível: "QEWQQRQEQ..."
    required String maxOrder, // "Q > E > W"
    @Default(ScienceTier.c) ScienceTier tier,
    @Default(0) int games, // partidas da build entre os monochamps
    @Default(0) double winRate, // 0 a 1, da build
    @Default(0) double pickRate, // 0 a 1, do campeão nesta rota no elo alto
    @Default(0) double banRate, // 0 a 1, do campeão no elo alto
  }) = _ScienceBuild;
}

/// Tier da Ciência, do melhor (S) para o pior (D).
enum ScienceTier {
  s('S'),
  a('A'),
  b('B'),
  c('C'),
  d('D');

  const ScienceTier(this.label);

  final String label;

  static ScienceTier fromLabel(String? value) =>
      values.firstWhere((t) => t.label == value, orElse: () => c);
}

@freezed
abstract class ScienceItem with _$ScienceItem {
  const factory ScienceItem({
    required int id,
    required String name,
    required String? iconUrl,
  }) = _ScienceItem;
}

enum ScienceRole {
  top('Top'),
  jungle('Selva'),
  middle('Mid'),
  bottom('Bot'),
  utility('Suporte');

  const ScienceRole(this.label);

  /// Nome da rota: vai no Tooltip e na leitura de tela (o app mostra o ícone).
  final String label;

  /// Ícone da rota como no cliente do jogo (Community Dragon).
  String get iconUrl =>
      'https://raw.communitydragon.org/latest/plugins/rcp-fe-lol-clash/'
      'global/default/assets/images/position-selector/positions/'
      'icon-position-$name.png';

  /// "MIDDLE" (formato da Riot) → [ScienceRole.middle].
  static ScienceRole? fromRiot(String value) => switch (value) {
    'TOP' => top,
    'JUNGLE' => jungle,
    'MIDDLE' => middle,
    'BOTTOM' => bottom,
    'UTILITY' => utility,
    _ => null,
  };
}
