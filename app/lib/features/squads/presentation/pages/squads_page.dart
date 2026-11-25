import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/failure_messages.dart';
import '../../../../core/presentation/run_action.dart';
import '../../../../core/router/app_router.dart';
import '../../data/squad_data_providers.dart';
import '../../domain/entities/squad.dart';
import '../providers/squad_providers.dart';

/// Aba "Squads": a lista dos squads do usuário e as ações de criar e entrar.
class SquadsPage extends ConsumerWidget {
  const SquadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final hasRiotId = account.value?.hasRiotId ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Squads')),
      floatingActionButton: hasRiotId
          ? FloatingActionButton.extended(
              onPressed: () => _showNewSquadSheet(context, ref),
              icon: const Icon(Icons.group_add),
              label: const Text('Novo'),
            )
          : null,
      body: switch (account) {
        AsyncValue(:final value?) when !value.hasRiotId =>
          const _LinkRiotIdPrompt(),
        AsyncValue(hasValue: true) => const _SquadList(),
        AsyncValue(:final error?) => _Message(shortFailureMessage(error)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _showNewSquadSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Criar um squad'),
              onTap: () {
                Navigator.pop(sheetContext);
                _create(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.vpn_key),
              title: const Text('Entrar com um código'),
              onTap: () {
                Navigator.pop(sheetContext);
                _join(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await _askText(
      context,
      title: 'Novo squad',
      label: 'Nome do squad',
      action: 'Criar',
      maxLength: 30,
    );
    if (name == null || !context.mounted) return;
    final id = await runAction(
      context,
      () => ref.read(squadRepositoryProvider).createSquad(name),
    );
    if (id != null && context.mounted) _open(context, id);
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final code = await _askText(
      context,
      title: 'Entrar num squad',
      label: 'Código de convite',
      action: 'Entrar',
      maxLength: 6,
      uppercase: true,
    );
    if (code == null || !context.mounted) return;
    final id = await runAction(
      context,
      () => ref.read(squadRepositoryProvider).joinSquad(code),
    );
    if (id != null && context.mounted) _open(context, id);
  }

  void _open(BuildContext context, String squadId) =>
      context.pushNamed(Routes.squad, pathParameters: {'squadId': squadId});
}

/// Pergunta um texto num diálogo. Devolve null se cancelado ou vazio.
Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  required int maxLength,
  bool uppercase = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextInputDialog(
    title: title,
    label: label,
    action: action,
    maxLength: maxLength,
    uppercase: uppercase,
  ),
);

/// O diálogo é dono do próprio controller: ele só é descartado quando o
/// diálogo some de vez, depois da animação de saída (durante ela, o campo
/// ainda é desenhado e usa o controller).
class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.action,
    required this.maxLength,
    required this.uppercase,
  });

  final String title;
  final String label;
  final String action;
  final int maxLength;
  final bool uppercase;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    Navigator.pop(context, text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: widget.maxLength,
      textCapitalization: widget.uppercase
          ? TextCapitalization.characters
          : TextCapitalization.sentences,
      inputFormatters: [if (widget.uppercase) _UpperCaseFormatter()],
      decoration: InputDecoration(labelText: widget.label),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.action)),
    ],
  );
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

class _SquadList extends ConsumerWidget {
  const _SquadList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(mySquadsProvider)) {
      AsyncValue(:final value?) when value.isEmpty => const _Message(
        'Você ainda não está em nenhum squad.\n'
        'Crie um ou entre com o código de um amigo.',
      ),
      AsyncValue(:final value?) => ListView(
        padding: const EdgeInsets.only(bottom: 88), // espaço do botão "Novo"
        children: [for (final squad in value) _SquadTile(squad: squad)],
      ),
      AsyncValue(:final error?) => _Message(shortFailureMessage(error)),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _SquadTile extends StatelessWidget {
  const _SquadTile({required this.squad});

  final Squad squad;

  @override
  Widget build(BuildContext context) {
    final count = squad.members.length;
    return ListTile(
      leading: CircleAvatar(
        child: Text(squad.name.characters.first.toUpperCase()),
      ),
      title: Text(squad.name),
      subtitle: Text(count == 1 ? '1 membro' : '$count membros'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.pushNamed(
        Routes.squad,
        pathParameters: {'squadId': squad.id},
      ),
    );
  }
}

class _LinkRiotIdPrompt extends StatelessWidget {
  const _LinkRiotIdPrompt();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.link,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Vincule o seu Riot ID',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Ele é o seu jogador nos squads e no ranking semanal.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.pushNamed(Routes.linkRiotId),
            icon: const Icon(Icons.link),
            label: const Text('Vincular Riot ID'),
          ),
        ],
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
