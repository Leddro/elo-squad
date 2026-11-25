import 'package:drift/drift.dart';

import '../../features/matches/data/local/match_tables.dart';
import '../../features/matches/domain/entities/match_summary.dart';

part 'app_database.g.dart';

/// O banco SQLite local do app (cache offline), definido com o drift.
///
/// Fica no core porque é UM arquivo de banco para o app inteiro: cada feature
/// declara as suas tabelas, e elas são registradas aqui. É o único ponto em
/// que o core conhece as features, como o `main.dart` (raiz de composição).
///
/// O [QueryExecutor] vem de fora (injeção de dependência): no app, um arquivo
/// no celular rodando num isolate separado; nos testes, um banco em memória.
@DriftDatabase(tables: [CachedMatches, MatchHistories])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Versão do esquema. Mudou uma tabela depois de publicado? Sobe este número
  /// e escreve a MIGRAÇÃO (`migration`), senão quem já tem o app instalado
  /// fica com as tabelas antigas.
  @override
  int get schemaVersion => 1;
}
