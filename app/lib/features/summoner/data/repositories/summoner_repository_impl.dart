import '../../../../core/error/guard_failures.dart';
import '../../domain/entities/riot_id.dart';
import '../../domain/entities/summoner_profile.dart';
import '../../domain/repositories/summoner_repository.dart';
import '../datasources/summoner_remote_data_source.dart';

/// Implementação do contrato definido no domain.
///
/// É a FRONTEIRA da camada data: nada de Dio, JSON ou TypeError passa daqui.
/// Quem está acima (caso de uso, providers, telas) só vê entidades ou Failure.
/// A tradução dos erros fica em `guardFailures`, compartilhada com as outras
/// features.
final class SummonerRepositoryImpl implements SummonerRepository {
  const SummonerRepositoryImpl(this._remote);

  final SummonerRemoteDataSource _remote;

  @override
  Future<SummonerProfile> getProfile(RiotId riotId) => guardFailures(() async {
    final dto = await _remote.fetchProfile(riotId);
    return dto.toEntity();
  });
}
