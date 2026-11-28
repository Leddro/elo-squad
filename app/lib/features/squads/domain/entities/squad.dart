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

    /// Período de disputa; null = semana de segunda a segunda.
    SquadPeriod? period,

    /// Resultados dos períodos encerrados, do mais recente ao mais antigo.
    @Default([]) List<Podium> podiums,
  }) = _Squad;

  bool isOwner(String uid) => ownerUid == uid;

  /// Medalhas de [uid] neste squad: (ouro, prata, bronze).
  ({int gold, int silver, int bronze}) medalsOf(String uid) {
    var (gold, silver, bronze) = (0, 0, 0);
    for (final podium in podiums) {
      switch (podium.places.indexOf(uid)) {
        case 0:
          gold++;
        case 1:
          silver++;
        case 2:
          bronze++;
      }
    }
    return (gold: gold, silver: silver, bronze: bronze);
  }
}

/// Duração do período escolhida pelo líder.
enum PeriodLength {
  week('week', '1 semana'),
  twoWeeks('two_weeks', '2 semanas'),
  month('month', '1 mês'),
  custom('custom', 'Datas próprias');

  const PeriodLength(this.wire, this.label);

  /// Como o proxy grava ("two_weeks").
  final String wire;
  final String label;

  static PeriodLength? fromWire(String value) =>
      values.where((l) => l.wire == value).firstOrNull;
}

@freezed
abstract class SquadPeriod with _$SquadPeriod {
  const factory SquadPeriod({
    required PeriodLength length,
    required DateTime startsAt,
    required DateTime endsAt,

    /// Ao acabar, começa outro igual.
    required bool repeat,
  }) = _SquadPeriod;
}

/// Os 3 primeiros de um período encerrado (uids, do 1º ao 3º).
@freezed
abstract class Podium with _$Podium {
  const factory Podium({
    required String periodId,
    required DateTime startsAt,
    required DateTime endsAt,
    required List<String> places,
    required List<int> points,
  }) = _Podium;
}

/// Troféu no perfil: 1º (ouro), 2º (prata) ou 3º (bronze) num período.
@freezed
abstract class Trophy with _$Trophy {
  const factory Trophy({
    required String squadId,
    required String squadName,
    required String periodId,
    required DateTime endsAt,
    required int place,
    required int points,
  }) = _Trophy;
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

  const factory AccountLink({
    required RiotId? riotId,
    required String? puuid,

    /// Do mais recente ao mais antigo.
    @Default([]) List<Trophy> trophies,
  }) = _AccountLink;

  /// Conta nova: ainda sem Riot ID.
  static const empty = AccountLink(riotId: null, puuid: null);

  bool get hasRiotId => riotId != null && puuid != null;
}
