import 'package:drift/native.dart';
import 'package:elo_squad/core/database/app_database.dart';
import 'package:elo_squad/features/summoner/data/local/profile_local_data_source.dart';
import 'package:elo_squad/features/summoner/data/models/summoner_profile_dto.dart';
import 'package:elo_squad/features/summoner/domain/entities/riot_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixtures.dart';

// TESTE DE MIGRAÇÃO: simula o celular de quem tinha a versão anterior do app
// (banco v1, só com as partidas) e abre com o código atual (v2).

void main() {
  test('v1 → v2: cria a tabela de perfis e mantém os dados antigos', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        // setup: roda no SQLite cru, ANTES do drift olhar a versão do banco.
        setup: (raw) {
          raw.execute('''
            CREATE TABLE match_histories (
              puuid TEXT NOT NULL PRIMARY KEY,
              reached_end INTEGER NOT NULL,
              refreshed_at INTEGER NOT NULL
            );
          ''');
          raw.execute(
            "INSERT INTO match_histories VALUES ('puuid-antigo', 1, 1764000000);",
          );
          // A versão do esquema fica gravada no próprio arquivo do banco.
          raw.execute('PRAGMA user_version = 1;');
        },
      ),
    );
    addTearDown(db.close);

    // O dado da v1 sobreviveu à atualização...
    final old = await db.select(db.matchHistories).getSingle();
    expect(old.puuid, 'puuid-antigo');
    expect(old.reachedEnd, isTrue);

    // ...e a tabela nova da v2 existe e funciona.
    final profiles = ProfileLocalDataSource(db);
    final dto = SummonerProfileDto.fromJson(
      loadFixture('summoner_profile.json'),
    );
    await profiles.save(const RiotId('Fulano', 'BR1'), dto);
    expect(await profiles.read(const RiotId('Fulano', 'BR1')), dto);

    // E o banco agora está marcado como v2.
    final version = await db
        .customSelect('PRAGMA user_version')
        .map((row) => row.read<int>('user_version'))
        .getSingle();
    expect(version, 2);
  });
}
