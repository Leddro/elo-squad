import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/widgets/elo_squad_logo.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/sign_out.dart';
import '../../domain/entities/riot_id.dart';

/// Tela inicial: barra de busca.
///
/// StatefulWidget (e não Riverpod) de propósito: o texto digitado e a mensagem
/// de erro do campo são ESTADO EFÊMERO, que só esta tela usa e que pode sumir
/// quando ela fecha. Riverpod é para estado compartilhado ou que vem de fora
/// (como o perfil buscado).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    // Validação ANTES de qualquer requisição: Riot ID inválido nem sai do celular.
    final riotId = RiotId.tryParse(_controller.text);
    if (riotId == null) {
      setState(
        () => _errorText = 'Use o formato nome#tag. Exemplo: Fulano#BR1',
      );
      return;
    }

    setState(() => _errorText = null);
    FocusScope.of(context).unfocus(); // fecha o teclado
    // Pelo NOME da rota; o go_router monta e codifica o caminho.
    context.pushNamed(
      Routes.profile,
      pathParameters: {'gameName': riotId.gameName, 'tagLine': riotId.tagLine},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elo Squad'),
        actions: const [_SignOutButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Riot ID',
                hintText: 'Fulano#BR1',
                errorText: _errorText,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Buscar',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _search,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EloSquadEmblem(size: 96),
                    const SizedBox(height: 16),
                    Text(
                      'Busque um invocador pelo Riot ID',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: 'Sair',
    icon: const Icon(Icons.logout),
    onPressed: () async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sair da conta?'),
          content: const Text('Tem certeza que deseja sair?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sair'),
            ),
          ],
        ),
      );
      // Depois do logout, o roteador leva ao login sozinho.
      if (confirmed ?? false) await ref.read(signOutProvider)();
    },
  );
}
