import '../entities/science.dart';

abstract interface class ScienceRepository {
  /// As Ciências publicadas, em tempo real. null = ainda não há nenhuma.
  /// Erros chegam como `Failure` (`core/error`).
  Stream<SciencesBoard?> watchCurrent();
}
