import 'package:dio/dio.dart';

import 'dio_error_mapper.dart';

/// Quando a requisição não chega ao proxy, pergunta ao sistema se o aparelho
/// tem rede e anota a resposta; o mapper decide entre "sem conexão" e
/// "servidor não respondeu".
class ConnectivityInterceptor extends Interceptor {
  ConnectivityInterceptor(this._isOffline);

  final Future<bool> Function() _isOffline;

  static const _noReply = {
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
  };

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (_noReply.contains(err.type)) {
      try {
        err.requestOptions.extra[offlineKey] = await _isOffline();
      } on Object {
        // Sem resposta do sistema: fica como "servidor não respondeu".
      }
    }
    handler.next(err);
  }
}
