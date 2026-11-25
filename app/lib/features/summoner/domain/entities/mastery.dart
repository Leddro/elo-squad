import 'package:freezed_annotation/freezed_annotation.dart';

part 'mastery.freezed.dart';

/// Maestria do jogador com um campeão.
@freezed
abstract class Mastery with _$Mastery {
  const factory Mastery({
    required int championId,

    /// `null` se o proxy não conseguiu resolver (campeão recém-lançado ou
    /// Data Dragon fora do ar): a tela mostra um placeholder.
    required String? championName,
    required String? championIconUrl,

    /// Sem teto: desde 2024 a maestria passa do nível 7.
    required int level,
    required int points,
  }) = _Mastery;
}
