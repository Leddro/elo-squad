import 'package:elo_squad/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // Smoke test: o app sobe e abre na tela de busca.
  testWidgets('o app abre na tela de busca', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EloSquadApp()));

    expect(find.text('Elo Squad'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
