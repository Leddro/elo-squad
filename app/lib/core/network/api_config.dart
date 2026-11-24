/// Configuração de acesso ao proxy.
///
/// `String.fromEnvironment` lê um valor passado NA COMPILAÇÃO com --dart-define:
///   flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000
///
/// Sem o --dart-define, vale o padrão `10.0.2.2`: dentro do EMULADOR Android,
/// esse IP especial aponta para o `localhost` do seu PC (onde o proxy roda).
/// Num celular físico, use o IP do PC na rede Wi-Fi e suba o proxy com
/// `--host 0.0.0.0` para ele aceitar conexões de fora do PC.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
