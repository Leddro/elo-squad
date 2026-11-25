import 'package:dio/dio.dart';

import '../../../../core/network/json.dart';
import '../../domain/entities/riot_id.dart';
import '../models/summoner_profile_dto.dart';

/// Fonte de dados REMOTA: só sabe fazer a requisição HTTP e ler o JSON.
///
/// Não trata erros (deixa o DioException subir) nem conhece entidades:
/// isso é papel do repositório. Na fase 2 vai surgir uma fonte LOCAL (cache
/// offline), e o repositório decidirá qual das duas usar.
final class SummonerRemoteDataSource {
  const SummonerRemoteDataSource(this._dio);

  final Dio _dio;

  Future<SummonerProfileDto> fetchProfile(RiotId riotId) async {
    // encodeComponent: "Nome Com Espaço" → "Nome%20Com%20Espa%C3%A7o".
    // Mesmo papel do quote() no proxy em Python.
    final name = Uri.encodeComponent(riotId.gameName);
    final tag = Uri.encodeComponent(riotId.tagLine);

    final response = await _dio.get<Json>('/summoner/$name/$tag');
    return SummonerProfileDto.fromJson(response.data!);
  }
}
