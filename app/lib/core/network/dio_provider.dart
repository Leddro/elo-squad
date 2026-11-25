import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_providers.dart';
import 'api_config.dart';
import 'dio_client.dart';

/// O Dio do app inteiro: criado uma vez, compartilhado por todos os repositórios.
final dioProvider = Provider<Dio>((ref) {
  final dio = createDio(
    baseUrl: ApiConfig.baseUrl,
    // read (e não watch): o token é pedido a cada requisição; o Dio não
    // precisa ser recriado quando o usuário muda.
    idToken: () => ref.read(authRepositoryProvider).idToken(),
  );
  // onDispose: limpeza quando o provider é descartado (fecha as conexões abertas).
  ref.onDispose(dio.close);
  return dio;
});
