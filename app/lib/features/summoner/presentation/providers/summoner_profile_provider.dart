import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/summoner_data_providers.dart';
import '../../domain/entities/riot_id.dart';
import '../../domain/entities/summoner_profile.dart';
import '../../domain/usecases/get_summoner_profile.dart';

/// O caso de uso, montado com o repositório.
/// (Fica aqui, e não no domain, porque o domain é Dart puro: não conhece Riverpod.)
final getSummonerProfileProvider = Provider<GetSummonerProfile>(
  (ref) => GetSummonerProfile(ref.watch(summonerRepositoryProvider)),
);

/// O perfil de UM Riot ID. A tela observa isto e recebe um AsyncValue.
///
/// - `.family`: um estado separado por RiotId (por isso o RiotId tem == e hashCode).
/// - `.autoDispose`: quando nenhuma tela observa mais (o usuário saiu do perfil),
///   o estado é descartado. Sem isso, cada busca ficaria na memória para sempre.
/// - `retry: null`: o Riverpod 3 refaz sozinho, até 10 vezes, um provider que
///   falha. Para nós isso é ruim: "jogador não existe" não muda tentando de
///   novo, e repetir um 429 só piora o rate limit. Quem decide tentar de novo
///   é o usuário, pelo botão da tela de erro.
final summonerProfileProvider = FutureProvider.autoDispose
    .family<SummonerProfile, RiotId>(
      (ref, riotId) => ref.watch(getSummonerProfileProvider)(riotId),
      retry: (retryCount, error) => null,
    );
