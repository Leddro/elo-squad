import 'package:connectivity_plus/connectivity_plus.dart';
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
    isOffline: () async => (await Connectivity().checkConnectivity()).every(
      (r) => r == ConnectivityResult.none,
    ),
  );
  // onDispose: limpeza quando o provider é descartado (fecha as conexões abertas).
  ref.onDispose(dio.close);
  return dio;
});

/// Acorda o proxy assim que o app abre (no Render gratuito ele dorme sem
/// uso), para a primeira busca de verdade não pagar a espera inteira.
/// Silencioso: se falhar, as telas mostram o erro quando precisarem.
final proxyWarmUpProvider = Provider<void Function()>(
  (ref) =>
      () => ref
          .read(dioProvider)
          .get<void>('/health')
          .then<void>((_) {}, onError: (Object _) {}),
);
