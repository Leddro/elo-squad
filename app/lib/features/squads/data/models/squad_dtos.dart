import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/network/json.dart';
// Sem `show`: o código gerado também usa o $RiotIdDtoCopyWith.
import '../../../summoner/data/models/summoner_profile_dto.dart';
import '../../domain/entities/squad.dart';

part 'squad_dtos.freezed.dart';
part 'squad_dtos.g.dart';

// Documentos do Firestore, no formato que o proxy grava (camelCase).
// Campos que o app não usa (createdAt, fcmTokens...) são ignorados.

@freezed
abstract class SquadDocDto with _$SquadDocDto {
  const SquadDocDto._();

  const factory SquadDocDto({
    required String name,
    required String inviteCode,
    required String ownerUid,
    required List<String> memberUids,
    required Map<String, SquadMemberDto> members,
    String? icon,
    String? description,
  }) = _SquadDocDto;

  factory SquadDocDto.fromJson(Json json) => _$SquadDocDtoFromJson(json);

  Squad toEntity(String id) => Squad(
    id: id,
    name: name,
    inviteCode: inviteCode,
    ownerUid: ownerUid,
    icon: icon,
    description: description,
    // memberUids guarda a ORDEM de entrada; o mapa, os dados de cada um.
    members: [
      for (final uid in memberUids)
        if (members[uid] case final member?) member.toEntity(),
    ],
  );
}

@freezed
abstract class SquadMemberDto with _$SquadMemberDto {
  const SquadMemberDto._();

  const factory SquadMemberDto({
    required String uid,
    String? displayName,
    required RiotIdDto riotId,
    required String puuid,
    String? profileIconUrl,
  }) = _SquadMemberDto;

  factory SquadMemberDto.fromJson(Json json) => _$SquadMemberDtoFromJson(json);

  SquadMember toEntity() => SquadMember(
    uid: uid,
    displayName: displayName,
    riotId: riotId.toEntity(),
    puuid: puuid,
    profileIconUrl: profileIconUrl,
  );
}

@freezed
abstract class UserDocDto with _$UserDocDto {
  const UserDocDto._();

  const factory UserDocDto({RiotIdDto? riotId, String? puuid}) = _UserDocDto;

  factory UserDocDto.fromJson(Json json) => _$UserDocDtoFromJson(json);

  AccountLink toEntity() =>
      AccountLink(riotId: riotId?.toEntity(), puuid: puuid);
}

/// Resposta do proxy ao criar/entrar: `{"id": ..., "inviteCode": ...}`.
@freezed
abstract class SquadRefDto with _$SquadRefDto {
  const factory SquadRefDto({required String id, required String inviteCode}) =
      _SquadRefDto;

  factory SquadRefDto.fromJson(Json json) => _$SquadRefDtoFromJson(json);
}
