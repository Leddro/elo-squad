import '../../../../core/error/failure.dart';
import '../../../../core/error/guard_failures.dart';
import '../../domain/entities/profile_result.dart';
import '../../domain/entities/riot_id.dart';
import '../../domain/entities/summoner_profile.dart';
import '../../domain/repositories/summoner_repository.dart';
import '../datasources/summoner_remote_data_source.dart';
import '../local/profile_local_data_source.dart';

/// Implementação do contrato definido no domain.
///
/// É a FRONTEIRA da camada data: nada de Dio, JSON, SQL ou TypeError passa
/// daqui. Quem está acima (caso de uso, providers, telas) só vê entidades ou
/// Failure.
///
/// Estratégia de cache: NETWORK-FIRST COM FALLBACK. Tenta sempre o proxy
/// primeiro (o elo muda, e a busca é uma só); o cache só entra quando a rede
/// falha. É o contrário das partidas (cache primeiro, rede em segundo plano),
/// em que mostrar o que já está salvo na hora vale mais.
final class SummonerRepositoryImpl implements SummonerRepository {
  const SummonerRepositoryImpl(this._remote, this._local);

  final SummonerRemoteDataSource _remote;
  final ProfileLocalDataSource _local;

  @override
  Future<ProfileResult> getProfile(RiotId riotId) async {
    try {
      final profile = await guardFailures(() async {
        final dto = await _remote.fetchProfile(riotId);
        // Converte ANTES de salvar: um perfil que nem vira entidade (ex.:
        // tier desconhecido) não pode ir para o cache.
        final profile = dto.toEntity();
        await _local.save(riotId, dto);
        return profile;
      });
      return ProfileResult(profile: profile);
    } on Failure catch (failure) {
      // A cópia só ajuda se o problema for TEMPORÁRIO.
      if (!_cacheHelpsWith(failure)) rethrow;

      final cached = await _readCacheOrNull(riotId);
      if (cached == null) rethrow; // nunca buscado aqui: o erro original
      return ProfileResult(profile: cached, staleBecause: failure);
    }
  }

  /// Switch exaustivo SEM curinga: uma Failure nova obriga a decidir aqui se
  /// a cópia salva serve para ela.
  static bool _cacheHelpsWith(Failure failure) => switch (failure) {
    NetworkFailure() ||
    RateLimitedFailure() ||
    UpstreamUnavailableFailure() => true,
    // "Jogador não existe" é uma resposta, não uma falha temporária: mostrar
    // o perfil antigo seria mentir. E um erro inesperado (bug) não deve ser
    // escondido atrás do cache.
    NotFoundFailure() || UnexpectedFailure() => false,
    // Sessão expirada e regras de squad não têm a ver com o perfil em cache.
    UnauthenticatedFailure() || SquadFailure() || AuthFailure() => false,
  };

  /// Uma cópia corrompida (ou que não vira mais entidade) não pode trocar o
  /// erro de verdade ("sem conexão") por um erro confuso de JSON: nesse caso,
  /// é como se não houvesse cópia.
  Future<SummonerProfile?> _readCacheOrNull(RiotId riotId) async {
    try {
      return (await _local.read(riotId))?.toEntity();
    } on Object {
      return null;
    }
  }
}
