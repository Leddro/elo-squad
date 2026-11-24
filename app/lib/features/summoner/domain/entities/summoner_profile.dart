import 'mastery.dart';
import 'ranked.dart';
import 'riot_id.dart';

/// Perfil de um jogador: tudo o que a tela de perfil mostra.
///
/// Formato pensado para o APP, não para a API. O campo `unavailable` do JSON
/// do proxy não existe aqui: no domínio, a nulidade de cada seção já diz tudo.
final class SummonerProfile {
  const SummonerProfile({
    required this.riotId,
    required this.puuid,
    required this.level,
    required this.profileIconUrl,
    required this.ranked,
    required this.topMasteries,
    required this.fetchedAt,
  });

  final RiotId riotId;

  /// Identificador permanente da conta (não muda se o jogador trocar de nome).
  final String puuid;
  final int level;
  final String? profileIconUrl;

  /// `null` = não foi possível carregar o ranqueado agora (falha temporária).
  /// Diferente de `Ranked(solo: null)`, que significa "sem ranque na solo".
  final Ranked? ranked;

  /// `null` = não foi possível carregar as maestrias agora.
  /// Lista vazia = o jogador não tem maestrias.
  final List<Mastery>? topMasteries;

  /// Quando o elo foi buscado na Riot, para exibir "atualizado há X min".
  final DateTime fetchedAt;

  bool get isPartial => ranked == null || topMasteries == null;
}
