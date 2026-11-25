import 'dart:async';

import 'package:elo_squad/features/matches/domain/entities/match_history.dart';
import 'package:elo_squad/features/matches/domain/repositories/match_repository.dart';

/// FAKE do repositório de partidas para testes de TELA: nada de banco nem
/// rede. O teste decide o que está "salvo" ([emit]) e o que o refresh e o
/// loadMore fazem (por padrão, terminam na hora sem erro).
class FakeMatchRepository implements MatchRepository {
  FakeMatchRepository([this._saved = MatchHistory.empty]);

  MatchHistory _saved;
  final _changes = StreamController<MatchHistory>.broadcast();

  Future<void> Function() onRefresh = () async {};
  Future<void> Function() onLoadMore = () async {};
  int refreshCalls = 0;
  int loadMoreCalls = 0;

  /// Simula uma escrita no banco: o Stream emite o novo histórico.
  void emit(MatchHistory history) {
    _saved = history;
    _changes.add(history);
  }

  @override
  Stream<MatchHistory> watchHistory(String puuid) async* {
    yield _saved; // emite na hora, como o drift
    yield* _changes.stream;
  }

  @override
  Future<void> refresh(String puuid) {
    refreshCalls++;
    return onRefresh();
  }

  @override
  Future<void> loadMore(String puuid) {
    loadMoreCalls++;
    return onLoadMore();
  }
}
