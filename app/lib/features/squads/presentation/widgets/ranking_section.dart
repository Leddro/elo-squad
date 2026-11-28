import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/failure_messages.dart';
import '../../../../core/presentation/formatters.dart';
import '../../../../core/presentation/widgets/network_avatar.dart';
import '../../../../core/router/app_router.dart';
import '../../../summoner/presentation/formatters.dart';
import '../../domain/entities/squad.dart';
import '../../domain/entities/squad_ranking.dart';
import '../providers/squad_providers.dart';

/// "dd/mm".
String dayMonth(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}';
}

/// O período vai até a meia-noite: o último dia é o anterior ao fim.
String periodRange(DateTime start, DateTime end) =>
    '${dayMonth(start)} a ${dayMonth(end.subtract(const Duration(minutes: 1)))}';

/// "🥇2 🥈1": as medalhas de um membro no squad (vazio se não tiver).
String medalsLabel(Squad squad, String uid) {
  final (:gold, :silver, :bronze) = squad.medalsOf(uid);
  return [
    if (gold > 0) '🥇$gold',
    if (silver > 0) '🥈$silver',
    if (bronze > 0) '🥉$bronze',
  ].join(' ');
}

String pointsLabel(int points) => '${points > 0 ? '+' : ''}$points pts';

/// Ranking do período: PDL ganho na Solo/Duo + bônus das Ciências.
class RankingSection extends ConsumerWidget {
  const RankingSection({super.key, required this.squad, required this.uid});

  final Squad squad;
  final String? uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final ranking = ref.watch(latestRankingProvider(squad.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ranking do período', style: text.titleMedium),
        const SizedBox(height: 8),
        switch (ranking) {
          AsyncValue(:final value?) => _RankingCard(
            ranking: value,
            squad: squad,
            uid: uid,
          ),
          AsyncValue(hasValue: true) => const Card(
            child: ListTile(
              leading: Icon(Icons.hourglass_empty),
              title: Text('O ranking ainda não foi calculado.'),
              subtitle: Text(
                'Ele é atualizado a cada hora: PDL ganho na Solo/Duo no '
                'período, mais o bônus das vitórias com Ciências.',
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
  const _RankingCard({
    required this.ranking,
    required this.squad,
    required this.uid,
  });

  final SquadRanking ranking;
  final Squad squad;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final range = periodRange(ranking.startsAt, ranking.endsAt);
    final subtitle = ranking.isFinal
        ? 'Resultado final de $range'
        : '$range · ${_remaining(ranking.endsAt)} · atualizado '
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
              medals: medalsLabel(squad, entry.uid),
              isMe: entry.uid == uid,
            ),
        ],
      ),
    );
  }

  static String _remaining(DateTime end) {
    final left = end.difference(DateTime.now());
    if (left.inDays >= 1) {
      return left.inDays == 1
          ? 'acaba em 1 dia'
          : 'acaba em ${left.inDays} dias';
    }
    if (left.inHours >= 1) return 'acaba em ${left.inHours} h';
    return 'acabando';
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.position,
    required this.entry,
    required this.medals,
    required this.isMe,
  });

  final int position;
  final RankingEntry entry;
  final String medals;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = entry.current;
    final points = entry.points;
    final games = entry.games == 1 ? '1 partida' : '${entry.games} partidas';

    return ListTile(
      selected: isMe,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              position == 1 && (points ?? 0) > 0 ? '🏆' : '$positionº',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          NetworkAvatar(url: entry.profileIconUrl, size: 36),
        ],
      ),
      title: Text(
        [entry.riotId.toString(), if (medals.isNotEmpty) medals].join('  '),
      ),
      subtitle: Text(
        current == null ? 'Sem ranque' : '${rankLabel(current)} · $games',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            points == null ? '—' : pointsLabel(points),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: switch (points) {
                null || 0 => null,
                > 0 => Colors.blue.shade600,
                _ => scheme.error,
              },
            ),
          ),
          if (entry.bonus > 0)
            Text(
              '🧪 +${entry.bonus}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
      onTap: () => _details(context),
    );
  }

  Future<void> _details(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      final text = Theme.of(sheetContext).textTheme;
      final delta = entry.lpDelta;
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              leading: NetworkAvatar(url: entry.profileIconUrl, size: 40),
              title: Text(entry.riotId.toString(), style: text.titleMedium),
              subtitle: Text(
                entry.points == null
                    ? 'Sem ranque'
                    : '${pointsLabel(entry.points!)} no período',
              ),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.trending_up),
              title: const Text('PDL na Solo/Duo'),
              trailing: Text(delta == null ? '—' : pointsLabel(delta)),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.science_outlined),
              title: const Text('Vitórias com Ciências'),
              trailing: Text(pointsLabel(entry.bonus)),
            ),
            for (final win in entry.scienceWins)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 72, right: 16),
                title: Text(win.title),
                subtitle: Text('Tier ${win.tier} · ${dayMonth(win.playedAt)}'),
                trailing: Text('+${win.bonus}'),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  context.pushNamed(
                    Routes.profile,
                    pathParameters: {
                      'gameName': entry.riotId.gameName,
                      'tagLine': entry.riotId.tagLine,
                    },
                  );
                },
                icon: const Icon(Icons.person_outline),
                label: const Text('Ver perfil'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Os pódios dos períodos encerrados, do mais recente ao mais antigo.
class PodiumHistory extends StatelessWidget {
  const PodiumHistory({super.key, required this.squad});

  final Squad squad;

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final names = {for (final m in squad.members) m.uid: m.riotId.gameName};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pódios', style: text.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final podium in squad.podiums.take(10))
                ListTile(
                  dense: true,
                  title: Text(periodRange(podium.startsAt, podium.endsAt)),
                  subtitle: Text(
                    [
                      for (final (i, uid) in podium.places.indexed)
                        '${_medals[i]} ${names[uid] ?? 'ex-membro'} '
                            '(${podium.points[i]})',
                    ].join('   '),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
