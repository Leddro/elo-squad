import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/presentation/widgets/network_avatar.dart';
import '../../domain/entities/science.dart';
import 'role_icon.dart';

/// Uma Ciência: campeão, rota, título, itens em ordem e habilidades.
class ScienceCard extends StatelessWidget {
  const ScienceCard({super.key, required this.science});

  final ScienceBuild science;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NetworkAvatar(
                  url: science.championIconUrl,
                  size: 44,
                  fallbackIcon: Icons.shield,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(science.title, style: text.titleMedium),
                      Row(
                        spacing: 6,
                        children: [
                          RoleIcon(role: science.role, size: 16),
                          Flexible(
                            child: Text(
                              science.championName,
                              style: text.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TierBadge(tier: science.tier),
              ],
            ),
            if (science.source case final source?) ...[
              const SizedBox(height: 8),
              ActionChip(
                avatar: const Icon(Icons.play_circle_outline, size: 18),
                label: Text('Vídeo do $source'),
                onPressed: science.videoUrl == null
                    ? null
                    : () => launchUrl(
                        Uri.parse(science.videoUrl!),
                        mode: LaunchMode.externalApplication,
                      ),
              ),
            ],
            const SizedBox(height: 10),
            _Rates(science: science),
            const SizedBox(height: 12),
            Text('Itens', style: text.labelMedium),
            const SizedBox(height: 4),
            _ItemSequence(items: science.items, boots: science.boots),
            if (science.skills.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Habilidades · ${science.maxOrder}',
                style: text.labelMedium,
              ),
              const SizedBox(height: 4),
              SkillOrder(skills: science.skills),
            ],
          ],
        ),
      ),
    );
  }
}

/// Win rate da build, pick rate e ban rate do campeão (rota) no elo alto.
class _Rates extends StatelessWidget {
  const _Rates({required this.science});

  final ScienceBuild science;

  static String _percent(double value) =>
      '${(value * 100).toStringAsFixed(1).replaceAll('.', ',')}%';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget stat(String label, String value, {String? hint}) => Expanded(
      child: Tooltip(
        message: hint ?? label,
        child: Column(
          children: [
            Text(value, style: text.titleSmall),
            Text(label, style: text.labelSmall),
          ],
        ),
      ),
    );
    return Row(
      children: [
        stat(
          switch (science.winRateBasis) {
            WinRateBasis.champion => 'Win rate*',
            _ => 'Win rate',
          },
          science.winRateBasis == WinRateBasis.none
              ? '—'
              : _percent(science.winRate),
          hint: switch (science.winRateBasis) {
            WinRateBasis.build => '${science.games} partidas com esta build',
            WinRateBasis.champion =>
              '*Do campeão (${science.games} partidas): a build ainda tem '
                  'poucas',
            WinRateBasis.video => 'Taxa informada no vídeo',
            WinRateBasis.none => 'Sem partidas com esta build ainda',
          },
        ),
        stat('Pick rate', _percent(science.pickRate)),
        stat('Ban rate', _percent(science.banRate)),
      ],
    );
  }
}

class _ItemSequence extends StatelessWidget {
  const _ItemSequence({required this.items, required this.boots});

  final List<ScienceItem> items;
  final ScienceItem? boots;

  @override
  Widget build(BuildContext context) {
    final arrow = Icon(
      Icons.chevron_right,
      size: 18,
      color: Theme.of(context).colorScheme.outline,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      runSpacing: 4,
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0) arrow,
          _ItemIcon(item: item),
        ],
        if (boots case final boots?) ...[
          const SizedBox(width: 10),
          _ItemIcon(item: boots),
        ],
      ],
    );
  }
}

class _ItemIcon extends StatelessWidget {
  const _ItemIcon({required this.item});

  final ScienceItem item;

  static const _size = 36.0;

  @override
  Widget build(BuildContext context) {
    final empty = Container(
      width: _size,
      height: _size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.inventory_2_outlined, size: 18),
    );
    return Tooltip(
      message: item.name,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: item.iconUrl == null
            ? empty
            : Image.network(
                item.iconUrl!,
                width: _size,
                height: _size,
                semanticLabel: item.name,
                errorBuilder: (_, _, _) => empty,
              ),
      ),
    );
  }
}

/// Uma casinha por nível (1 a 18) com a habilidade upada; R em destaque.
class SkillOrder extends StatelessWidget {
  const SkillOrder({super.key, required this.skills});

  final String skills;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        for (final (i, key) in skills.split('').indexed)
          Tooltip(
            message: 'Nível ${i + 1}',
            child: Container(
              width: 18,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: key == 'R'
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                key,
                style: text.labelSmall?.copyWith(
                  fontWeight: key == 'R' ? FontWeight.bold : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
