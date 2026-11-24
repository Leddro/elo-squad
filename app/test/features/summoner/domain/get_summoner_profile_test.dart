import 'package:elo_squad/core/error/failure.dart';
import 'package:elo_squad/features/summoner/domain/entities/riot_id.dart';
import 'package:elo_squad/features/summoner/domain/entities/summoner_profile.dart';
import 'package:elo_squad/features/summoner/domain/repositories/summoner_repository.dart';
import 'package:elo_squad/features/summoner/domain/usecases/get_summoner_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Mock: um "dublê" do repositório. Não tem lógica nenhuma: o teste programa
// o que ele responde (when) e depois confere como ele foi chamado (verify).
class MockSummonerRepository extends Mock implements SummonerRepository {}

void main() {
  late MockSummonerRepository repository;
  late GetSummonerProfile getSummonerProfile;

  const riotId = RiotId('Fulano', 'BR1');
  final profile = SummonerProfile(
    riotId: riotId,
    puuid: 'puuid-123',
    level: 347,
    profileIconUrl: null,
    ranked: null,
    topMasteries: const [],
    fetchedAt: DateTime.utc(2026, 11, 24, 14, 3),
  );

  // setUp roda antes de CADA teste: cada um começa com um mock limpo.
  setUp(() {
    repository = MockSummonerRepository();
    getSummonerProfile = GetSummonerProfile(repository);
  });

  test('devolve o perfil que o repositório entregou', () async {
    when(() => repository.getProfile(riotId)).thenAnswer((_) async => profile);

    final result = await getSummonerProfile(riotId); // `call()` implícito

    expect(result, same(profile));
    verify(() => repository.getProfile(riotId)).called(1);
  });

  test('propaga a Failure do repositório sem transformá-la', () async {
    when(() => repository.getProfile(riotId))
        .thenAnswer((_) async => throw const NotFoundFailure());

    await expectLater(
      getSummonerProfile(riotId),
      throwsA(isA<NotFoundFailure>()),
    );
  });
}
