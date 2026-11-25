import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'auth_interceptor.dart';

/// Cria o Dio usado por todo o app: UMA configuração, em UM lugar.
///
/// Interceptors são "ganchos" que o Dio executa em toda requisição:
///   onRequest  → antes de enviar  (ex.: adicionar um token de login)
///   onResponse → ao receber       (ex.: medir tempo de resposta)
///   onError    → quando falha     (ex.: registrar o erro)
/// Eles são executados em fila, na ordem em que foram adicionados.
Dio createDio({required String baseUrl, Future<String?> Function()? idToken}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      // connectTimeout: tempo para ESTABELECER a conexão com o proxy.
      // receiveTimeout: tempo para a resposta CHEGAR depois de conectado.
      // O proxy faz até 4 chamadas à Riot (em paralelo), então 15s dá folga.
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
    ),
  );

  if (idToken != null) dio.interceptors.add(AuthInterceptor(idToken));

  // kDebugMode: true só em `flutter run` (debug). Em release, nada é logado.
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        responseHeader: false,
        responseBody: true,
        logPrint: (line) => debugPrint(line.toString()),
      ),
    );
  }

  return dio;
}
