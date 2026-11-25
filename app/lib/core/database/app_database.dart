import 'package:drift/drift.dart';

import '../../features/matches/data/local/match_tables.dart';
import '../../features/matches/domain/entities/match_summary.dart';
import '../../features/summoner/data/local/profile_tables.dart';
import '../../features/summoner/data/models/summoner_profile_dto.dart';

part 'app_database.g.dart';

/// O banco SQLite local do app (cache offline), definido com o drift.
///
/// Fica no core porque é UM arquivo de banco para o app inteiro: cada feature
/// declara as suas tabelas, e elas são registradas aqui. É o único ponto em
/// que o core conhece as features, como o `main.dart` (raiz de composição).
///
/// O [QueryExecutor] vem de fora (injeção de dependência): no app, um arquivo
/// no celular rodando num isolate separado; nos testes, um banco em memória.
@DriftDatabase(tables: [CachedMatches, MatchHistories, CachedProfiles])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Versão do ESQUEMA (a estrutura das tabelas). O SQLite guarda no próprio
  /// arquivo a versão com que ele foi criado; ao abrir, o drift compara as
  /// duas e chama a migração certa.
  ///
  /// Histórico:
  /// - v1: partidas (CachedMatches, MatchHistories).
  /// - v2: cache offline do perfil (CachedProfiles).
  @override
  int get schemaVersion => 2;

  /// MIGRAÇÃO: como levar um banco antigo até a versão atual SEM perder os
  /// dados de quem já tem o app instalado.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    // Instalação nova: cria tudo direto na versão atual.
    onCreate: (m) => m.createAll(),
    // Atualização do app: aplica só os passos que faltam, em ordem. Um
    // usuário que pulou versões (v1 → v3) passa por todos os `if`.
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(cachedProfiles);
    },
  );
}
