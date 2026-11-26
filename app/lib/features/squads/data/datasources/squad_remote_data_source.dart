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
}
