import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/network/json.dart';
import '../../domain/entities/match_summary.dart';

part 'match_page_dto.freezed.dart';
part 'match_page_dto.g.dart';

// DTOs da resposta de GET /matches/{puuid}?start=&count= (contrato do proxy).

@freezed
abstract class MatchPageDto with _$MatchPageDto {
  const factory MatchPageDto({
    required List<MatchSummaryDto> matches,
    // Valor de `start` para a próxima página. null = o histórico acabou.
    required int? nextStart,
  }) = _MatchPageDto;

  factory MatchPageDto.fromJson(Json json) => _$MatchPageDtoFromJson(json);
}

@freezed
abstract class MatchSummaryDto with _$MatchSummaryDto {
  const MatchSummaryDto._();

  const factory MatchSummaryDto({
    required String matchId,
    required String queue, // "RANKED_SOLO": texto, como no JSON
    required String result, // "WIN"
    required int? placement,
    required int championId,
    required String? championName,
    required String? championIconUrl,
    required int kills,
    required int deaths,
    required int assists,
    required int cs,
    required List<ItemDto?> items,
    required ItemDto? trinket,
    required int durationSeconds,
    required DateTime playedAt,
  }) = _MatchSummaryDto;

  factory MatchSummaryDto.fromJson(Json json) =>
      _$MatchSummaryDtoFromJson(json);

  MatchSummary toEntity() => MatchSummary(
    matchId: matchId,
    queue: _queueFrom(queue),
    result: _resultFrom(result),
    placement: placement,
    championId: championId,
    championName: championName,
    championIconUrl: championIconUrl,
    kills: kills,
    deaths: deaths,
    assists: assists,
    cs: cs,
    items: items.map((i) => i?.toEntity()).toList(),
    trinket: trinket?.toEntity(),
    duration: Duration(seconds: durationSeconds),
    playedAt: playedAt,
  );
}

@freezed
abstract class ItemDto with _$ItemDto {
  const ItemDto._();

  const factory ItemDto({required int itemId, required String? iconUrl}) =
      _ItemDto;

  factory ItemDto.fromJson(Json json) => _$ItemDtoFromJson(json);

  /// Caminho inverso, usado pelo banco local para guardar itens como JSON.
  factory ItemDto.fromEntity(Item item) =>
      ItemDto(itemId: item.itemId, iconUrl: item.iconUrl);

  Item toEntity() => Item(itemId: itemId, iconUrl: iconUrl);
}

/// LEITOR TOLERANTE (tolerant reader): uma fila que o app não conhece vira
/// `other`. Se a Riot criar um modo novo, o histórico continua aparecendo.
QueueType _queueFrom(String value) => switch (value) {
  'RANKED_SOLO' => QueueType.rankedSolo,
  'RANKED_FLEX' => QueueType.rankedFlex,
  'NORMAL' => QueueType.normal,
  'ARAM' => QueueType.aram,
  'ARENA' => QueueType.arena,
  _ => QueueType.other,
};

/// Aqui NÃO há tolerância: um resultado desconhecido não pode ser exibido
/// como vitória nem derrota, então é um erro (vira UnexpectedFailure).
MatchResult _resultFrom(String value) => switch (value) {
  'WIN' => MatchResult.win,
  'LOSS' => MatchResult.loss,
  'REMAKE' => MatchResult.remake,
  _ => throw ArgumentError.value(value, 'result', 'resultado desconhecido'),
};
