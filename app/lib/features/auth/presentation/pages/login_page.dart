import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/failure_messages.dart';
import '../../../../core/presentation/theme/brand_colors.dart';
import '../../../../core/presentation/widgets/elo_squad_logo.dart';
import '../../data/auth_providers.dart';

/// Tela de entrada: e-mail e senha (entrar ou criar conta) ou Google.
/// Depois do login, o roteador leva à home sozinho (ele observa o
/// authStateProvider).
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _creating = false; // false = entrar; true = criar conta
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      _show(shortFailureMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final auth = ref.read(authRepositoryProvider);
    final email = _email.text.trim();
    _run(
      () => _creating
          ? auth.createAccount(
              name: _name.text.trim(),
              email: email,
              password: _password.text,
            )
          : auth.signInWithEmail(email: email, password: _password.text),
    );
  }

  void _resetPassword() {
    final email = _email.text.trim();
    if (_validateEmail(email) case final String problem) {
      _show('Para redefinir a senha: $problem');
      return;
    }
    _run(() async {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      _show(
        'Se houver uma conta com este e-mail, enviamos um link para '
        'redefinir a senha.',
      );
    });
  }

  static String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'informe o e-mail.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'e-mail inválido.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: _loginTheme,
    child: Builder(builder: _build),
  );

  /// Tema da entrada: sempre escuro, nas cores hextech da marca.
  static final _loginTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: BrandColors.gold,
          brightness: Brightness.dark,
        ).copyWith(
          primary: BrandColors.gold,
          onPrimary: BrandColors.void0,
          secondary: BrandColors.red,
          surface: BrandColors.navy,
          outline: BrandColors.goldDark,
        ),
    scaffoldBackgroundColor: Colors.transparent,
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0x660A1428),
      border: OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: BrandColors.goldDark),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BrandColors.goldLight,
        side: const BorderSide(color: BrandColors.gold),
        shape: const BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  );

  Widget _build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.5),
          radius: 1.2,
          colors: [Color(0xFF13233D), BrandColors.void0],
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: EloSquadLogo(width: 220)),
                        const SizedBox(height: 12),
                        Text(
                          'Elo, partidas, ciências e o ranking do seu squad.',
                          style: text.bodyMedium?.copyWith(
                            color: BrandColors.goldLight.withValues(alpha: 0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        if (_creating) ...[
                          TextFormField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'Nome',
                              helperText: 'Como o seu squad vai te ver.',
                            ),
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            maxLength: 30,
                            validator: (value) => (value?.trim() ?? '').isEmpty
                                ? 'Informe o nome.'
                                : null,
                          ),
                          const SizedBox(height: 8),
                        ],
                        TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          validator: (value) => switch (_validateEmail(value)) {
                            final String problem =>
                              '${problem[0].toUpperCase()}${problem.substring(1)}',
                            null => null,
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          decoration: const InputDecoration(labelText: 'Senha'),
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: [
                            _creating
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          onFieldSubmitted: (_) => _busy ? null : _submit(),
                          validator: (value) {
                            final password = value ?? '';
                            if (password.isEmpty) return 'Informe a senha.';
                            if (_creating && password.length < 6) {
                              return 'Use pelo menos 6 caracteres.';
                            }
                            return null;
                          },
                        ),
                        if (!_creating)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy ? null : _resetPassword,
                              child: const Text('Esqueci a senha'),
                            ),
                          )
                        else
                          const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: Text(_creating ? 'Criar conta' : 'Entrar'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _creating = !_creating;
                                  _form.currentState?.reset();
                                }),
                          child: Text(
                            _creating
                                ? 'Já tem conta? Entrar'
                                : 'Não tem conta? Criar conta',
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('ou'),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  ref
                                      .read(authRepositoryProvider)
                                      .signInWithGoogle,
                                ),
                          icon: const Icon(Icons.login),
                          label: const Text('Entrar com Google'),
                        ),
                        if (_busy) ...[
                          const SizedBox(height: 24),
                          const Center(child: CircularProgressIndicator()),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
