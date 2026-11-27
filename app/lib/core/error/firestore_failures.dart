import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'failure.dart';

/// Erros do Firestore (e de JSON fora do formato) de um stream viram Failure.
///
/// [permissionDeniedAsNull]: depois de sair de um squad, a regra de
/// segurança passa a negar a leitura dele. Para a tela, isso é "não está
/// mais disponível" (null), e não um erro.
StreamTransformer<T, T> firestoreFailures<T>({
  bool permissionDeniedAsNull = false,
}) => StreamTransformer.fromHandlers(
  handleError: (error, stackTrace, sink) {
    if (error is FirebaseException) {
      if (permissionDeniedAsNull && error.code == 'permission-denied') {
        sink.add(null as T);
        return;
      }
      if (error.code == 'unavailable') {
        sink.addError(const NoConnectionFailure(), stackTrace);
        return;
      }
    }
    sink.addError(
      error is Failure ? error : UnexpectedFailure(error),
      stackTrace,
    );
  },
);
