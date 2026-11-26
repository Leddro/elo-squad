import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../summoner/domain/entities/riot_id.dart';

part 'squad.freezed.dart';

/// Um grupo de amigos que compete no ranking semanal.
@freezed
abstract class Squad with _$Squad {
  const Squad._();

  const factory Squad({
    required String id,
    required String name,
    required String inviteCode,
    required String ownerUid,

    /// Na ordem em que entraram (o primeiro é quem criou).
    required List<SquadMember> members,

    /// Chave do ícone escolhido (ver SquadIcon); null = inicial do nome.
    String? icon,

    /// Texto livre do líder; só aparece ao abrir o squad.
    String? description,
  }) = _Squad;

  bool isOwner(String uid) => ownerUid == uid;
}

@freezed
abstract class SquadMember with _$SquadMember {
  const factory SquadMember({
    required String uid,
    required String? displayName,
    required RiotId riotId,
    required String puuid,
    required String? profileIconUrl,
  }) = _SquadMember;
}

/// O que o app sabe da conta do usuário logado (documento users/{uid}).
@freezed
abstract class AccountLink with _$AccountLink {
  const AccountLink._();

  const factory AccountLink({required RiotId? riotId, required String? puuid}) =
      _AccountLink;

  /// Conta nova: ainda sem Riot ID.
  static const empty = AccountLink(riotId: null, puuid: null);

  bool get hasRiotId => riotId != null && puuid != null;
}
