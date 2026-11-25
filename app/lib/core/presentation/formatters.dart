// Formatadores usados por mais de uma feature (perfil, partidas...).
// Funções puras: recebem dados e devolvem texto, fáceis de testar.

/// 245000 → "245.000".
String formatThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 0.533 → "53%". Sem partidas → "—".
String formatWinRate(double? winRate) =>
    winRate == null ? '—' : '${(winRate * 100).round()}%';

/// Quanto tempo se passou desde [moment]: "agora mesmo", "há 3 min",
/// "há 2 h", "há 4 dias".
String formatTimeAgo(DateTime moment, {required DateTime now}) {
  final elapsed = now.difference(moment);
  if (elapsed.inMinutes < 1) return 'agora mesmo';
  if (elapsed.inHours < 1) return 'há ${elapsed.inMinutes} min';
  if (elapsed.inDays < 1) return 'há ${elapsed.inHours} h';
  return elapsed.inDays == 1 ? 'há 1 dia' : 'há ${elapsed.inDays} dias';
}
