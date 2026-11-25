import 'package:freezed_annotation/freezed_annotation.dart';

import 'mastery.dart';
import 'ranked.dart';
import 'riot_id.dart';

part 'summoner_profile.freezed.dart';

/// Perfil de um jogador: tudo o que a tela de perfil mostra.
///
/// Formato pensado para o APP, não para a API. O campo `unavailable` do JSON
/// do proxy não existe aqui: no domínio, a nulidade de cada seção já diz tudo.
@freezed
abstract class SummonerProfile with _$SummonerProfile {
  const SummonerProfile._(); // para o getter isPartial

  const factory SummonerProfile({
    required RiotId riotId,

    /// Identificador permanente da conta (não muda se o jogador trocar de nome).
    required String puuid,
    required int level,
    required String? profileIconUrl,

    /// `null` = não foi possível carregar o ranqueado agora (falha temporária).
    /// Diferente de `Ranked(solo: null)`, que significa "sem ranque na solo".
    required Ranked? ranked,

    /// `null` = não foi possível carregar as maestrias agora.
    /// Lista vazia = o jogador não tem maestrias.
    required List<Mastery>? topMasteries,

    /// Quando o elo foi buscado na Riot, para exibir "atualizado há X min".
    required DateTime fetchedAt,
  }) = _SummonerProfile;

  bool get isPartial => ranked == null || topMasteries == null;
}
