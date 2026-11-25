import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/match_history.dart';
import '../../domain/entities/match_summary.dart';

/// Fonte de dados LOCAL do histórico: o cache offline, em SQLite (drift).
///
/// Garante uma regra (INVARIANTE): o cache de um jogador é sempre um bloco
/// CONTÍNUO de partidas, começando pela mais recente. Nunca "as 10 mais novas
/// + um buraco + as de semana passada". Por causa disso, a posição da próxima
/// página no proxy é simplesmente a quantidade de partidas salvas.
final class MatchLocalDataSource {
  const MatchLocalDataSource(this._db);

  final AppDatabase _db;

  /// Emite o histórico na hora e de novo a cada escrita nas duas tabelas.
  ///
  /// LEFT JOIN: parte do estado do jogador (MatchHistories) e junta as
  /// partidas dele. "LEFT" porque o estado aparece mesmo sem nenhuma partida
  /// (jogador que nunca jogou). Como a consulta lê as duas tabelas, o `watch`
  /// do drift reage a escritas em qualquer uma delas.
  Stream<MatchHistory> watchHistory(String puuid) {
    final matches = _db.cachedMatches;
    final histories = _db.matchHistories;

    final query =
        _db.select(histories).join([
            leftOuterJoin(matches, matches.puuid.equalsExp(histories.puuid)),
          ])
          ..where(histories.puuid.equals(puuid))
          ..orderBy([OrderingTerm.desc(matches.playedAt)]);

    return query.watch().map((rows) {
      if (rows.isEmpty) return MatchHistory.empty; // nunca buscado

      final state = rows.first.readTable(histories);
      return MatchHistory(
        matches: [
          for (final row in rows)
            if (row.readTableOrNull(matches) case final match?)
              _toEntity(match),
        ],
        hasMore: !state.reachedEnd,
        refreshedAt: state.refreshedAt.toUtc(),
      );
    });
  }

  /// Grava a PRIMEIRA página (as partidas mais recentes), numa transação.
  ///
  /// Se alguma partida da página já estava salva, as novas "encostam" nas
  /// antigas e o bloco continua contínuo: junta as duas. Se nenhuma estava,
  /// pode haver um buraco (o jogador jogou mais de uma página desde a última
  /// visita): descarta as antigas, porque um buraco escondido é pior do que
  /// buscar de novo.
  Future<void> saveFirstPage(
    String puuid,
    List<MatchSummary> page, {
    required bool reachedEnd,
    required DateTime refreshedAt,
  }) {
    // transaction: ou tudo é gravado, ou nada. E o `watch` emite UMA vez no
    // fim, sem mostrar à tela um estado pela metade.
    return _db.transaction(() async {
      final ids = [for (final m in page) m.matchId];
      final alreadySaved = await _db.cachedMatches
          .count(where: (m) => m.puuid.equals(puuid) & m.matchId.isIn(ids))
          .getSingle();
      final previous = await _historyRow(puuid);

      final keepOld = alreadySaved > 0;
      if (!keepOld) {
        await _db.cachedMatches.deleteWhere((m) => m.puuid.equals(puuid));
      }

      await _upsertMatches(puuid, page);
      await _db.matchHistories.insertOnConflictUpdate(
        MatchHistoriesCompanion.insert(
          puuid: puuid,
          // Mantendo as antigas, o fim do histórico continua onde estava.
          reachedEnd:
              reachedEnd || (keepOld && (previous?.reachedEnd ?? false)),
          refreshedAt: refreshedAt,
        ),
      );
    });
  }

  /// Grava uma página seguinte (partidas mais antigas) no fim do bloco.
  Future<void> appendPage(
    String puuid,
    List<MatchSummary> page, {
    required bool reachedEnd,
  }) {
    return _db.transaction(() async {
      await _upsertMatches(puuid, page);
      // Companion com Value(...): atualiza SÓ esta coluna; refreshedAt fica.
      await (_db.update(_db.matchHistories)
            ..where((h) => h.puuid.equals(puuid)))
          .write(MatchHistoriesCompanion(reachedEnd: Value(reachedEnd)));
    });
  }

  /// Posição (`start`) da próxima página no proxy, pela invariante do bloco
  /// contínuo. null = não há próxima: o histórico acabou ou nunca foi buscado.
  Future<int?> nextStart(String puuid) async {
    final state = await _historyRow(puuid);
    if (state == null || state.reachedEnd) return null;
    return _db.cachedMatches
        .count(where: (m) => m.puuid.equals(puuid))
        .getSingle();
  }

  Future<MatchHistoryRow?> _historyRow(String puuid) => (_db.select(
    _db.matchHistories,
  )..where((h) => h.puuid.equals(puuid))).getSingleOrNull();

  /// UPSERT (insert or update): partida nova é inserida; partida que já
  /// existia (mesmo puuid + matchId) é sobrescrita. É isso que descarta as
  /// duplicadas que a paginação por posição pode trazer.
  Future<void> _upsertMatches(String puuid, List<MatchSummary> page) {
    // batch: todas as inserções num único envio ao isolate do banco.
    return _db.batch(
      (b) => b.insertAllOnConflictUpdate(_db.cachedMatches, [
        for (final m in page) _toCompanion(puuid, m),
      ]),
    );
  }

  // ---------- Mapeamento linha ⇄ entidade ----------

  static CachedMatchesCompanion _toCompanion(String puuid, MatchSummary m) =>
      CachedMatchesCompanion.insert(
        puuid: puuid,
        matchId: m.matchId,
        queue: m.queue,
        result: m.result,
        placement: Value(m.placement), // Value: coluna anulável
        championId: m.championId,
        championName: Value(m.championName),
        championIconUrl: Value(m.championIconUrl),
        kills: m.kills,
        deaths: m.deaths,
        assists: m.assists,
        cs: m.cs,
        items: m.items,
        trinket: Value(m.trinket),
        durationSeconds: m.duration.inSeconds,
        playedAt: m.playedAt,
      );

  static MatchSummary _toEntity(MatchRow row) => MatchSummary(
    matchId: row.matchId,
    queue: row.queue,
    result: row.result,
    placement: row.placement,
    championId: row.championId,
    championName: row.championName,
    championIconUrl: row.championIconUrl,
    kills: row.kills,
    deaths: row.deaths,
    assists: row.assists,
    cs: row.cs,
    items: row.items,
    trinket: row.trinket,
    duration: Duration(seconds: row.durationSeconds),
    // O drift devolve a data no fuso do aparelho; o app trabalha em UTC.
    playedAt: row.playedAt.toUtc(),
  );
}
