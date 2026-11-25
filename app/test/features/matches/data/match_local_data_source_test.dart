import 'dart:async';

import 'package:drift/native.dart';
import 'package:elo_squad/core/database/app_database.dart';
import 'package:elo_squad/features/matches/data/local/match_local_data_source.dart';
import 'package:elo_squad/features/matches/data/models/match_page_dto.dart';
import 'package:elo_squad/features/matches/domain/entities/match_history.dart';
import 'package:elo_squad/features/matches/domain/entities/match_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/matches.dart';

// Testes com um SQLite DE VERDADE, só que em memória (NativeDatabase.memory):
// rápido, isolado (cada teste começa com um banco vazio) e roda o SQL real
// que o drift gerou. Um mock do banco não provaria nada sobre as consultas.

void main() {
  late AppDatabase db;
  late MatchLocalDataSource local;
  const fulano = 'puuid-fulano';
  final refreshedAt = DateTime.utc(2026, 11, 25, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    local = MatchLocalDataSource(db);
  });

  tearDown(() => db.close());

  Future<MatchHistory> read([String puuid = fulano]) =>
      local.watchHistory(puuid).first;

  Future<void> saveFirst(
    List<MatchSummary> page, {
    bool reachedEnd = false,
    String puuid = fulano,
  }) => local.saveFirstPage(
    puuid,
    page,
    reachedEnd: reachedEnd,
    refreshedAt: refreshedAt,
  );

  test('jogador nunca buscado: histórico vazio e sem refreshedAt', () async {
    final history = await read();

    expect(history, MatchHistory.empty);
    expect(history.neverLoaded, isTrue);
    expect(await local.nextStart(fulano), isNull);
  });

  test(
    'ida e volta: o que é salvo volta igual (enums, itens em JSON, UTC)',
    () async {
      // Partidas reais da fixture: espaço vazio, trinket null, Arena...
      final page = [
        for (final dto in MatchPageDto.fromJson(
          loadFixture('match_page.json'),
        ).matches)
          dto.toEntity(),
      ];

      await saveFirst(page);
      final history = await read();

      expect(history.matches, page); // igualdade do freezed, campo a campo
      expect(history.refreshedAt, refreshedAt);
      expect(history.hasMore, isTrue);
    },
  );

  test('ordena da mais nova para a mais antiga', () async {
    await saveFirst(pageOf([2, 9, 5])); // fora de ordem de propósito

    expect(idsOf((await read()).matches), ['BR1_9', 'BR1_5', 'BR1_2']);
  });

  group('primeira página (refresh)', () {
    test('encosta nas salvas: junta as duas, sem duplicar', () async {
      await saveFirst(pageOf([5, 4, 3]));
      await saveFirst(pageOf([6, 5, 4])); // o jogador jogou 1 partida nova

      expect(idsOf((await read()).matches), [
        'BR1_6',
        'BR1_5',
        'BR1_4',
        'BR1_3',
      ]);
    });

    test('nenhuma em comum: descarta as antigas (evita um buraco)', () async {
      await saveFirst(pageOf([3, 2, 1]));
      await saveFirst(pageOf([9, 8, 7])); // jogou 6 desde a última visita

      expect(idsOf((await read()).matches), ['BR1_9', 'BR1_8', 'BR1_7']);
    });

    test(
      'juntando, o fim do histórico já alcançado continua valendo',
      () async {
        await saveFirst(pageOf([3, 2, 1]), reachedEnd: true);
        await saveFirst(pageOf([4, 3, 2])); // o proxy diz "tem mais"

        // ...mas a partida 1 (a mais antiga de todas) já está salva.
        expect((await read()).hasMore, isFalse);
      },
    );
  });

  group('páginas seguintes (loadMore)', () {
    test(
      'nextStart = quantidade salva (invariante do bloco contínuo)',
      () async {
        await saveFirst(pageOf([6, 5, 4]));
        expect(await local.nextStart(fulano), 3);

        await local.appendPage(fulano, pageOf([3, 2]), reachedEnd: false);
        expect(await local.nextStart(fulano), 5);
      },
    );

    test('duplicadas da paginação por posição são descartadas', () async {
      await saveFirst(pageOf([6, 5, 4]));
      // Uma partida nova empurrou tudo uma posição: a 4 vem de novo.
      await local.appendPage(fulano, pageOf([4, 3, 2]), reachedEnd: false);

      expect((await read()).matches, hasLength(5));
      expect(await local.nextStart(fulano), 5);
    });

    test('última página: hasMore false e nextStart null', () async {
      await saveFirst(pageOf([6, 5, 4]));
      await local.appendPage(fulano, pageOf([3]), reachedEnd: true);

      final history = await read();
      expect(history.hasMore, isFalse);
      expect(history.refreshedAt, refreshedAt); // o append não mexe nele
      expect(await local.nextStart(fulano), isNull);
    });
  });

  test(
    'mesma partida no histórico de dois jogadores (chave composta)',
    () async {
      await saveFirst([makeMatch(1, kills: 10)]);
      await saveFirst([makeMatch(1, kills: 0)], puuid: 'puuid-amigo');

      expect((await read()).matches.single.kills, 10);
      expect((await read('puuid-amigo')).matches.single.kills, 0);
    },
  );

  test('watch é reativo: emite de novo a cada escrita', () async {
    // StreamIterator: espera cada emissão, uma de cada vez (sem corrida).
    final emissions = StreamIterator(local.watchHistory(fulano));
    addTearDown(emissions.cancel);

    expect(await emissions.moveNext(), isTrue);
    expect(emissions.current.neverLoaded, isTrue);

    await saveFirst(pageOf([6, 5, 4]));
    expect(await emissions.moveNext(), isTrue);
    expect(emissions.current.matches, hasLength(3));

    await local.appendPage(fulano, pageOf([3, 2]), reachedEnd: true);
    expect(await emissions.moveNext(), isTrue);
    expect(emissions.current.matches, hasLength(5));
    expect(emissions.current.hasMore, isFalse);
  });
}
