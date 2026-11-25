import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/repositories/match_repository.dart';
import 'datasources/match_remote_data_source.dart';
import 'local/match_local_data_source.dart';
import 'repositories/match_repository_impl.dart';

// Injeção de dependência da camada data do histórico. Mesmo padrão do
// summoner: o provider do repositório expõe a INTERFACE do domain.

final matchRemoteDataSourceProvider = Provider<MatchRemoteDataSource>(
  (ref) => MatchRemoteDataSource(ref.watch(dioProvider)),
);

final matchLocalDataSourceProvider = Provider<MatchLocalDataSource>(
  (ref) => MatchLocalDataSource(ref.watch(appDatabaseProvider)),
);

final matchRepositoryProvider = Provider<MatchRepository>(
  (ref) => MatchRepositoryImpl(
    ref.watch(matchRemoteDataSourceProvider),
    ref.watch(matchLocalDataSourceProvider),
  ),
);
