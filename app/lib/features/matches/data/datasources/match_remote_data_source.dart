import 'package:dio/dio.dart';

import '../../../../core/network/json.dart';
import '../models/match_page_dto.dart';

/// Quantas partidas por página. Cada partida custa uma chamada do proxy à
/// Riot (limite da dev key: 20 por segundo), então a página é pequena.
const matchPageSize = 10;

/// Fonte de dados REMOTA do histórico: só faz a requisição e lê o JSON.
final class MatchRemoteDataSource {
  const MatchRemoteDataSource(this._dio);

  final Dio _dio;

  Future<MatchPageDto> fetchPage(
    String puuid, {
    required int start,
    int count = matchPageSize,
  }) async {
    final response = await _dio.get<Json>(
      '/matches/${Uri.encodeComponent(puuid)}',
      // queryParameters: o Dio monta "?start=10&count=10" e faz o encoding.
      queryParameters: {'start': start, 'count': count},
    );
    return MatchPageDto.fromJson(response.data!);
  }
}
