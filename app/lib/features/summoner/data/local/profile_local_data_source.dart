import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/riot_id.dart';
import '../models/summoner_profile_dto.dart';

/// Fonte de dados LOCAL do perfil: guarda e lê o último perfil de cada Riot ID.
final class ProfileLocalDataSource {
  const ProfileLocalDataSource(this._db);

  final AppDatabase _db;

  /// Salva (ou substitui) a cópia de [riotId].
  Future<void> save(RiotId riotId, SummonerProfileDto profile) =>
      _db.cachedProfiles.insertOnConflictUpdate(
        CachedProfilesCompanion.insert(
          riotIdKey: riotId.storageKey,
          profile: profile,
        ),
      );

  /// A cópia salva de [riotId], ou null se ele nunca foi buscado aqui.
  Future<SummonerProfileDto?> read(RiotId riotId) async {
    final query = _db.select(_db.cachedProfiles)
      ..where((p) => p.riotIdKey.equals(riotId.storageKey));
    return (await query.getSingleOrNull())?.profile;
  }
}
