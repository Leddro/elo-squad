import 'dart:async';

import 'package:elo_squad/features/squads/domain/entities/squad.dart';
import 'package:elo_squad/features/squads/domain/entities/weekly_ranking.dart';
import 'package:elo_squad/features/squads/domain/repositories/squad_repository.dart';
import 'package:elo_squad/features/summoner/domain/entities/riot_id.dart';

/// FAKE dos squads para testes de TELA: o teste controla a conta, os squads
/// "no Firestore" e o que cada ação devolve.
class FakeSquadRepository implements SquadRepository {
  FakeSquadRepository({
    this._account = AccountLink.empty,
    List<Squad> squads = const [],
  }) : _squads = [...squads];

  AccountLink _account;
  List<Squad> _squads;
  final _accountChanges = StreamController<AccountLink>.broadcast();
  final _squadChanges = StreamController<List<Squad>>.broadcast();

  Future<String> Function(String name) onCreate = (_) async => 'novo-id';
  Future<String> Function(String code) onJoin = (_) async => 'novo-id';
  Future<RiotId> Function(RiotId riotId) onLink = (id) async => id;
  final leftSquads = <String>[];

  /// Ranking mais recente de cada squad (por id).
  final rankings = <String, WeeklyRanking>{};

  void setAccount(AccountLink account) {
    _account = account;
    _accountChanges.add(account);
  }

  void setSquads(List<Squad> squads) {
    _squads = [...squads];
    _squadChanges.add(_squads);
  }

  @override
  Stream<AccountLink> watchAccount(String uid) async* {
    yield _account;
    yield* _accountChanges.stream;
  }

  @override
  Stream<List<Squad>> watchMySquads(String uid) async* {
    yield _squads;
    yield* _squadChanges.stream;
  }

  @override
  Stream<Squad?> watchSquad(String squadId) async* {
    Squad? find(List<Squad> all) =>
        all.where((s) => s.id == squadId).firstOrNull;
    yield find(_squads);
    yield* _squadChanges.stream.map(find);
  }

  @override
  Stream<WeeklyRanking?> watchLatestRanking(String squadId) =>
      Stream.value(rankings[squadId]);

  @override
  Future<RiotId> linkRiotId(RiotId riotId) => onLink(riotId);

  @override
  Future<String> createSquad(String name) => onCreate(name);

  @override
  Future<String> joinSquad(String inviteCode) => onJoin(inviteCode);

  @override
  Future<void> leaveSquad(String squadId) async => leftSquads.add(squadId);

  final iconChanges = <(String, String)>[];
  final removedMembers = <(String, String)>[];

  @override
  Future<void> removeMember(String squadId, String memberUid) async =>
      removedMembers.add((squadId, memberUid));

  @override
  Future<void> setSquadIcon(String squadId, String icon) async =>
      iconChanges.add((squadId, icon));
}

const linkedAccount = AccountLink(
  riotId: RiotId('Fulano', 'BR1'),
  puuid: 'puuid-123',
);

SquadMember makeMember(String uid, {String name = 'Fulano'}) => SquadMember(
  uid: uid,
  displayName: 'Nome $uid',
  riotId: RiotId(name, 'BR1'),
  puuid: 'puuid-$uid',
  profileIconUrl: null,
);

Squad makeSquad({
  String id = 'squad-1',
  String name = 'Os Brabos',
  List<SquadMember>? members,
}) => Squad(
  id: id,
  name: name,
  inviteCode: 'ABC234',
  ownerUid: 'uid-1',
  members:
      members ?? [makeMember('uid-1'), makeMember('uid-2', name: 'Ciclano')],
);
