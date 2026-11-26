import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/firestore_failures.dart';
import '../../domain/entities/science.dart';
import '../../domain/repositories/science_repository.dart';
import '../models/science_dtos.dart';

/// Lê sciences/current do Firestore (só leitura; quem escreve é a coleta).
final class ScienceRepositoryImpl implements ScienceRepository {
  const ScienceRepositoryImpl(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<SciencesBoard?> watchCurrent() => _db
      .collection('sciences')
      .doc('current')
      .snapshots()
      .map((snap) {
        final data = snap.data();
        return data == null ? null : SciencesBoardDto.fromJson(data).toEntity();
      })
      .transform(firestoreFailures());
}
