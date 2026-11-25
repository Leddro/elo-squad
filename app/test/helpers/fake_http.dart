import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// FAKE (não mock): uma implementação simplificada, mas funcional, do
/// "motor de rede" do Dio. Em vez de abrir uma conexão, devolve a resposta
/// que o teste mandar. Todo o resto do Dio (status, JSON, exceções) roda de
/// verdade, então estes testes cobrem datasource + mapper + repositório juntos.
class FakeHttpAdapter implements HttpClientAdapter {
  // FutureOr: o teste pode devolver a resposta na hora ou só quando quiser
  // (um Completer), para simular uma requisição lenta.
  FutureOr<ResponseBody> Function(RequestOptions options) respond = (_) =>
      throw StateError('Configure `respond` no teste');
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(
  Object body, {
  int status = 200,
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...headers,
  },
);
