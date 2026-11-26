import 'package:material_ui/material_ui.dart';

/// Paleta da marca: hextech do LoL (azul-marinho e dourado) com vermelho
/// nos destaques.
abstract final class BrandColors {
  /// Fundo mais escuro (quase preto azulado).
  static const void0 = Color(0xFF010A13);

  /// Fundo de painéis.
  static const navy = Color(0xFF0A1428);
  static const navyLight = Color(0xFF1E2328);

  /// Dourado hextech: molduras, bordas, destaques.
  static const gold = Color(0xFFC8AA6E);
  static const goldDark = Color(0xFF785A28);
  static const goldLight = Color(0xFFF0E6D2);

  /// Vermelho dos destaques ("SQUAD", acentos).
  static const red = Color(0xFFE8303F);
  static const redDark = Color(0xFF8C1A22);

  /// Ciano hextech (detalhes pequenos).
  static const cyan = Color(0xFF0AC8B9);
}
