import 'package:freezed_annotation/freezed_annotation.dart';

part 'match_summary.freezed.dart';

/// Filas que o app distingue. Espelha o `QueueType` do proxy; filas novas
/// que o app ainda não conhece chegam como [other].
enum QueueType { rankedSolo, rankedFlex, normal, aram, arena, other }

/// [remake]: partida encerrada no começo (alguém não conectou). Não conta
/// como vitória nem derrota.
enum MatchResult { win, loss, remake }

/// Um item do inventário. [iconUrl] é null se o Data Dragon estiver fora do ar.
@freezed
abstract class Item with _$Item {
  const factory Item({required int itemId, required String? iconUrl}) = _Item;
}

/// Uma partida do ponto de vista de UM jogador (o dono do PUUID buscado).
@freezed
abstract class MatchSummary with _$MatchSummary {
  const MatchSummary._(); // para o getter kda

  const factory MatchSummary({
    required String matchId, // "BR1_3307659647": identifica a partida
    required QueueType queue,
    required MatchResult result,
    required int? placement, // 1º a 8º, só na Arena
    required int championId,
    required String? championName,
    required String? championIconUrl,
    required int kills,
    required int deaths,
    required int assists,
    required int cs,
    required List<Item?> items, // sempre 6 posições; null = espaço vazio
    required Item? trinket,
    required Duration duration,
    required DateTime playedAt, // quando a partida terminou (UTC)
  }) = _MatchSummary;

  /// (abates + assistências) / mortes. Sem mortes, divide por 1 (convenção
  /// do jogo: um 5/0/5 aparece como KDA 10, e não "infinito").
  double get kda => (kills + assists) / (deaths == 0 ? 1 : deaths);
}
