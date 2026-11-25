import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/failure_messages.dart';
import '../../../../core/presentation/run_action.dart';
import '../../../../core/presentation/widgets/network_avatar.dart';
import '../../../../core/router/app_router.dart';
import '../../data/squad_data_providers.dart';
import '../../domain/entities/squad.dart';
import '../providers/squad_providers.dart';
import '../widgets/ranking_section.dart';

/// Um squad: o código de convite e os membros.
class SquadDetailPage extends ConsumerWidget {
  const SquadDetailPage({super.key, required this.squadId});

  final String squadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squad = ref.watch(squadProvider(squadId));
    final uid = ref.watch(currentUidProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(squad.value?.name ?? 'Squad'),
        actions: [
          if (squad.value != null)
            PopupMenuButton<void>(
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: () => _leave(context, ref, squad.value!),
                  child: const Text('Sair do squad'),
                ),
              ],
            ),
        ],
      ),
      body: switch (squad) {
        AsyncValue(:final value?) => _SquadView(squad: value, uid: uid),
        // null: o squad foi apagado, ou o usuário saiu dele.
        AsyncValue(hasValue: true) => const _Message(
          'Este squad não está mais disponível.',
        ),
        AsyncValue(:final error?) => _Message(shortFailureMessage(error)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, Squad squad) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Sair de ${squad.name}?'),
        content: Text(
          squad.members.length == 1
              ? 'Você é o único membro: o squad será apagado.'
              : 'Para voltar, você vai precisar do código de convite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final left = await runAction(context, () async {
      await ref.read(squadRepositoryProvider).leaveSquad(squad.id);
      return true;
    });
    if (left == true && context.mounted) context.pop();
  }
}

class _SquadView extends StatelessWidget {
  const _SquadView({required this.squad, required this.uid});

  final Squad squad;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RankingSection(squadId: squad.id, uid: uid),
        const SizedBox(height: 24),
        _InviteCard(code: squad.inviteCode),
        const SizedBox(height: 24),
        Text('Membros (${squad.members.length})', style: text.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final member in squad.members)
                ListTile(
                  leading: NetworkAvatar(url: member.profileIconUrl, size: 40),
                  title: Text(member.riotId.toString()),
                  subtitle: Text(
                    [
                      ?member.displayName,
                      if (squad.isOwner(member.uid)) 'líder',
                      if (member.uid == uid) 'você',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed(
                    Routes.profile,
                    pathParameters: {
                      'gameName': member.riotId.gameName,
                      'tagLine': member.riotId.tagLine,
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Código de convite', style: text.labelLarge),
                  SelectableText(
                    code,
                    style: text.headlineSmall?.copyWith(letterSpacing: 4),
                  ),
                  const Text('Passe para os amigos entrarem no squad.'),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Copiar código',
              icon: const Icon(Icons.copy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código copiado.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
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
