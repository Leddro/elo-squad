import 'package:drift/native.dart';
import 'package:elo_squad/core/database/app_database.dart';
import 'package:elo_squad/features/summoner/data/local/profile_local_data_source.dart';
import 'package:elo_squad/features/summoner/data/models/summoner_profile_dto.dart';
import 'package:elo_squad/features/summoner/domain/entities/riot_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixtures.dart';

void main() {
  late AppDatabase db;
  late ProfileLocalDataSource local;
  const fulano = RiotId('Fulano', 'BR1');
  final dto = SummonerProfileDto.fromJson(loadFixture('summoner_profile.json'));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    local = ProfileLocalDataSource(db);
  });

  tearDown(() => db.close());

  test('nunca salvo: null', () async {
    expect(await local.read(fulano), isNull);
  });

  test('ida e volta pelo JSON: o DTO volta igual', () async {
    await local.save(fulano, dto);

    expect(await local.read(fulano), dto);
  });

  test('salvar de novo substitui a cópia (upsert)', () async {
    await local.save(fulano, dto);
    await local.save(fulano, dto.copyWith(level: 400));

    expect((await local.read(fulano))!.level, 400);
  });

  test('a chave ignora maiúsculas, como o RiotId', () async {
    await local.save(const RiotId('fulano', 'br1'), dto);

    expect(await local.read(fulano), dto);
  });
}
