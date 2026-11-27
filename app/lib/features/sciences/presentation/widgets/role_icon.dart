import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/theme/brand_colors.dart';
import '../../domain/entities/science.dart';

/// Ícone da rota como no cliente do jogo. O nome da rota fica no Tooltip e na
/// leitura de tela; sem internet, mostra as iniciais.
class RoleIcon extends StatelessWidget {
  const RoleIcon({super.key, required this.role, this.size = 20, this.color});

  final ScienceRole role;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? BrandColors.goldLight;
    return Tooltip(
      message: role.label,
      child: Semantics(
        label: role.label,
        image: true,
        child: Image.network(
          role.iconUrl,
          width: size,
          height: size,
          color: tint,
          colorBlendMode: BlendMode.srcIn,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Text(
                role.label.substring(0, 1),
                style: TextStyle(color: tint, fontSize: size * 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selo do tier (S, A, B, C, D) com a cor de cada um.
class TierBadge extends StatelessWidget {
  const TierBadge({super.key, required this.tier, this.size = 28});

  final ScienceTier tier;
  final double size;

  static Color colorOf(ScienceTier tier) => switch (tier) {
    ScienceTier.s => BrandColors.red,
    ScienceTier.a => BrandColors.gold,
    ScienceTier.b => BrandColors.cyan,
    ScienceTier.c => BrandColors.goldDark,
    ScienceTier.d => const Color(0xFF5B5A56),
  };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(tier);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tier.label,
        semanticsLabel: 'Tier ${tier.label}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.55,
        ),
      ),
    );
  }
}
