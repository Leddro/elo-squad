import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/run_action.dart';
import '../../../summoner/domain/entities/riot_id.dart';
import '../../data/squad_data_providers.dart';

/// Vincula o Riot ID do usuário à conta (o proxy confere se existe na Riot).
class LinkRiotIdPage extends ConsumerStatefulWidget {
  const LinkRiotIdPage({super.key});

  @override
  ConsumerState<LinkRiotIdPage> createState() => _LinkRiotIdPageState();
}

class _LinkRiotIdPageState extends ConsumerState<LinkRiotIdPage> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final riotId = RiotId.tryParse(_controller.text);
    if (riotId == null) {
      setState(
        () => _errorText = 'Use o formato nome#tag. Exemplo: Fulano#BR1',
      );
      return;
    }
    setState(() => _errorText = null);
    FocusScope.of(context).unfocus();

    final linked = await runAction(
      context,
      () => ref.read(squadRepositoryProvider).linkRiotId(riotId),
    );
    if (linked != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Riot ID vinculado: $linked')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vincular Riot ID')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Digite o seu Riot ID, do jeito que aparece no cliente do jogo.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Riot ID',
                hintText: 'Fulano#BR1',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('Vincular')),
          ],
        ),
      ),
    );
  }
}
