import 'package:elo_squad/features/summoner/domain/entities/mastery.dart';
import 'package:elo_squad/features/summoner/domain/entities/ranked.dart';
import 'package:elo_squad/features/summoner/domain/entities/riot_id.dart';
import 'package:elo_squad/features/summoner/domain/entities/summoner_profile.dart';
import 'package:elo_squad/features/summoner/domain/entities/tier.dart';

const fulano = RiotId('Fulano', 'BR1');

/// Perfil de exemplo para testes de tela. Os parâmetros permitem montar
/// variações (ex.: resposta parcial) sem repetir o perfil inteiro.
SummonerProfile makeProfile({
  Ranked? ranked = const Ranked(
    solo: RankedEntry(
      tier: Tier.gold,
      division: Division.ii,
      lp: 54,
      wins: 40,
      losses: 35,
    ),
  ),
  List<Mastery>? topMasteries = const [
    Mastery(
      championId: 62,
      championName: 'Wukong',
      championIconUrl: null,
      level: 12,
      points: 245000,
    ),
  ],
}) => SummonerProfile(
  riotId: fulano,
  puuid: 'puuid-123',
  level: 347,
  profileIconUrl: null,
  ranked: ranked,
  topMasteries: topMasteries,
  fetchedAt: DateTime.now().subtract(const Duration(minutes: 3)),
);
