import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../squads/data/squad_data_providers.dart' show firestoreProvider;
import '../../data/repositories/science_repository_impl.dart';
import '../../domain/entities/science.dart';
import '../../domain/repositories/science_repository.dart';

final scienceRepositoryProvider = Provider<ScienceRepository>(
  (ref) => ScienceRepositoryImpl(ref.watch(firestoreProvider)),
);

/// As Ciências publicadas, em tempo real.
final sciencesProvider = StreamProvider.autoDispose<SciencesBoard?>(
  (ref) => ref.watch(scienceRepositoryProvider).watchCurrent(),
  retry: (_, _) => null,
);

/// Filtro de rota da tela (null = todas).
final scienceRoleFilterProvider =
    NotifierProvider.autoDispose<ScienceRoleFilter, ScienceRole?>(
      ScienceRoleFilter.new,
    );

class ScienceRoleFilter extends Notifier<ScienceRole?> {
  @override
  ScienceRole? build() => null;

  void select(ScienceRole? role) => state = role;
}
