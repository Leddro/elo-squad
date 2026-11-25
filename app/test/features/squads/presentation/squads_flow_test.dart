import 'package:elo_squad/core/error/failure.dart';
import 'package:elo_squad/features/squads/presentation/pages/link_riot_id_page.dart';
import 'package:elo_squad/features/squads/presentation/pages/squad_detail_page.dart';
import 'package:elo_squad/features/summoner/domain/entities/riot_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/fake_squad_repository.dart';
import '../../../helpers/pump_app.dart';

void main() {
  /// Sobe o app logado (como uid-1) e abre a aba Squads.
  Future<void> openSquadsTab(
    WidgetTester tester,
    FakeSquadRepository squads,
  ) async {
    await pumpApp(tester, squads: squads);
    await tester.tap(find.text('Squads'));
    await pumpFrames(tester);
  }

  testWidgets('sem Riot ID: pede o vínculo, e vincular volta à lista', (
    tester,
  ) async {
    RiotId? linked;
    final squads = FakeSquadRepository();
    squads.onLink = (riotId) async {
      linked = riotId;
      squads.setAccount(linkedAccount);
      return const RiotId('Fulano', 'BR1');
    };
    await openSquadsTab(tester, squads);
    expect(find.text('Vincule o seu Riot ID'), findsOneWidget);
    expect(find.text('Novo'), findsNothing); // sem Riot ID não cria squad

    await tester.tap(find.text('Vincular Riot ID'));
    await pumpFrames(tester);
    expect(find.byType(LinkRiotIdPage), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'fulano#br1');
    await tester.tap(find.text('Vincular'));
    await pumpFrames(tester);

    expect(linked, const RiotId('fulano', 'br1'));
    expect(find.byType(LinkRiotIdPage), findsNothing);
    expect(find.text('Riot ID vinculado: Fulano#BR1'), findsOneWidget);
    expect(find.textContaining('nenhum squad'), findsOneWidget);
  });

  testWidgets('Riot ID inválido: erro no campo, sem chamar o proxy', (
    tester,
  ) async {
    var calls = 0;
    final squads = FakeSquadRepository()
      ..onLink = (id) async {
        calls++;
        return id;
      };
    await openSquadsTab(tester, squads);
    await tester.tap(find.text('Vincular Riot ID'));
    await pumpFrames(tester);

    await tester.enterText(find.byType(TextField), 'semtag');
    await tester.tap(find.text('Vincular'));
    await pumpFrames(tester);

    expect(find.textContaining('nome#tag'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('lista os squads e abre o detalhe com código e membros', (
    tester,
  ) async {
    await openSquadsTab(
      tester,
      FakeSquadRepository(account: linkedAccount, squads: [makeSquad()]),
    );
    expect(find.text('Os Brabos'), findsOneWidget);
    expect(find.text('2 membros'), findsOneWidget);

    await tester.tap(find.text('Os Brabos'));
    await pumpFrames(tester);

    expect(find.byType(SquadDetailPage), findsOneWidget);
    expect(find.text('ABC234'), findsOneWidget);
    expect(find.text('Fulano#BR1'), findsOneWidget);
    expect(find.text('Nome uid-1 · líder · você'), findsOneWidget);
    expect(find.text('Ciclano#BR1'), findsOneWidget);
  });

  testWidgets('criar um squad abre o squad novo', (tester) async {
    final squads = FakeSquadRepository(account: linkedAccount);
    String? createdName;
    squads.onCreate = (name) async {
      createdName = name;
      squads.setSquads([makeSquad(id: 'novo-id', name: name)]);
      return 'novo-id';
    };
    await openSquadsTab(tester, squads);

    await tester.tap(find.text('Novo'));
    await pumpFrames(tester);
    await tester.tap(find.text('Criar um squad'));
    await pumpFrames(tester);
    await tester.enterText(find.byType(TextField), 'Time da Madrugada');
    await tester.tap(find.text('Criar'));
    await pumpFrames(tester);

    expect(createdName, 'Time da Madrugada');
    expect(find.byType(SquadDetailPage), findsOneWidget);
    expect(find.text('Time da Madrugada'), findsWidgets); // título
  });

  testWidgets('código inválido: avisa e continua na lista', (tester) async {
    final squads = FakeSquadRepository(account: linkedAccount)
      ..onJoin = (_) async => throw const SquadFailure(SquadProblem.notFound);
    await openSquadsTab(tester, squads);

    await tester.tap(find.text('Novo'));
    await pumpFrames(tester);
    await tester.tap(find.text('Entrar com um código'));
    await pumpFrames(tester);
    await tester.enterText(find.byType(TextField), 'zzzzzz');
    await tester.tap(find.text('Entrar'));
    await pumpFrames(tester);

    expect(find.text('Código de convite inválido.'), findsOneWidget);
    expect(find.byType(SquadDetailPage), findsNothing);
  });

  testWidgets('sair do squad, confirmando, volta à lista', (tester) async {
    final squads = FakeSquadRepository(
      account: linkedAccount,
      squads: [makeSquad()],
    );
    await openSquadsTab(tester, squads);
    await tester.tap(find.text('Os Brabos'));
    await pumpFrames(tester);

    await tester.tap(find.byType(PopupMenuButton<void>));
    await pumpFrames(tester);
    await tester.tap(find.text('Sair do squad'));
    await pumpFrames(tester);
    expect(find.text('Sair de Os Brabos?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sair'));
    await pumpFrames(tester);

    expect(squads.leftSquads, ['squad-1']);
    expect(find.byType(SquadDetailPage), findsNothing);
  });
}
