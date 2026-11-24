import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../domain/repositories/summoner_repository.dart';
import 'datasources/summoner_remote_data_source.dart';
import 'repositories/summoner_repository_impl.dart';

// Injeção de dependência da camada data, feita com providers.
//
// Repare no TIPO de summonerRepositoryProvider: é a INTERFACE do domain
// (SummonerRepository), não a implementação. Quem usa este provider não sabe
// que existe Dio por trás. E nos testes basta um override:
//   summonerRepositoryProvider.overrideWithValue(MockSummonerRepository())

final summonerRemoteDataSourceProvider = Provider<SummonerRemoteDataSource>(
  (ref) => SummonerRemoteDataSource(ref.watch(dioProvider)),
);

final summonerRepositoryProvider = Provider<SummonerRepository>(
  (ref) => SummonerRepositoryImpl(ref.watch(summonerRemoteDataSourceProvider)),
);
