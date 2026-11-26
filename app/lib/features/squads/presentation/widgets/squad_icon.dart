import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/theme/brand_colors.dart';
import '../../domain/entities/squad.dart';

/// Os ícones que um squad pode ter. As chaves são as mesmas que o proxy
/// aceita (SQUAD_ICONS no backend).
const squadIcons = <String, IconData>{
  'shield': Icons.shield,
  'trophy': Icons.emoji_events,
  'fire': Icons.local_fire_department,
  'bolt': Icons.bolt,
  'star': Icons.star,
  'gem': Icons.diamond,
  'castle': Icons.castle,
  'rocket': Icons.rocket_launch,
  'paw': Icons.pets,
  'medal': Icons.military_tech,
  'target': Icons.gps_fixed,
  'sparkle': Icons.auto_awesome,
};

/// Brasão do squad: losango dourado com o ícone escolhido, ou a inicial do
/// nome se ainda não houver ícone.
class SquadBadge extends StatelessWidget {
  const SquadBadge({super.key, required this.squad, this.size = 44});

  final Squad squad;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = squadIcons[squad.icon];
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: const ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF13233D), BrandColors.void0],
          ),
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            side: BorderSide(color: BrandColors.gold, width: 1.5),
          ),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: BrandColors.gold, size: size * 0.55)
              : Text(
                  squad.name.characters.first.toUpperCase(),
                  style: TextStyle(
                    color: BrandColors.gold,
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Grade para escolher o ícone. Devolve a chave escolhida, ou null.
Future<String?> pickSquadIcon(BuildContext context, {String? current}) =>
    showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ícone do squad',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final MapEntry(:key, :value) in squadIcons.entries)
                    IconButton(
                      key: ValueKey('icon-$key'),
                      isSelected: key == current,
                      style: IconButton.styleFrom(
                        shape: const BeveledRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          side: BorderSide(color: BrandColors.goldDark),
                        ),
                      ),
                      color: BrandColors.gold,
                      onPressed: () => Navigator.pop(sheetContext, key),
                      icon: Icon(value),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
