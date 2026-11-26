import '../../../summoner/domain/entities/riot_id.dart';
import '../entities/squad.dart';
import '../entities/weekly_ranking.dart';

/// Squads: LEITURAS em tempo real do Firestore (Streams, que funcionam offline
/// com o cache do próprio Firestore) e ESCRITAS pelo proxy, que valida tudo.
///
/// Os métodos lançam SOMENTE `Failure` (`core/error`), e os Streams só emitem
/// erros do tipo `Failure`.
abstract interface class SquadRepository {
  /// A conta do usuário [uid] (Riot ID vinculado ou não).
  Stream<AccountLink> watchAccount(String uid);

  /// Os squads de que [uid] faz parte, em ordem alfabética.
  Stream<List<Squad>> watchMySquads(String uid);

  /// Um squad. Emite null se ele não existe mais ou se o usuário saiu dele.
  Stream<Squad?> watchSquad(String squadId);

  /// O ranking mais recente do squad (a semana atual, ou o resultado final da
  /// anterior até a primeira atualização da semana nova). null = ainda não há.
  Stream<WeeklyRanking?> watchLatestRanking(String squadId);

  /// Valida o Riot ID na Riot e vincula à conta. Devolve a grafia oficial.
  Future<RiotId> linkRiotId(RiotId riotId);

  /// Cria um squad e devolve o id dele.
  Future<String> createSquad(String name);

  /// Entra num squad pelo código de convite e devolve o id dele.
  Future<String> joinSquad(String inviteCode);

  Future<void> leaveSquad(String squadId);

  /// Troca o ícone do squad (qualquer membro pode).
  Future<void> setSquadIcon(String squadId, String icon);

  /// Tira um membro do squad (só o líder pode).
  Future<void> removeMember(String squadId, String memberUid);
}
