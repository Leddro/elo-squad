import 'package:material_ui/material_ui.dart';

import '../../domain/entities/riot_id.dart';
import 'profile_page.dart';

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
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ProfilePage(riotId: riotId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Elo Squad')),
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
                    Icon(
                      Icons.person_search,
                      size: 72,
                      color: theme.colorScheme.primary,
                    ),
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
