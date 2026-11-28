import 'package:dio/dio.dart';

import '../../../../core/network/json.dart';
import '../../../summoner/data/models/summoner_profile_dto.dart' show RiotIdDto;
import '../models/squad_dtos.dart';

/// Escritas pelo proxy (que confere o token do Firebase e as regras).
final class SquadRemoteDataSource {
  const SquadRemoteDataSource(this._dio);

  final Dio _dio;

  Future<RiotIdDto> linkRiotId(String gameName, String tagLine) async {
    final response = await _dio.put<Json>(
      '/me/riot-id',
      data: {'gameName': gameName, 'tagLine': tagLine},
    );
    return RiotIdDto.fromJson(response.data!['riotId'] as Json);
  }

  Future<SquadRefDto> createSquad(String name) async {
    final response = await _dio.post<Json>('/squads', data: {'name': name});
    return SquadRefDto.fromJson(response.data!);
  }

  Future<SquadRefDto> joinSquad(String inviteCode) async {
    final response = await _dio.post<Json>(
      '/squads/join',
      data: {'inviteCode': inviteCode},
    );
    return SquadRefDto.fromJson(response.data!);
  }

  Future<void> leaveSquad(String squadId) =>
      _dio.post<void>('/squads/${Uri.encodeComponent(squadId)}/leave');

  Future<void> setSquadIcon(String squadId, String icon) => _dio.put<void>(
    '/squads/${Uri.encodeComponent(squadId)}/icon',
    data: {'icon': icon},
  );

  Future<void> updateSquadInfo(
    String squadId,
    String name,
    String description,
  ) => _dio.put<void>(
    '/squads/${Uri.encodeComponent(squadId)}/info',
    data: {'name': name, 'description': description},
  );

  Future<void> removeMember(String squadId, String memberUid) =>
      _dio.delete<void>(
        '/squads/${Uri.encodeComponent(squadId)}/members/'
        '${Uri.encodeComponent(memberUid)}',
      );

  Future<void> setPeriod(
    String squadId, {
    required String length,
    DateTime? startsAt,
    DateTime? endsAt,
    required bool repeat,
  }) => _dio.put<void>(
    '/squads/${Uri.encodeComponent(squadId)}/period',
    data: {
      'length': length,
      'startsAt': ?startsAt?.toUtc().toIso8601String(),
      'endsAt': ?endsAt?.toUtc().toIso8601String(),
      'repeat': repeat,
    },
  );
}
