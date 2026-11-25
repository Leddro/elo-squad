import '../../../../core/error/failure.dart';
import '../../../../core/error/guard_failures.dart';
import '../../domain/entities/match_history.dart';
import '../../domain/repositories/match_repository.dart';
import '../datasources/match_remote_data_source.dart';
import '../local/match_local_data_source.dart';

/// Orquestra as duas fontes: a rede escreve no banco, a tela lê do banco.
final class MatchRepositoryImpl implements MatchRepository {
  MatchRepositoryImpl(this._remote, this._local, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final MatchRemoteDataSource _remote;
  final MatchLocalDataSource _local;

  /// RELÓGIO INJETADO: o teste passa um horário fixo e consegue conferir o
  /// `refreshedAt` exato. Com `DateTime.now()` direto, o valor mudaria a cada
  /// execução.
  final DateTime Function() _clock;

  @override
  Stream<MatchHistory> watchHistory(String puuid) => _local
      .watchHistory(puuid)
      // Um erro do banco vira Failure, como nos outros métodos.
      .handleError(
        (Object e, StackTrace st) =>
            Error.throwWithStackTrace(UnexpectedFailure(e), st),
      );

  @override
  Future<void> refresh(String puuid) => _oneAtATime(() async {
    final page = await _remote.fetchPage(puuid, start: 0);
    await _local.saveFirstPage(
      puuid,
      [for (final dto in page.matches) dto.toEntity()],
      reachedEnd: page.nextStart == null,
      refreshedAt: _clock().toUtc(),
    );
  });

  @override
  Future<void> loadMore(String puuid) => _oneAtATime(() async {
    final start = await _local.nextStart(puuid);
    if (start == null) return; // acabou, ou ainda não houve refresh

    final page = await _remote.fetchPage(puuid, start: start);
    await _local.appendPage(puuid, [
      for (final dto in page.matches) dto.toEntity(),
    ], reachedEnd: page.nextStart == null);
  });

  /// Fim da fila de escritas: cada operação nova espera a anterior acabar.
  Future<void> _queue = Future.value();

  /// EXCLUSÃO MÚTUA (mutex): uma escrita por vez.
  ///
  /// Evita uma CONDIÇÃO DE CORRIDA. Sem a fila, um loadMore que começa
  /// durante um refresh lê o `nextStart` ANTES do refresh descartar as
  /// partidas antigas, e grava a página depois do buraco, quebrando a
  /// invariante do bloco contínuo. Com a fila, ele só lê o `nextStart`
  /// depois que o refresh terminou.
  Future<void> _oneAtATime(Future<void> Function() body) {
    final result = _queue.then((_) => guardFailures(body));
    // Uma operação que falhou não pode travar a fila para sempre.
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }
}
