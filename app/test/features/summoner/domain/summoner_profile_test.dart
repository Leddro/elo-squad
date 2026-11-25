import 'package:elo_squad/features/summoner/domain/entities/mastery.dart';
import 'package:elo_squad/features/summoner/domain/entities/riot_id.dart';
import 'package:elo_squad/features/summoner/domain/entities/summoner_profile.dart';
import 'package:flutter_test/flutter_test.dart';

// O que o freezed gera e estes testes conferem: igualdade por valor,
// hashCode consistente, copyWith e listas imutáveis.

const wukong = Mastery(
  championId: 62,
  championName: 'Wukong',
  championIconUrl: null,
  level: 12,
  points: 245000,
);

SummonerProfile profile({
  RiotId riotId = const RiotId('Fulano', 'BR1'),
  List<Mastery>? masteries = const [wukong],
}) => SummonerProfile(
  riotId: riotId,
  puuid: 'puuid-123',
  level: 347,
  profileIconUrl: null,
  ranked: null,
  // List.of: uma lista NOVA a cada chamada, para provar que a comparação é
  // pelo conteúdo e não pelo endereço na memória.
  topMasteries: masteries == null ? null : List.of(masteries),
  fetchedAt: DateTime.utc(2026, 11, 25),
);

void main() {
  test('dois perfis com o mesmo conteúdo são iguais (igualdade por valor)', () {
    expect(profile(), profile());
    expect(profile().hashCode, profile().hashCode);
  });

  test('listas são comparadas pelo conteúdo, não pela referência', () {
    final a = profile();
    final b = profile();

    expect(
      identical(a.topMasteries, b.topMasteries),
      isFalse,
    ); // listas diferentes...
    expect(a, b); // ...mas perfis iguais
  });

  test('o == do freezed usa o == de cada campo (RiotId ignora maiúsculas)', () {
    expect(
      profile(riotId: const RiotId('fulano', 'br1')),
      profile(riotId: const RiotId('Fulano', 'BR1')),
    );
  });

  test('copyWith cria uma cópia mudando só o que foi pedido', () {
    final original = profile();
    final upado = original.copyWith(level: 348);

    expect(upado.level, 348);
    expect(upado.puuid, original.puuid);
    expect(original.level, 347); // o original não muda (imutável)
  });

  test('copyWith consegue colocar null num campo anulável', () {
    final semMaestrias = profile().copyWith(topMasteries: null);

    expect(semMaestrias.topMasteries, isNull);
    expect(semMaestrias.isPartial, isTrue);
  });

  test('a lista do perfil não pode ser alterada por fora', () {
    expect(() => profile().topMasteries!.add(wukong), throwsUnsupportedError);
  });
}
