import 'package:elo_squad/features/matches/domain/entities/match_summary.dart';

/// Partida de exemplo. Quanto MAIOR o [n], mais RECENTE a partida, então
/// uma página do proxy (da mais nova para a mais antiga) é `pageOf([6, 5, 4])`.
MatchSummary makeMatch(int n, {int kills = 5}) => MatchSummary(
  matchId: 'BR1_$n',
  queue: QueueType.rankedSolo,
  result: MatchResult.win,
  placement: null,
  championId: 62,
  championName: 'Wukong',
  championIconUrl: null,
  kills: kills,
  deaths: 2,
  assists: 7,
  cs: 180,
  items: const [
    Item(itemId: 3078, iconUrl: null),
    null,
    null,
    null,
    null,
    null,
  ],
  trinket: null,
  duration: const Duration(minutes: 30),
  playedAt: DateTime.utc(2026, 11, 1).add(Duration(hours: n)),
);

List<MatchSummary> pageOf(List<int> ns) => [for (final n in ns) makeMatch(n)];

/// Só os números das partidas, para comparar listas de forma legível.
List<String> idsOf(List<MatchSummary> matches) => [
  for (final m in matches) m.matchId,
];
