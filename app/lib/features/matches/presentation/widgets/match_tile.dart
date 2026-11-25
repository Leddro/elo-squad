import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/formatters.dart';
import '../../../../core/presentation/widgets/network_avatar.dart';
import '../../domain/entities/match_summary.dart';
import '../match_formatters.dart';

/// Uma partida do histórico. Widget "burro": recebe a entidade e só exibe.
class MatchTile extends StatelessWidget {
  const MatchTile({super.key, required this.match});

  final MatchSummary match;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = resultColor(match.result, Theme.of(context).colorScheme);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        // A faixa colorida à esquerda: azul vitória, vermelho derrota.
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NetworkAvatar(
                url: match.championIconUrl,
                size: 44,
                fallbackIcon: Icons.shield,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: matchTitle(match),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(text: ' · ${queueLabel(match.queue)}'),
                        ],
                      ),
                      style: text.bodyMedium,
                    ),
                    Text(
                      '${kdaLine(match)} · KDA ${formatKda(match.kda)} · '
                      '${match.cs} CS',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    _ItemsRow(match: match),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatTimeAgo(match.playedAt, now: DateTime.now()),
                    style: text.bodySmall,
                  ),
                  Text(formatDuration(match.duration), style: text.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cor do resultado. Pública para os testes e para reaproveitar no ranking.
Color resultColor(MatchResult result, ColorScheme scheme) => switch (result) {
  MatchResult.win => Colors.blue.shade600,
  MatchResult.loss => scheme.error,
  MatchResult.remake => scheme.outline,
};

/// Os 6 espaços do inventário + o trinket, na ordem do jogo.
class _ItemsRow extends StatelessWidget {
  const _ItemsRow({required this.match});

  final MatchSummary match;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 3,
    runSpacing: 3,
    children: [
      for (final item in match.items) _ItemIcon(item: item),
      const SizedBox(width: 4),
      _ItemIcon(item: match.trinket, round: true),
    ],
  );
}

class _ItemIcon extends StatelessWidget {
  const _ItemIcon({required this.item, this.round = false});

  final Item? item;
  final bool round;

  static const _size = 22.0;

  @override
  Widget build(BuildContext context) {
    final empty = Container(
      width: _size,
      height: _size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
    final url = item?.iconUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(round ? _size / 2 : 4),
      child: url == null
          ? empty
          : Image.network(
              url,
              width: _size,
              height: _size,
              errorBuilder: (_, _, _) => empty,
            ),
    );
  }
}
