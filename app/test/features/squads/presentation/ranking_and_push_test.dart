import 'package:elo_squad/features/squads/domain/entities/weekly_ranking.dart';
import 'package:elo_squad/features/squads/presentation/pages/squad_detail_page.dart';
import 'package:elo_squad/features/summoner/domain/entities/ranked.dart';
import 'package:elo_squad/features/summoner/domain/entities/riot_id.dart';
import 'package:elo_squad/features/summoner/domain/entities/tier.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_push_service.dart';
import '../../../helpers/fake_squad_repository.dart';
import '../../../helpers/pump_app.dart';

RankingEntry rankingEntry(
  String uid,
  String name, {
  int? delta,
  int games = 0,
  bool ranked = true,
}) => RankingEntry(
  uid: uid,
  displayName: null,
  riotId: RiotId(name, 'BR1'),
  profileIconUrl: null,
  current: ranked
      ? const RankedEntry(
          tier: Tier.gold,
          division: Division.i,
          lp: 10,
          wins: 13,
          losses: 10,
        )
      : null,
  lpDelta: delta,
  games: games,
);

WeeklyRanking ranking({bool isFinal = false}) => WeeklyRanking(
  weekId: '2026-W48',
  weekStart: DateTime.utc(2026, 11, 23, 3),
  updatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
  isFinal: isFinal,
  entries: [
    rankingEntry('uid-2', 'Ciclano', delta: 56, games: 3),
    rankingEntry('uid-1', 'Fulano', delta: -12, games: 1),
    rankingEntry('uid-3', 'Beltrano', ranked: false),
  ],
);

void main() {
  Future<void> openSquad(
    WidgetTester tester,
    FakeSquadRepository squads,
  ) async {
    await pumpApp(tester, squads: squads);
    await tester.tap(find.text('Squads'));
    await pumpFrames(tester);
    await tester.tap(find.text('Os Brabos'));
    await pumpFrames(tester);
    await tester.tap(find.text('Abrir squad'));
    await pumpFrames(tester);
  }

  testWidgets('ranking da semana: ordem, PDL, partidas e o troféu', (
    tester,
  ) async {
    final squads = FakeSquadRepository(
      account: linkedAccount,
      squads: [makeSquad()],
    )..rankings['squad-1'] = ranking();

    await openSquad(tester, squads);

    expect(find.text('Ranking da semana'), findsOneWidget);
    expect(
      find.textContaining('Semana de 23/11 · atualizado há 20 min'),
      findsOneWidget,
    );
    expect(find.text('🏆'), findsOneWidget);
    expect(find.text('+56 PDL'), findsOneWidget);
    expect(find.text('Ouro I · 3 partidas'), findsOneWidget);
    expect(find.text('-12 PDL'), findsOneWidget);
    expect(find.text('Ouro I · 1 partida'), findsOneWidget);
    expect(find.text('Sem ranque'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('semana fechada mostra o resultado final', (tester) async {
    final squads = FakeSquadRepository(
      account: linkedAccount,
      squads: [makeSquad()],
    )..rankings['squad-1'] = ranking(isFinal: true);

    await openSquad(tester, squads);

    expect(find.text('Resultado final da semana de 23/11'), findsOneWidget);
  });

  testWidgets('sem ranking ainda: explica quando aparece', (tester) async {
    await openSquad(
      tester,
      FakeSquadRepository(account: linkedAccount, squads: [makeSquad()]),
    );

    expect(find.text('O ranking ainda não foi calculado.'), findsOneWidget);
  });

  group('push', () {
    testWidgets('logado: registra o aparelho uma vez', (tester) async {
      final push = FakePushService();
      await pumpApp(tester, push: push);

      expect(push.registerCalls, 1);
    });

    testWidgets('deslogado: só registra depois do login', (tester) async {
      final push = FakePushService();
      await pumpApp(tester, auth: FakeAuthRepository(), push: push);
      expect(push.registerCalls, 0);

      await tester.tap(find.text('Entrar com Google'));
      await pumpFrames(tester);

      expect(push.registerCalls, 1);
    });

    testWidgets('notificação com o app aberto vira um aviso', (tester) async {
      final push = FakePushService();
      await pumpApp(tester, push: push);

      push.receive((
        title: 'Ciclano subiu de elo!',
        body: 'Ciclano#BR1 agora é Ouro I (Os Brabos).',
        squadId: 'squad-1',
      ));
      await pumpFrames(tester);

      expect(find.textContaining('Ciclano subiu de elo!'), findsOneWidget);
    });

    testWidgets('tocar na notificação abre o squad', (tester) async {
      final push = FakePushService();
      await pumpApp(
        tester,
        push: push,
        squads: FakeSquadRepository(
          account: linkedAccount,
          squads: [makeSquad()],
        ),
      );

      push.tap('squad-1');
      await pumpFrames(tester);

      expect(find.byType(SquadDetailPage), findsOneWidget);
      expect(find.text('ABC234'), findsOneWidget);
    });
  });
}
