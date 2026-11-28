import 'package:dio/dio.dart';
import 'package:elo_squad/core/error/failure.dart';
import 'package:elo_squad/features/squads/data/datasources/squad_firestore_data_source.dart';
import 'package:elo_squad/features/squads/data/datasources/squad_remote_data_source.dart';
import 'package:elo_squad/features/squads/data/repositories/squad_repository_impl.dart';
import 'package:elo_squad/features/squads/domain/entities/squad.dart';
import 'package:elo_squad/features/summoner/domain/entities/riot_id.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_http.dart';

// Firestore FALSO em memória (fake_cloud_firestore) + rede falsa do Dio: os
// documentos têm o mesmo formato que o proxy grava.

Map<String, dynamic> memberDoc(String uid, String name) => {
  'uid': uid,
  'displayName': 'Nome $uid',
  'riotId': {'gameName': name, 'tagLine': 'BR1'},
  'puuid': 'puuid-$uid',
  'profileIconUrl': null,
};

Map<String, dynamic> squadDoc(String name, List<String> uids) => {
  'name': name,
  'inviteCode': 'ABC234',
  'ownerUid': uids.first,
  'memberUids': uids,
  'members': {for (final uid in uids) uid: memberDoc(uid, 'Jogador $uid')},
  'createdAt': DateTime.utc(2026, 11, 25), // ignorado pelo app
};

void main() {
  late FakeFirebaseFirestore db;
  late FakeHttpAdapter adapter;
  late SquadRepositoryImpl repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    adapter = FakeHttpAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://proxy.test'))
      ..httpClientAdapter = adapter;
    repository = SquadRepositoryImpl(
      SquadFirestoreDataSource(db),
      SquadRemoteDataSource(dio),
    );
  });

  group('leituras do Firestore', () {
    test('conta sem documento: ainda sem Riot ID', () async {
      final account = await repository.watchAccount('a').first;

      expect(account, AccountLink.empty);
      expect(account.hasRiotId, isFalse);
    });

    test('conta com Riot ID vinculado', () async {
      await db.collection('users').doc('a').set({
        'riotId': {'gameName': 'Fulano', 'tagLine': 'BR1'},
        'puuid': 'puuid-a',
        'squadIds': ['s1'],
        'fcmTokens': ['t'],
      });

      final account = await repository.watchAccount('a').first;

      expect(account.riotId, const RiotId('Fulano', 'BR1'));
      expect(account.hasRiotId, isTrue);
    });

    test('meus squads: só os que tenho, em ordem alfabética', () async {
      await db.collection('squads').doc('s1').set(squadDoc('zebras', ['a']));
      await db
          .collection('squads')
          .doc('s2')
          .set(squadDoc('Alfas', ['b', 'a']));
      await db.collection('squads').doc('s3').set(squadDoc('Outros', ['b']));

      final squads = await repository.watchMySquads('a').first;

      expect([for (final s in squads) s.name], ['Alfas', 'zebras']);
    });

    test('squad: membros na ordem de entrada', () async {
      await db
          .collection('squads')
          .doc('s1')
          .set(squadDoc('X', ['c', 'a', 'b']));

      final squad = (await repository.watchSquad('s1').first)!;

      expect([for (final m in squad.members) m.uid], ['c', 'a', 'b']);
      expect(squad.members.first.riotId, const RiotId('Jogador c', 'BR1'));
      expect(squad.isOwner('c'), isTrue);
    });

    test('ranking mais recente: Timestamp e o campo `final`', () async {
      final rankings = db.collection('squads').doc('s1').collection('rankings');
      Map<String, dynamic> doc(String week, DateTime start, bool isFinal) => {
        'periodId': week,
        'startsAt': start, // o fake guarda como Timestamp, igual ao real
        'endsAt': start.add(const Duration(days: 7)),
        'updatedAt': start.add(const Duration(days: 1)),
        'final': isFinal,
        'entries': [
          {
            'uid': 'a',
            'displayName': null,
            'riotId': {'gameName': 'Fulano', 'tagLine': 'BR1'},
            'profileIconUrl': null,
            'current': {
              'tier': 'GOLD',
              'division': 'I',
              'lp': 10,
              'wins': 13,
              'losses': 10,
            },
            'lpDelta': 56,
            'games': 3,
            'bonus': 20,
            'points': 76,
            'scienceWins': [
              {
                'matchId': 'BR1_1',
                'playedAt': start.add(const Duration(hours: 5)),
                'championName': 'Malphite',
                'title': 'Malphite AP no Mid',
                'tier': 'D',
                'bonus': 20,
              },
            ],
          },
        ],
      };
      await rankings
          .doc('2026-W47')
          .set(doc('2026-W47', DateTime.utc(2026, 11, 16, 3), true));
      await rankings
          .doc('2026-W48')
          .set(doc('2026-W48', DateTime.utc(2026, 11, 23, 3), false));

      final ranking = (await repository.watchLatestRanking('s1').first)!;

      expect(ranking.periodId, '2026-W48'); // o período mais novo
      expect(ranking.isFinal, isFalse);
      expect(ranking.startsAt, DateTime.utc(2026, 11, 23, 3));
      expect(ranking.endsAt, DateTime.utc(2026, 11, 30, 3));
      expect(ranking.entries.single.lpDelta, 56);
      expect(ranking.entries.single.points, 76);
      expect(ranking.entries.single.scienceWins.single.tier, 'D');
      expect(ranking.entries.single.current!.lp, 10);
    });

    test('sem ranking ainda: null', () async {
      expect(await repository.watchLatestRanking('s1').first, isNull);
    });

    test('squad apagado: null', () async {
      expect(await repository.watchSquad('nao-existe').first, isNull);
    });
  });

  group('escritas pelo proxy', () {
    test(
      'vincular Riot ID: PUT /me/riot-id e devolve a grafia oficial',
      () async {
        adapter.respond = (_) => jsonResponse({
          'riotId': {'gameName': 'Fulano', 'tagLine': 'BR1'},
          'puuid': 'puuid-a',
        });

        final riotId = await repository.linkRiotId(
          const RiotId('fulano', 'br1'),
        );

        final request = adapter.requests.single;
        expect(request.method, 'PUT');
        expect(request.path, '/me/riot-id');
        expect(request.data, {'gameName': 'fulano', 'tagLine': 'br1'});
        expect(riotId.gameName, 'Fulano'); // a grafia da Riot
      },
    );

    test('criar e entrar devolvem o id do squad', () async {
      adapter.respond = (_) =>
          jsonResponse({'id': 'squad-9', 'inviteCode': 'ABC234'});

      expect(await repository.createSquad('Os Brabos'), 'squad-9');
      expect(await repository.joinSquad('ABC234'), 'squad-9');
      expect(adapter.requests.last.data, {'inviteCode': 'ABC234'});
    });

    test('código inválido → SquadFailure(notFound)', () async {
      adapter.respond = (_) => jsonResponse({
        'code': 'SQUAD_NOT_FOUND',
        'message': '...',
      }, status: 404);

      await expectLater(
        repository.joinSquad('ZZZZZZ'),
        throwsA(
          isA<SquadFailure>().having(
            (f) => f.problem,
            'problem',
            SquadProblem.notFound,
          ),
        ),
      );
    });

    test('sair: POST /squads/{id}/leave', () async {
      adapter.respond = (_) => ResponseBody.fromString('', 204);

      await repository.leaveSquad('squad-9');

      expect(adapter.requests.single.path, '/squads/squad-9/leave');
    });
  });
}
