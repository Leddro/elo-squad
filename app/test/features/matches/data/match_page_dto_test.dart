import 'package:elo_squad/features/matches/data/models/match_page_dto.dart';
import 'package:elo_squad/features/matches/domain/entities/match_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';

void main() {
  // Gerada pelos modelos Pydantic do proxy: é o formato REAL.
  late Map<String, dynamic> json;

  setUp(() => json = loadFixture('match_page.json'));

  List<MatchSummary> entities() => [
    for (final dto in MatchPageDto.fromJson(json).matches) dto.toEntity(),
  ];

  test('JSON → entidades com enums, duração e data convertidos', () {
    final page = MatchPageDto.fromJson(json);
    final [ranked, aram, arena] = entities();

    expect(page.nextStart, 3);

    expect(ranked.queue, QueueType.rankedSolo);
    expect(ranked.result, MatchResult.win);
    expect(ranked.duration, const Duration(minutes: 30, seconds: 34));
    expect(ranked.playedAt, DateTime.utc(2026, 11, 24, 22, 15));
    expect(ranked.trinket?.itemId, 3364);

    expect(aram.queue, QueueType.aram);
    expect(aram.championName, isNull); // Data Dragon fora: não quebra

    expect(arena.queue, QueueType.arena);
    expect(arena.placement, 5);
  });

  test('itens são posicionais: espaço vazio continua sendo uma posição', () {
    final aram = entities()[1];

    expect(aram.items, hasLength(6));
    expect(
      [for (final i in aram.items) i?.itemId],
      [3020, null, 6655, null, null, null],
    );
    expect(aram.trinket, isNull);
  });

  test('fila desconhecida vira `other` (leitor tolerante)', () {
    (json['matches'] as List).first['queue'] = 'MODO_NOVO_2027';

    expect(entities().first.queue, QueueType.other);
  });

  test('resultado desconhecido é erro (não dá para chutar V ou D)', () {
    (json['matches'] as List).first['result'] = 'DRAW';

    expect(entities, throwsArgumentError);
  });

  test('última página: nextStart null', () {
    json['nextStart'] = null;

    expect(MatchPageDto.fromJson(json).nextStart, isNull);
  });

  test('KDA: sem mortes, divide por 1', () {
    final [ranked, aram, _] = entities();

    expect(ranked.kda, (8 + 11) / 2);
    expect(aram.kda, 28); // 3/0/25
  });
}
