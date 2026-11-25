import 'package:dio/dio.dart';

/// Põe `Authorization: Bearer <token do Firebase>` em toda requisição ao
/// proxy. O proxy confere o token e só então gasta a cota da Riot.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._idToken);

  final Future<String?> Function() _idToken;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _idToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    } on Object {
      // Sem token (ex.: offline e expirado): segue sem ele; o proxy responde
      // 401 e o erro é tratado como qualquer outro.
    }
    handler.next(options);
  }
}
