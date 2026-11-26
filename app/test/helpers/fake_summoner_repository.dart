import 'package:elo_squad/features/summoner/domain/entities/profile_result.dart';
import 'package:elo_squad/features/summoner/domain/entities/riot_id.dart';
import 'package:elo_squad/features/summoner/domain/repositories/summoner_repository.dart';

import 'profiles.dart';

/// Devolve o mesmo perfil para qualquer Riot ID (a home mostra o do dono).
class FakeSummonerRepository implements SummonerRepository {
  @override
  Future<ProfileResult> getProfile(RiotId riotId) async =>
      ProfileResult(profile: makeProfile());
}
