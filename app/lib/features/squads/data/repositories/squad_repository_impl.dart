import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/guard_failures.dart';
import '../../../summoner/domain/entities/riot_id.dart';
import '../../domain/entities/squad.dart';
import '../../domain/entities/weekly_ranking.dart';
import '../../domain/repositories/squad_repository.dart';
import '../datasources/squad_firestore_data_source.dart';
import '../datasources/squad_remote_data_source.dart';

final class SquadRepositoryImpl implements SquadRepository {
  const SquadRepositoryImpl(this._firestore, this._remote);

  final SquadFirestoreDataSource _firestore;
  final SquadRemoteDataSource _remote;

  @override
  Stream<AccountLink> watchAccount(String uid) => _firestore
      .watchUser(uid)
      .map((dto) => dto?.toEntity() ?? AccountLink.empty)
      .transform(_toFailures());

  @override
  Stream<List<Squad>> watchMySquads(String uid) => _firestore
      .watchSquadsOf(uid)
      .map(
        (docs) => [
          for (final (id, dto) in docs) dto.toEntity(id),
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      )
      .transform(_toFailures());

  @override
  Stream<Squad?> watchSquad(String squadId) => _firestore
      .watchSquad(squadId)
      .map((dto) => dto?.toEntity(squadId))
      .transform(_toFailures(permissionDeniedAsNull: true));

  @override
  Stream<WeeklyRanking?> watchLatestRanking(String squadId) => _firestore
      .watchLatestRanking(squadId)
      .map((dto) => dto?.toEntity())
      .transform(_toFailures(permissionDeniedAsNull: true));

  @override
  Future<RiotId> linkRiotId(RiotId riotId) => guardFailures(() async {
    final dto = await _remote.linkRiotId(riotId.gameName, riotId.tagLine);
    return dto.toEntity();
  });

  @override
  Future<String> createSquad(String name) =>
      guardFailures(() async => (await _remote.createSquad(name)).id);

  @override
  Future<String> joinSquad(String inviteCode) =>
      guardFailures(() async => (await _remote.joinSquad(inviteCode)).id);

  @override
  Future<void> leaveSquad(String squadId) =>
      guardFailures(() => _remote.leaveSquad(squadId));

  /// Erros do Firestore (e de JSON fora do formato) viram Failure.
  ///
  /// [permissionDeniedAsNull]: depois de sair de um squad, a regra de
  /// segurança passa a negar a leitura dele. Para a tela, isso é "o squad não
  /// está mais disponível" (null), e não um erro.
  static StreamTransformer<T, T> _toFailures<T>({
    bool permissionDeniedAsNull = false,
  }) => StreamTransformer.fromHandlers(
    handleError: (error, stackTrace, sink) {
      if (error is FirebaseException) {
        if (permissionDeniedAsNull && error.code == 'permission-denied') {
          sink.add(null as T);
          return;
        }
        if (error.code == 'unavailable') {
          sink.addError(const NetworkFailure(), stackTrace);
          return;
        }
      }
      sink.addError(
        error is Failure ? error : UnexpectedFailure(error),
        stackTrace,
      );
    },
  );
}
