import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/failure_messages.dart';
import '../../../../core/presentation/run_action.dart';
import '../../../../core/presentation/theme/brand_colors.dart';
import '../../../../core/presentation/widgets/network_avatar.dart';
import '../../../../core/router/app_router.dart';
import '../../../summoner/domain/entities/ranked.dart';
import '../../../summoner/presentation/formatters.dart';
import '../../domain/entities/weekly_ranking.dart';
import '../widgets/squad_icon.dart';
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
      appBar: AppBar(
        title: const Text('Squads'),
        actions: [
          if (hasRiotId)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => _showNewSquadSheet(context, ref),
                icon: const Icon(Icons.group_add),
                label: const Text('Novo'),
              ),
            ),
        ],
      ),
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

class _SquadList extends ConsumerStatefulWidget {
  const _SquadList();

  @override
  ConsumerState<_SquadList> createState() => _SquadListState();
}

/// Só um squad aberto por vez: tocar em outro fecha o anterior.
class _SquadListState extends ConsumerState<_SquadList> {
  String? _expanded;

  @override
  Widget build(BuildContext context) {
    return switch (ref.watch(mySquadsProvider)) {
      AsyncValue(:final value?) when value.isEmpty => const _Message(
        'Você ainda não está em nenhum squad.\n'
        'Crie um ou entre com o código de um amigo.',
      ),
      AsyncValue(:final value?) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          for (final squad in value)
            _SquadCard(
              key: ValueKey(squad.id),
              squad: squad,
              expanded: _expanded == squad.id,
              onTap: () => setState(
                () => _expanded = _expanded == squad.id ? null : squad.id,
              ),
            ),
        ],
      ),
      AsyncValue(:final error?) => _Message(shortFailureMessage(error)),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _SquadCard extends ConsumerWidget {
  const _SquadCard({
    super.key,
    required this.squad,
    required this.expanded,
    required this.onTap,
  });

  final Squad squad;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final count = squad.members.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  SquadBadge(squad: squad),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          squad.name,
                          style: text.titleMedium?.copyWith(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          count == 1 ? '1 membro' : '$count membros',
                          style: text.bodySmall?.copyWith(
                            color: const Color(0xFFA09B8C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.expand_more,
                      color: BrandColors.gold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? _SquadMembers(squad: squad)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Os membros em "cascata": do primeiro do ranking da semana para baixo,
/// cada um entrando um pouco depois do anterior.
class _SquadMembers extends ConsumerWidget {
  const _SquadMembers({required this.squad});

  final Squad squad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ranking = ref.watch(latestRankingProvider(squad.id)).value;
    final rows = _rows(ranking);
    return Column(
      children: [
        const Divider(height: 1),
        for (final (index, row) in rows.indexed)
          _Cascade(
            index: index,
            child: _MemberRow(position: index + 1, row: row),
          ),
        _Cascade(
          index: rows.length,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            // OverflowBar: lado a lado; se não couber, um embaixo do outro.
            child: OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _changeIcon(context, ref),
                  icon: const Icon(Icons.palette_outlined, size: 18),
                  label: const Text('Ícone'),
                ),
                TextButton.icon(
                  onPressed: () => context.pushNamed(
                    Routes.squad,
                    pathParameters: {'squadId': squad.id},
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Abrir squad'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Quem está na frente no ranking vem primeiro. Sem ranking ainda, a
  /// ordem de entrada no squad.
  List<_Row> _rows(WeeklyRanking? ranking) {
    final byUid = {for (final m in squad.members) m.uid: m};
    if (ranking == null) {
      return [for (final m in squad.members) _Row(m)];
    }
    final ranked = [
      for (final e in ranking.entries)
        if (byUid.containsKey(e.uid)) _Row(byUid[e.uid]!, e.current, e.lpDelta),
    ];
    final seen = {for (final r in ranked) r.member.uid};
    return [
      ...ranked,
      for (final m in squad.members)
        if (!seen.contains(m.uid)) _Row(m),
    ];
  }

  Future<void> _changeIcon(BuildContext context, WidgetRef ref) async {
    final icon = await pickSquadIcon(context, current: squad.icon);
    if (icon == null || !context.mounted) return;
    await runAction(
      context,
      () => ref.read(squadRepositoryProvider).setSquadIcon(squad.id, icon),
    );
  }
}

/// Uma linha da cascata: o membro e, se houver ranking, o elo e o PDL.
class _Row {
  const _Row(this.member, [this.current, this.lpDelta]);

  final SquadMember member;
  final RankedEntry? current;
  final int? lpDelta;
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.position, required this.row});

  final int position;
  final _Row row;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final _Row(:member, :current, lpDelta: delta) = row;
    return InkWell(
      onTap: () => context.pushNamed(
        Routes.profile,
        pathParameters: {
          'gameName': member.riotId.gameName,
          'tagLine': member.riotId.tagLine,
        },
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '$positionº',
                style: text.labelLarge?.copyWith(color: BrandColors.gold),
              ),
            ),
            NetworkAvatar(url: member.profileIconUrl, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.riotId.toString(),
                    style: text.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (current != null)
                    Text(
                      rankLabel(current),
                      style: text.bodySmall?.copyWith(
                        color: const Color(0xFFA09B8C),
                      ),
                    ),
                ],
              ),
            ),
            if (delta != null)
              Text(
                '${delta > 0 ? '+' : ''}$delta PDL',
                style: text.labelLarge?.copyWith(
                  color: delta > 0
                      ? BrandColors.cyan
                      : delta < 0
                      ? BrandColors.red
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Entra deslizando de cima e aparecendo, com atraso pela posição.
class _Cascade extends StatefulWidget {
  const _Cascade({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_Cascade> createState() => _CascadeState();
}

class _CascadeState extends State<_Cascade>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: 70 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, -0.4),
        end: Offset.zero,
      ).animate(_curve),
      child: widget.child,
    ),
  );
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
