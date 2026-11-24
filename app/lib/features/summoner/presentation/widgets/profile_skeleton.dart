import 'package:material_ui/material_ui.dart';

/// Skeleton: blocos cinzas no formato do perfil, pulsando.
///
/// Comparado a um spinner, o usuário já vê ONDE cada coisa vai aparecer, e a
/// espera parece menor (velocidade percebida).
class ProfileSkeleton extends StatefulWidget {
  const ProfileSkeleton({super.key});

  @override
  State<ProfileSkeleton> createState() => _ProfileSkeletonState();
}

// SingleTickerProviderStateMixin: fornece o "relógio" (Ticker) que move a
// animação a cada frame e pausa sozinho quando a tela não está visível.
class _ProfileSkeletonState extends State<ProfileSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.4,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose(); // sem isso, a animação continuaria rodando após sair da tela
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget block({double? width, required double height, double radius = 8}) =>
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    return Semantics(
      label: 'Carregando perfil', // leitores de tela (e os testes) encontram por aqui
      child: FadeTransition(
        opacity: _pulse,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                block(width: 72, height: 72, radius: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      block(width: 180, height: 20),
                      const SizedBox(height: 8),
                      block(width: 80, height: 14),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(child: block(height: 96)),
                const SizedBox(width: 12),
                Expanded(child: block(height: 96)),
              ],
            ),
            const SizedBox(height: 32),
            for (var i = 0; i < 3; i++) ...[
              block(height: 56),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
