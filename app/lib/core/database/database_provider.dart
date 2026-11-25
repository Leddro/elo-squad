import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// O banco do app inteiro: aberto uma vez, compartilhado por todas as features.
///
/// `driftDatabase` (do drift_flutter) cria o arquivo na pasta de dados do app
/// e roda as consultas num ISOLATE separado: a tela não trava enquanto o
/// SQLite trabalha. Nos testes, este provider é trocado por um banco em
/// memória (`overrideWithValue`).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'elo_squad'));
  ref.onDispose(db.close);
  return db;
});
