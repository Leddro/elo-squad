import '../entities/riot_id.dart';
import '../entities/summoner_profile.dart';

/// CONTRATO do repositório: o domain diz O QUE precisa, não COMO buscar.
///
/// A implementação (com Dio, JSON, cache...) fica em `data/repositories/`.
/// Isso é a inversão de dependência: `data` depende do `domain`, e não o contrário.
///
/// `abstract interface class`: só pode ser implementada (`implements`), nunca
/// estendida, e não tem código próprio. É um contrato puro.
abstract interface class SummonerRepository {
  /// Busca o perfil de [riotId].
  ///
  /// Em caso de erro, lança SOMENTE subclasses de Failure (`core/error`).
  /// Exceções do Dio, de JSON etc. nunca escapam da camada data.
  Future<SummonerProfile> getProfile(RiotId riotId);
}
