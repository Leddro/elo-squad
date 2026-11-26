import 'package:elo_squad/core/error/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_push_service.dart';
import 'helpers/pump_app.dart';

void main() {
  testWidgets('deslogado: abre no login', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository());

    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);
  });

  testWidgets('logado: abre na busca', (tester) async {
    await pumpApp(tester);

    expect(find.text('Elo Squad'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('entrar leva à busca, e sair volta ao login', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository());

    await tester.tap(find.text('Entrar com Google'));
    await pumpFrames(tester);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byTooltip('Sair'));
    await pumpFrames(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sair'));
    await pumpFrames(tester);
    expect(find.text('Entrar com Google'), findsOneWidget);
  });

  testWidgets('sair desliga o push ANTES de sair da conta', (tester) async {
    final push = FakePushService();
    final auth = FakeAuthRepository(signedInAs: testUser);
    auth.onSignOut = () => push.events.add('signOut');
    await pumpApp(tester, auth: auth, push: push);

    await tester.tap(find.byTooltip('Sair'));
    await pumpFrames(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sair'));
    await pumpFrames(tester);

    // Na ordem inversa, o proxy recusaria o pedido (já sem login).
    expect(push.events, ['unregister', 'signOut']);
    expect(find.text('Entrar com Google'), findsOneWidget);
  });

  testWidgets('sair pede confirmação; cancelar mantém logado', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Sair'));
    await pumpFrames(tester);
    expect(find.text('Tem certeza que deseja sair?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await pumpFrames(tester);
    expect(find.text('Entrar com Google'), findsNothing);
  });

  testWidgets('login cancelado: continua no login, sem erro', (tester) async {
    final auth = FakeAuthRepository()..onSignIn = () async => false;
    await pumpApp(tester, auth: auth);

    await tester.tap(find.text('Entrar com Google'));
    await pumpFrames(tester);

    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('login sem internet: avisa e continua no login', (tester) async {
    final auth = FakeAuthRepository()
      ..onSignIn = () async => throw const NetworkFailure();
    await pumpApp(tester, auth: auth);

    await tester.tap(find.text('Entrar com Google'));
    await pumpFrames(tester);

    expect(find.text('Sem conexão. Verifique sua internet.'), findsOneWidget);
  });
}
