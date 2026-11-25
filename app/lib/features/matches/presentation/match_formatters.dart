import '../domain/entities/match_summary.dart';

// Textos de exibição do histórico (decisão da presentation, não do domain).

String queueLabel(QueueType queue) => switch (queue) {
  QueueType.rankedSolo => 'Ranqueada Solo/Duo',
  QueueType.rankedFlex => 'Ranqueada Flex',
  QueueType.normal => 'Normal',
  QueueType.aram => 'ARAM',
  QueueType.arena => 'Arena',
  QueueType.other => 'Outro modo',
};

String resultLabel(MatchResult result) => switch (result) {
  MatchResult.win => 'Vitória',
  MatchResult.loss => 'Derrota',
  MatchResult.remake => 'Refeita',
};

/// Na Arena, a colocação diz mais do que "vitória/derrota": "5º lugar".
String matchTitle(MatchSummary match) => switch (match.placement) {
  final placement? => '$placementº lugar',
  null => resultLabel(match.result),
};

/// "8/2/11".
String kdaLine(MatchSummary match) =>
    '${match.kills}/${match.deaths}/${match.assists}';

/// 9.5 → "9,5" (vírgula decimal, padrão brasileiro).
String formatKda(double kda) => kda.toStringAsFixed(1).replaceAll('.', ',');

/// 1834 s → "30:34"; acima de 1 hora → "1:02:05".
String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60);
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return duration.inHours > 0
      ? '${duration.inHours}:${twoDigits(minutes)}:$seconds'
      : '$minutes:$seconds';
}
