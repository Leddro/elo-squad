import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../../domain/entities/riot_id.dart';
import '../../domain/entities/summoner_profile.dart';
import '../../domain/repositories/summoner_repository.dart';
import '../datasources/summoner_remote_data_source.dart';

/// Implementação do contrato definido no domain.
///
/// É a FRONTEIRA da camada data: nada de Dio, JSON ou TypeError passa daqui.
/// Quem está acima (caso de uso, providers, telas) só vê entidades ou Failure.
final class SummonerRepositoryImpl implements SummonerRepository {
  const SummonerRepositoryImpl(this._remote);

  final SummonerRemoteDataSource _remote;

  @override
  Future<SummonerProfile> getProfile(RiotId riotId) async {
    try {
      final dto = await _remote.fetchProfile(riotId);
      return dto.toEntity();
    } on DioException catch (e, stackTrace) {
      // Erro de rede ou HTTP → Failure específica (tratamento centralizado).
      Error.throwWithStackTrace(failureFromDioException(e), stackTrace);
    } on Failure {
      rethrow;
    } catch (e, stackTrace) {
      // JSON fora do formato esperado (TypeError, FormatException,
      // ArgumentError de um tier desconhecido...).
      //
      // throwWithStackTrace preserva o stack trace ORIGINAL: no log, você vê
      // a linha do fromJson que quebrou, e não esta linha do repositório.
      Error.throwWithStackTrace(UnexpectedFailure(e), stackTrace);
    }
  }
}
