import 'dart:async';

import '../../../../core/error/firestore_failures.dart';
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
      .transform(firestoreFailures());

  @override
  Stream<List<Squad>> watchMySquads(String uid) => _firestore
      .watchSquadsOf(uid)
      .map(
        (docs) => [
          for (final (id, dto) in docs) dto.toEntity(id),
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      )
      .transform(firestoreFailures());

  @override
  Stream<Squad?> watchSquad(String squadId) => _firestore
      .watchSquad(squadId)
      .map((dto) => dto?.toEntity(squadId))
      .transform(firestoreFailures(permissionDeniedAsNull: true));

  @override
  Stream<WeeklyRanking?> watchLatestRanking(String squadId) => _firestore
      .watchLatestRanking(squadId)
      .map((dto) => dto?.toEntity())
      .transform(firestoreFailures(permissionDeniedAsNull: true));

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

  @override
  Future<void> setSquadIcon(String squadId, String icon) =>
      guardFailures(() => _remote.setSquadIcon(squadId, icon));

  @override
  Future<void> updateSquadInfo(
    String squadId, {
    required String name,
    required String description,
  }) =>
      guardFailures(() => _remote.updateSquadInfo(squadId, name, description));

  @override
  Future<void> removeMember(String squadId, String memberUid) =>
      guardFailures(() => _remote.removeMember(squadId, memberUid));
}
