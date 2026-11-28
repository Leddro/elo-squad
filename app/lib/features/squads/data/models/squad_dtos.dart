import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/network/json.dart';
// Sem `show`: o código gerado também usa o $RiotIdDtoCopyWith.
import '../../../summoner/data/models/summoner_profile_dto.dart';
import '../../domain/entities/squad.dart';
import 'ranking_dtos.dart' show TimestampConverter;

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
    SquadPeriodDto? period,
    @Default([]) List<PodiumDto> podiums,
  }) = _SquadDocDto;

  factory SquadDocDto.fromJson(Json json) => _$SquadDocDtoFromJson(json);

  Squad toEntity(String id) => Squad(
    id: id,
    name: name,
    inviteCode: inviteCode,
    ownerUid: ownerUid,
    icon: icon,
    description: description,
    period: period?.toEntity(),
    podiums: [for (final p in podiums) p.toEntity()],
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

  const factory UserDocDto({
    RiotIdDto? riotId,
    String? puuid,
    @Default([]) List<TrophyDto> trophies,
  }) = _UserDocDto;

  factory UserDocDto.fromJson(Json json) => _$UserDocDtoFromJson(json);

  AccountLink toEntity() => AccountLink(
    riotId: riotId?.toEntity(),
    puuid: puuid,
    trophies: [for (final t in trophies) t.toEntity()]
      ..sort((a, b) => b.endsAt.compareTo(a.endsAt)),
  );
}

@freezed
abstract class SquadPeriodDto with _$SquadPeriodDto {
  const SquadPeriodDto._();

  const factory SquadPeriodDto({
    required String length,
    @TimestampConverter() required DateTime startsAt,
    @TimestampConverter() required DateTime endsAt,
    required bool repeat,
  }) = _SquadPeriodDto;

  factory SquadPeriodDto.fromJson(Json json) => _$SquadPeriodDtoFromJson(json);

  SquadPeriod toEntity() => SquadPeriod(
    length: PeriodLength.fromWire(length) ?? PeriodLength.custom,
    startsAt: startsAt,
    endsAt: endsAt,
    repeat: repeat,
  );
}

@freezed
abstract class PodiumDto with _$PodiumDto {
  const PodiumDto._();

  const factory PodiumDto({
    required String periodId,
    @TimestampConverter() required DateTime startsAt,
    @TimestampConverter() required DateTime endsAt,
    required List<String> places,
    required List<int> points,
  }) = _PodiumDto;

  factory PodiumDto.fromJson(Json json) => _$PodiumDtoFromJson(json);

  Podium toEntity() => Podium(
    periodId: periodId,
    startsAt: startsAt,
    endsAt: endsAt,
    places: places,
    points: points,
  );
}

@freezed
abstract class TrophyDto with _$TrophyDto {
  const TrophyDto._();

  const factory TrophyDto({
    required String squadId,
    required String squadName,
    required String periodId,
    @TimestampConverter() required DateTime endsAt,
    required int place,
    required int points,
  }) = _TrophyDto;

  factory TrophyDto.fromJson(Json json) => _$TrophyDtoFromJson(json);

  Trophy toEntity() => Trophy(
    squadId: squadId,
    squadName: squadName,
    periodId: periodId,
    endsAt: endsAt,
    place: place,
    points: points,
  );
}

/// Resposta do proxy ao criar/entrar: `{"id": ..., "inviteCode": ...}`.
@freezed
abstract class SquadRefDto with _$SquadRefDto {
  const factory SquadRefDto({required String id, required String inviteCode}) =
      _SquadRefDto;

  factory SquadRefDto.fromJson(Json json) => _$SquadRefDtoFromJson(json);
}
