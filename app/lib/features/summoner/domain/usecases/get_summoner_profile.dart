import '../entities/profile_result.dart';
import '../entities/riot_id.dart';
import '../repositories/summoner_repository.dart';

/// Caso de uso: "buscar o perfil de um jogador".
///
/// Hoje só repassa para o repositório. Ele existe para ser o lugar das regras
/// que envolvem MAIS de um repositório. Exemplo da fase 3: "buscar o perfil e
/// marcar se ele é do meu squad" combina SummonerRepository + FriendsRepository.
///
/// `call()`: torna a classe "chamável" como função:
///   final getProfile = GetSummonerProfile(repo);
///   await getProfile(riotId);   // em vez de getProfile.call(riotId)
final class GetSummonerProfile {
  const GetSummonerProfile(this._repository);

  final SummonerRepository _repository;

  Future<ProfileResult> call(RiotId riotId) => _repository.getProfile(riotId);
}
