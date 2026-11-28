import 'package:elo_squad/features/squads/domain/entities/squad.dart';
import 'package:elo_squad/features/squads/domain/entities/squad_ranking.dart';
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
  int bonus = 0,
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
  bonus: bonus,
  points: delta == null ? null : delta + bonus,
  scienceWins: [
    if (bonus > 0)
      ScienceWin(
        matchId: 'BR1_1',
        playedAt: DateTime.utc(2026, 11, 25, 15),
        championName: 'Malphite',
        title: 'Malphite AP no Mid',
        tier: 'D',
        bonus: bonus,
      ),
  ],
);

SquadRanking ranking({bool isFinal = false}) => SquadRanking(
  periodId: '2026-W48',
  // Meio-dia UTC: a mesma data em qualquer fuso do CI.
  startsAt: DateTime.utc(2026, 11, 23, 12),
  endsAt: DateTime.utc(2026, 11, 30, 12),
  updatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
  isFinal: isFinal,
  entries: [
    rankingEntry('uid-2', 'Ciclano', delta: 56, games: 3, bonus: 20),
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

  testWidgets('ranking do período: ordem, pontos, partidas e o troféu', (
    tester,
  ) async {
    final squads = FakeSquadRepository(
      account: linkedAccount,
      squads: [makeSquad()],
    )..rankings['squad-1'] = ranking();

    await openSquad(tester, squads);

    expect(find.text('Ranking do período'), findsOneWidget);
    expect(find.textContaining('23/11 a 30/11 · '), findsOneWidget);
    expect(find.textContaining('atualizado há 20 min'), findsOneWidget);
    expect(find.text('🏆'), findsOneWidget);
    expect(find.text('+76 pts'), findsOneWidget); // 56 PDL + 20 de Ciência
    expect(find.text('🧪 +20'), findsOneWidget);
    expect(find.text('Ouro I · 3 partidas'), findsOneWidget);
    expect(find.text('-12 pts'), findsOneWidget);
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

    expect(find.text('Resultado final de 23/11 a 30/11'), findsOneWidget);
  });

  testWidgets('tocar no jogador mostra o PDL e as vitórias com Ciência', (
    tester,
  ) async {
    final squads = FakeSquadRepository(
      account: linkedAccount,
      squads: [makeSquad()],
    )..rankings['squad-1'] = ranking();
    await openSquad(tester, squads);

    await tester.tap(find.text('+76 pts'));
    await pumpFrames(tester);

    expect(find.text('+56 pts'), findsOneWidget); // PDL
    expect(find.text('Malphite AP no Mid'), findsOneWidget);
    expect(find.text('Tier D · 25/11'), findsOneWidget);
    expect(find.text('Ver perfil'), findsOneWidget);
  });

  testWidgets('medalhas dos pódios ao lado do nome', (tester) async {
    final squad = makeSquad().copyWith(
      podiums: [
        Podium(
          periodId: '2026-W47',
          startsAt: DateTime.utc(2026, 11, 16, 12),
          endsAt: DateTime.utc(2026, 11, 23, 12),
          places: const ['uid-2', 'uid-1'],
          points: const [40, 10],
        ),
      ],
    );
    final squads = FakeSquadRepository(account: linkedAccount, squads: [squad])
      ..rankings['squad-1'] = ranking();
    await openSquad(tester, squads);

    expect(
      find.text(
        'Ciclano#BR1  🥇'
        '1',
      ),
      findsOneWidget,
    );
    expect(find.text('Pódios'), findsOneWidget);
  });

  testWidgets('o líder define o período', (tester) async {
    final squads = FakeSquadRepository(
      account: linkedAccount,
      squads: [makeSquad()],
    );
    await openSquad(tester, squads);

    await tester.tap(find.byTooltip('Configurações'));
    await pumpFrames(tester);
    await tester.tap(find.text('Período de disputa'));
    await pumpFrames(tester);
    await tester.tap(find.text('2 semanas'));
    await pumpFrames(tester);
    await tester.tap(find.text('Começar'));
    await pumpFrames(tester);

    expect(squads.periodChanges.single.$2, PeriodLength.twoWeeks);
    expect(squads.periodChanges.single.$5, isTrue);
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
