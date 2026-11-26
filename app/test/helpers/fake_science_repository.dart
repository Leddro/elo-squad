import 'dart:async';

import 'package:elo_squad/features/sciences/domain/entities/science.dart';
import 'package:elo_squad/features/sciences/domain/repositories/science_repository.dart';

/// FAKE das Ciências: o teste define o que está publicado (ou um erro).
class FakeScienceRepository implements ScienceRepository {
  FakeScienceRepository({this.board, this.error});

  SciencesBoard? board;
  Object? error;

  @override
  Stream<SciencesBoard?> watchCurrent() async* {
    if (error case final error?) throw error;
    yield board;
  }
}
