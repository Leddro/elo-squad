import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/failure_messages.dart';
import '../../../../core/presentation/run_action.dart';
import '../../../../core/presentation/theme/brand_colors.dart';
import '../../../../core/presentation/widgets/network_avatar.dart';
import '../../../../core/router/app_router.dart';
import '../../data/squad_data_providers.dart';
import '../../domain/entities/squad.dart';
import '../providers/squad_providers.dart';
import '../widgets/ranking_section.dart';
import '../widgets/squad_icon.dart';

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
          if (squad.value case final value?)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Configurações',
                icon: const Icon(Icons.settings),
                style: IconButton.styleFrom(
                  foregroundColor: BrandColors.gold,
                  shape: const BeveledRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    side: BorderSide(color: BrandColors.goldDark),
                  ),
                ),
                onPressed: () => _settings(context, ref, value, uid),
              ),
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

  Future<void> _settings(
    BuildContext context,
    WidgetRef ref,
    Squad squad,
    String? uid,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Tema'),
              subtitle: const Text('O ícone do squad'),
              onTap: () => Navigator.pop(sheetContext, 'theme'),
            ),
            if (uid != null && squad.isOwner(uid))
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Nome e descrição'),
                onTap: () => Navigator.pop(sheetContext, 'info'),
              ),
            if (uid != null && squad.isOwner(uid) && squad.members.length > 1)
              ListTile(
                leading: const Icon(Icons.person_remove_outlined),
                title: const Text('Remover invocadores'),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            ListTile(
              leading: const Icon(Icons.logout, color: BrandColors.red),
              title: const Text('Sair do squad'),
              onTap: () => Navigator.pop(sheetContext, 'leave'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'theme':
        final icon = await pickSquadIcon(context, current: squad.icon);
        if (icon == null || !context.mounted) return;
        await runAction(
          context,
          () => ref.read(squadRepositoryProvider).setSquadIcon(squad.id, icon),
        );
      case 'info':
        final info = await showDialog<(String, String)>(
          context: context,
          builder: (_) => _SquadInfoDialog(squad: squad),
        );
        if (info == null || !context.mounted) return;
        await runAction(
          context,
          () => ref
              .read(squadRepositoryProvider)
              .updateSquadInfo(squad.id, name: info.$1, description: info.$2),
        );
      case 'remove':
        await _remove(context, ref, squad, uid!);
      case 'leave':
        await _leave(context, ref, squad);
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Squad squad,
    String uid,
  ) async {
    final member = await showModalBottomSheet<SquadMember>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Quem sai do squad?'),
            ),
            for (final m in squad.members)
              if (m.uid != uid)
                ListTile(
                  leading: NetworkAvatar(url: m.profileIconUrl, size: 36),
                  title: Text(m.riotId.toString()),
                  trailing: const Icon(
                    Icons.person_remove_outlined,
                    color: BrandColors.red,
                  ),
                  onTap: () => Navigator.pop(sheetContext, m),
                ),
          ],
        ),
      ),
    );
    if (member == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remover ${member.riotId}?'),
        content: const Text('Para voltar, vai precisar do código de convite.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await runAction(
      context,
      () =>
          ref.read(squadRepositoryProvider).removeMember(squad.id, member.uid),
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
        if (squad.description case final description?) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(description, style: text.bodyMedium),
            ),
          ),
          const SizedBox(height: 24),
        ],
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

/// Nome e descrição do squad. Devolve (nome, descrição), ou null se cancelou.
class _SquadInfoDialog extends StatefulWidget {
  const _SquadInfoDialog({required this.squad});

  final Squad squad;

  @override
  State<_SquadInfoDialog> createState() => _SquadInfoDialogState();
}

class _SquadInfoDialogState extends State<_SquadInfoDialog> {
  late final _name = TextEditingController(text: widget.squad.name);
  late final _description = TextEditingController(
    text: widget.squad.description ?? '',
  );
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Informe o nome.');
      return;
    }
    Navigator.pop(context, (name, _description.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nome e descrição'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          maxLength: 30,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Nome do squad',
            errorText: _nameError,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _description,
          maxLength: 200,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Descrição',
            hintText: 'Aparece para quem abrir o squad.',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _save, child: const Text('Salvar')),
    ],
  );
}
