import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/pump_app.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  testWidgets('entrar com e-mail e senha leva à busca', (tester) async {
    final auth = FakeAuthRepository()..accounts['eu@ex.com'] = 'segredo1';
    await pumpApp(tester, auth: auth);

    await tester.enterText(field('E-mail'), 'eu@ex.com');
    await tester.enterText(field('Senha'), 'segredo1');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await pumpFrames(tester);

    expect(find.text('Entrar com Google'), findsNothing);
  });

  testWidgets('senha errada: avisa e continua no login', (tester) async {
    final auth = FakeAuthRepository()..accounts['eu@ex.com'] = 'segredo1';
    await pumpApp(tester, auth: auth);

    await tester.enterText(field('E-mail'), 'eu@ex.com');
    await tester.enterText(field('Senha'), 'errada');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await pumpFrames(tester);

    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    expect(find.text('Entrar com Google'), findsOneWidget);
  });

  testWidgets('campos inválidos não chegam ao Firebase', (tester) async {
    await pumpApp(tester, auth: FakeAuthRepository());

    await tester.enterText(field('E-mail'), 'sem-arroba');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await pumpFrames(tester);

    expect(find.text('E-mail inválido.'), findsOneWidget);
    expect(find.text('Informe a senha.'), findsOneWidget);
  });

  testWidgets('criar conta pede nome e senha de 6+ e entra', (tester) async {
    final auth = FakeAuthRepository();
    await pumpApp(tester, auth: auth);

    await tester.tap(find.text('Não tem conta? Criar conta'));
    await pumpFrames(tester);
    await tester.enterText(field('E-mail'), 'novo@ex.com');
    await tester.enterText(field('Senha'), '123');
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await pumpFrames(tester);
    expect(find.text('Informe o nome.'), findsOneWidget);
    expect(find.text('Use pelo menos 6 caracteres.'), findsOneWidget);

    await tester.enterText(field('Nome'), 'Fulano');
    await tester.enterText(field('Senha'), '123456');
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await pumpFrames(tester);

    expect(auth.accounts, {'novo@ex.com': '123456'});
    expect(find.text('Entrar com Google'), findsNothing);
  });

  testWidgets('e-mail já cadastrado: avisa', (tester) async {
    final auth = FakeAuthRepository()..accounts['eu@ex.com'] = 'segredo1';
    await pumpApp(tester, auth: auth);

    await tester.tap(find.text('Não tem conta? Criar conta'));
    await pumpFrames(tester);
    await tester.enterText(field('Nome'), 'Eu');
    await tester.enterText(field('E-mail'), 'eu@ex.com');
    await tester.enterText(field('Senha'), 'outra123');
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await pumpFrames(tester);

    expect(find.text('Já existe uma conta com este e-mail.'), findsOneWidget);
  });

  testWidgets('esqueci a senha: manda o link para o e-mail digitado', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpApp(tester, auth: auth);

    await tester.tap(find.text('Esqueci a senha'));
    await pumpFrames(tester);
    expect(
      find.text('Para redefinir a senha: informe o e-mail.'),
      findsOneWidget,
    );

    await tester.enterText(field('E-mail'), 'eu@ex.com');
    await tester.tap(find.text('Esqueci a senha'));
    await pumpFrames(tester);

    expect(auth.resetEmails, ['eu@ex.com']);
    expect(find.textContaining('enviamos um link'), findsOneWidget);
  });
}
