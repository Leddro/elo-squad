import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/failure_messages.dart';
import '../../../../core/presentation/formatters.dart';
import '../../../../core/presentation/widgets/network_avatar.dart';
import '../../../../core/router/app_router.dart';
import '../../../summoner/presentation/formatters.dart';
import '../../domain/entities/weekly_ranking.dart';
import '../providers/squad_providers.dart';

/// "Ranking da semana": PDL ganho na Solo/Duo desde segunda-feira.
class RankingSection extends ConsumerWidget {
  const RankingSection({super.key, required this.squadId, required this.uid});

  final String squadId;
  final String? uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final ranking = ref.watch(latestRankingProvider(squadId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ranking da semana', style: text.titleMedium),
        const SizedBox(height: 8),
        switch (ranking) {
          AsyncValue(:final value?) => _RankingCard(ranking: value, uid: uid),
          AsyncValue(hasValue: true) => const Card(
            child: ListTile(
              leading: Icon(Icons.hourglass_empty),
              title: Text('O ranking ainda não foi calculado.'),
              subtitle: Text(
                'Ele é atualizado a cada hora, com o PDL ganho na Solo/Duo '
                'desde segunda-feira.',
              ),
            ),
          ),
          AsyncValue(:final error?) => Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_off),
              title: Text(shortFailureMessage(error)),
            ),
          ),
          _ => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({required this.ranking, required this.uid});

  final WeeklyRanking ranking;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final start = ranking.weekStart.toLocal();
    final day =
        '${start.day.toString().padLeft(2, '0')}/'
        '${start.month.toString().padLeft(2, '0')}';
    final subtitle = ranking.isFinal
        ? 'Resultado final da semana de $day'
        : 'Semana de $day · atualizado '
              '${formatTimeAgo(ranking.updatedAt, now: DateTime.now())}';

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(subtitle, style: text.bodySmall),
          ),
          for (final (index, entry) in ranking.entries.indexed)
            _RankingRow(
              position: index + 1,
              entry: entry,
              isMe: entry.uid == uid,
            ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.position,
    required this.entry,
    required this.isMe,
  });

  final int position;
  final RankingEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = entry.current;
    final delta = entry.lpDelta;
    final games = entry.games == 1 ? '1 partida' : '${entry.games} partidas';

    return ListTile(
      selected: isMe,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              position == 1 && (delta ?? 0) > 0 ? '🏆' : '$positionº',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          NetworkAvatar(url: entry.profileIconUrl, size: 36),
        ],
      ),
      title: Text(entry.riotId.toString()),
      subtitle: Text(
        current == null ? 'Sem ranque' : '${rankLabel(current)} · $games',
      ),
      trailing: Text(
        delta == null ? '—' : '${delta > 0 ? '+' : ''}$delta PDL',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: switch (delta) {
            null || 0 => null,
            > 0 => Colors.blue.shade600,
            _ => scheme.error,
          },
        ),
      ),
      onTap: () => context.pushNamed(
        Routes.profile,
        pathParameters: {
          'gameName': entry.riotId.gameName,
          'tagLine': entry.riotId.tagLine,
        },
      ),
    );
  }
}
