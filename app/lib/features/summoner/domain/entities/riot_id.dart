/// Identificador público de um jogador na Riot, no formato `nome#tag`.
///
/// Entidade do domínio: Dart puro, sem Flutter, Dio ou JSON.
final class RiotId {
  /// Para dados já confiáveis (ex.: vindos do proxy).
  /// Para texto digitado pelo usuário, use [tryParse], que valida.
  const RiotId(this.gameName, this.tagLine);

  final String gameName;
  final String tagLine;

  // Regras da Riot para o Riot ID.
  static const _minNameLength = 3;
  static const _maxNameLength = 16;
  static const _minTagLength = 3;
  static const _maxTagLength = 5;

  /// Converte o texto digitado (`"Fulano#BR1"`) em [RiotId].
  /// Devolve `null` se o formato for inválido, sem fazer nenhuma requisição.
  static RiotId? tryParse(String input) {
    final parts = input.trim().split('#');
    if (parts.length != 2) return null; // sem "#" ou com mais de um

    final name = parts[0].trim();
    final tag = parts[1].trim();
    if (!_hasLength(name, _minNameLength, _maxNameLength)) return null;
    if (!_hasLength(tag, _minTagLength, _maxTagLength)) return null;

    return RiotId(name, tag);
  }

  // `runes` conta caracteres de verdade (code points). `.length` conta unidades
  // UTF-16, e alguns caracteres especiais ocupariam 2 e contariam em dobro.
  static bool _hasLength(String value, int min, int max) {
    final length = value.runes.length;
    return length >= min && length <= max;
  }

  // ---------- Igualdade por VALOR (e sem diferenciar maiúsculas) ----------
  // A Riot trata "fulano#br1" e "Fulano#BR1" como a mesma conta, então aqui
  // também. Isso importa para o `.family` do Riverpod, que usa o RiotId como
  // chave de cache: buscas iguais com caixa diferente reaproveitam o resultado.
  //
  // Regra de ouro: objetos `==` iguais DEVEM ter o mesmo `hashCode`.
  // Por isso os dois normalizam com toLowerCase() do mesmo jeito.

  @override
  bool operator ==(Object other) =>
      other is RiotId &&
      other.gameName.toLowerCase() == gameName.toLowerCase() &&
      other.tagLine.toLowerCase() == tagLine.toLowerCase();

  @override
  int get hashCode =>
      Object.hash(gameName.toLowerCase(), tagLine.toLowerCase());

  /// Chave para guardar no banco local: `fulano#br1`. Segue a MESMA regra
  /// do `==` (minúsculas), então buscar "Fulano#BR1" acha o que foi salvo
  /// como "fulano#br1".
  String get storageKey => '${gameName.toLowerCase()}#${tagLine.toLowerCase()}';

  /// Mantém a grafia original para exibição: `Fulano#BR1`.
  @override
  String toString() => '$gameName#$tagLine';
}
