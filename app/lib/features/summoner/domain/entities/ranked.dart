import 'package:freezed_annotation/freezed_annotation.dart';

import 'tier.dart';

// O código gerado (==, hashCode, copyWith, toString) vai para este arquivo.
part 'ranked.freezed.dart';

/// As filas ranqueadas de um jogador.
///
/// `null` em [solo] ou [flex] = sem ranque nessa fila (dado real, não falha).
@freezed
abstract class Ranked with _$Ranked {
  const factory Ranked({RankedEntry? solo, RankedEntry? flex}) = _Ranked;
}

/// Situação do jogador em uma fila.
@freezed
abstract class RankedEntry with _$RankedEntry {
  // Construtor privado vazio: necessário para a classe ter getters próprios.
  // Com ele, o código gerado ESTENDE esta classe (herda os getters) em vez de
  // só implementá-la.
  const RankedEntry._();

  const factory RankedEntry({
    required Tier tier,
    required Division division,
    required int lp,
    required int wins,
    required int losses,
  }) = _RankedEntry;

  /// Regra de negócio derivada: não vem da API, é calculada aqui.
  int get games => wins + losses;

  /// Taxa de vitória de 0.0 a 1.0, ou `null` se ainda não há partidas.
  /// (`null` em vez de 0.0: "0%" sugeriria que perdeu todas.)
  double? get winRate => games == 0 ? null : wins / games;
}
