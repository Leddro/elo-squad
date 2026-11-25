import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../domain/repositories/squad_repository.dart';
import 'datasources/squad_firestore_data_source.dart';
import 'datasources/squad_remote_data_source.dart';
import 'repositories/squad_repository_impl.dart';

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final squadRepositoryProvider = Provider<SquadRepository>(
  (ref) => SquadRepositoryImpl(
    SquadFirestoreDataSource(ref.watch(firestoreProvider)),
    SquadRemoteDataSource(ref.watch(dioProvider)),
  ),
);
