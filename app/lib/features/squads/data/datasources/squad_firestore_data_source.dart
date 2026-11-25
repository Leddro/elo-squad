import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/squad_dtos.dart';

/// Leituras em tempo real do Firestore. As regras de segurança garantem que
/// só membros leem um squad e que cada um só lê o próprio documento.
final class SquadFirestoreDataSource {
  const SquadFirestoreDataSource(this._db);

  final FirebaseFirestore _db;

  Stream<UserDocDto?> watchUser(String uid) =>
      _db.collection('users').doc(uid).snapshots().map((snap) {
        final data = snap.data();
        return data == null ? null : UserDocDto.fromJson(data);
      });

  /// Consulta "squads em que eu estou": satisfaz a regra de leitura, porque
  /// só devolve documentos que têm o uid em memberUids.
  Stream<List<(String, SquadDocDto)>> watchSquadsOf(String uid) => _db
      .collection('squads')
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map(
        (query) => [
          for (final doc in query.docs)
            (doc.id, SquadDocDto.fromJson(doc.data())),
        ],
      );

  Stream<SquadDocDto?> watchSquad(String squadId) =>
      _db.collection('squads').doc(squadId).snapshots().map((snap) {
        final data = snap.data();
        return data == null ? null : SquadDocDto.fromJson(data);
      });
}
