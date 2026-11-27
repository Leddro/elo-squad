import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:elo_squad/core/error/failure.dart';
import 'package:elo_squad/features/sciences/data/repositories/science_repository_impl.dart';
import 'package:elo_squad/features/sciences/domain/entities/science.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_science_repository.dart';
import '../../helpers/pump_app.dart';

ScienceItem item(int id, String name) =>
    ScienceItem(id: id, name: name, iconUrl: null);

ScienceBuild science(
  String title,
  String champion,
  ScienceRole role, {
  ScienceTier tier = ScienceTier.c,
}) => ScienceBuild(
  title: title,
  championName: champion,
  championIconUrl: null,
  role: role,
  items: [item(3089, 'Capuz da Morte'), item(3157, 'Ampulheta de Zhonya')],
  boots: item(3020, 'Sapatos do Feiticeiro'),
  skills: 'QEWQQRQEQEREEWWRWW',
  maxOrder: 'Q > E > W',
  tier: tier,
  games: 12,
  winRate: 0.75,
  pickRate: 0.042,
  banRate: 0.31,
);

SciencesBoard board() => SciencesBoard(
  patch: '16.23',
  updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
  builds: [
    science('Malphite AP no Mid', 'Malphite', ScienceRole.middle),
    science('Jinx Letalidade', 'Jinx', ScienceRole.bottom, tier: ScienceTier.s),
  ],
);

/// O chip do filtro da rota (o card também tem o ícone, com o mesmo Tooltip).
Finder roleChip(String label) =>
    find.ancestor(of: find.byTooltip(label), matching: find.byType(ChoiceChip));

void main() {
  Future<void> openSciences(
    WidgetTester tester,
    FakeScienceRepository sciences,
  ) async {
    await pumpApp(tester, sciences: sciences);
    await tester.tap(find.text('Ciências'));
    await pumpFrames(tester);
  }

  testWidgets('mostra título, campeão, rota, itens e habilidades', (
    tester,
  ) async {
    await openSciences(tester, FakeScienceRepository(board: board()));

    expect(
      find.textContaining('Patch 16.23 · atualizado há 2 h'),
      findsOneWidget,
    );
    expect(find.text('Malphite AP no Mid'), findsOneWidget);
    expect(find.text('Malphite'), findsOneWidget);
    // Rota pelo ícone (o nome só no Tooltip): no filtro e no card.
    expect(find.byTooltip('Mid'), findsNWidgets(2));
    expect(find.text('Mid'), findsNothing);
    expect(find.text('75,0%'), findsNWidgets(2));
    expect(find.text('4,2%'), findsNWidgets(2));
    expect(find.text('31,0%'), findsNWidgets(2));
    expect(find.text('Habilidades · Q > E > W'), findsNWidgets(2));
    expect(find.byTooltip('Capuz da Morte'), findsNWidgets(2));
    expect(find.byTooltip('Sapatos do Feiticeiro'), findsNWidgets(2));
    expect(find.byTooltip('Nível 18'), findsNWidgets(2));
  });

  testWidgets('filtro por rota', (tester) async {
    await openSciences(tester, FakeScienceRepository(board: board()));

    await tester.ensureVisible(roleChip('Bot'));
    await tester.tap(roleChip('Bot'));
    await pumpFrames(tester);
    expect(find.text('Jinx Letalidade'), findsOneWidget);
    expect(find.text('Malphite AP no Mid'), findsNothing);

    await tester.ensureVisible(roleChip('Top'));
    await tester.tap(roleChip('Top'));
    await pumpFrames(tester);
    expect(find.text('Nenhuma ciência nesta rota'), findsOneWidget);
  });

  testWidgets('organiza por tier: o melhor primeiro', (tester) async {
    await openSciences(tester, FakeScienceRepository(board: board()));

    expect(find.text('Tier S'), findsOneWidget);
    expect(find.text('Tier C'), findsOneWidget);
    expect(find.text('Tier A'), findsNothing);
    final jinx = tester.getTopLeft(find.text('Jinx Letalidade')).dy;
    final malphite = tester.getTopLeft(find.text('Malphite AP no Mid')).dy;
    expect(jinx, lessThan(malphite));
  });

  testWidgets('sem nada publicado: explica', (tester) async {
    await openSciences(tester, FakeScienceRepository());
    expect(find.text('Nenhuma ciência ainda'), findsOneWidget);
  });

  testWidgets('erro: mensagem curta', (tester) async {
    await openSciences(
      tester,
      FakeScienceRepository(error: const NoConnectionFailure()),
    );
    expect(find.text('Sem conexão. Verifique sua internet.'), findsOneWidget);
  });

  test('lê sciences/current no formato do backend', () async {
    final db = FakeFirebaseFirestore();
    Map<String, Object?> buildJson(String role) => {
      'championId': 54,
      'championName': 'Malphite',
      'championIconUrl': 'https://x/Malphite.png',
      'role': role,
      'roleName': 'Mid',
      'title': 'Malphite AP no Mid',
      'items': [
        {'id': 3089, 'name': 'Capuz da Morte', 'iconUrl': 'https://x/3089.png'},
      ],
      'boots': null,
      'skills': 'QEW',
      'maxOrder': 'Q > E > W',
      'games': 12,
      'wins': 9,
      'tier': 'A',
      'winRate': 0.75,
      'pickRate': 0.04,
      'banRate': 0,
    };
    await db.collection('sciences').doc('current').set({
      'patch': '16.23',
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 26, 9)),
      'builds': [buildJson('MIDDLE'), buildJson('ARAM')],
    });

    final result = await ScienceRepositoryImpl(db).watchCurrent().first;

    expect(result!.patch, '16.23');
    expect(result.updatedAt, DateTime.utc(2026, 11, 26, 9));
    // Rota desconhecida é ignorada.
    expect(result.builds, hasLength(1));
    expect(result.builds.single.role, ScienceRole.middle);
    expect(result.builds.single.boots, isNull);
    expect(result.builds.single.tier, ScienceTier.a);
    expect(result.builds.single.winRate, 0.75);
    expect(result.builds.single.banRate, 0);
  });

  test('documento ausente: null', () async {
    final result = await ScienceRepositoryImpl(FakeFirebaseFirestore())
        .watchCurrent()
        .first;
    expect(result, isNull);
  });
}
