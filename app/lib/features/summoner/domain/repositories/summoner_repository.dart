import '../entities/profile_result.dart';
import '../entities/riot_id.dart';

/// CONTRATO do repositório: o domain diz O QUE precisa, não COMO buscar.
///
/// A implementação (com Dio, JSON, cache...) fica em `data/repositories/`.
/// Isso é a inversão de dependência: `data` depende do `domain`, e não o contrário.
///
/// `abstract interface class`: só pode ser implementada (`implements`), nunca
/// estendida, e não tem código próprio. É um contrato puro.
abstract interface class SummonerRepository {
  /// Busca o perfil de [riotId] no proxy e guarda uma cópia no aparelho.
  ///
  /// Se a busca falhar por um motivo TEMPORÁRIO (sem internet, Riot fora,
  /// rate limit) e houver uma cópia salva, devolve a cópia, com
  /// [ProfileResult.staleBecause] preenchido.
  ///
  /// Sem cópia (ou com um erro que a cópia não resolve, como "jogador não
  /// existe"), lança SOMENTE subclasses de Failure (`core/error`).
  Future<ProfileResult> getProfile(RiotId riotId);
}
