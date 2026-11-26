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
  }) = _ScienceBuild;
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

  final String label;

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
