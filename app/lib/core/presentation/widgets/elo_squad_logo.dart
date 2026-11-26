import 'package:material_ui/material_ui.dart';

import '../theme/brand_colors.dart';

/// A logo do app: o squad (três silhuetas) numa moldura hextech, o nome
/// "ELO SQUAD" e o livro das Ciências. Desenhada em código (vetor), fica
/// nítida em qualquer tamanho. [width] define o tamanho de tudo.
class EloSquadLogo extends StatelessWidget {
  const EloSquadLogo({super.key, this.width = 240, this.showBook = true});

  final double width;
  final bool showBook;

  @override
  Widget build(BuildContext context) {
    final u = width / 240; // unidade: tudo foi desenhado numa caixa de 240
    return Semantics(
      label: 'Elo Squad',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: Size(width, 140 * u),
                painter: _EmblemPainter(),
              ),
              _Wordmark(unit: u),
              if (showBook) ...[
                SizedBox(height: 6 * u),
                CustomPaint(size: Size(width, 34 * u), painter: _BookPainter()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "ELO" dourado e "SQUAD" vermelho, inclinados, com contorno escuro.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.unit});

  final double unit;

  Widget _word(String text, double size, Gradient fill) {
    final style = TextStyle(
      fontFamily: 'RussoOne',
      fontSize: size,
      height: 1,
      letterSpacing: size * 0.04,
      decoration: TextDecoration.none,
    );
    return Stack(
      children: [
        // Contorno: o mesmo texto, só com traço, por baixo.
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.09
              ..strokeJoin = StrokeJoin.round
              ..color = BrandColors.void0,
          ),
        ),
        ShaderMask(
          shaderCallback: fill.createShader,
          blendMode: BlendMode.srcIn,
          child: Text(text, style: style.copyWith(color: Colors.white)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Transform(
    alignment: Alignment.center,
    transform: Matrix4.skewX(-0.18), // itálico "de velocidade"
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _word(
          'ELO',
          64 * unit,
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [BrandColors.goldLight, BrandColors.gold],
          ),
        ),
        SizedBox(height: 2 * unit),
        _word(
          'SQUAD',
          44 * unit,
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF5A64), BrandColors.red],
          ),
        ),
      ],
    ),
  );
}

/// Moldura angular dourada com cortes vermelhos e as três silhuetas.
class _EmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 240;
    canvas.scale(u);

    // Moldura: um quadrilátero inclinado, aberto em dois cantos.
    final frame = Path()
      ..moveTo(62, 22)
      ..lineTo(188, 10)
      ..lineTo(176, 116)
      ..lineTo(48, 132)
      ..close();
    canvas.drawPath(
      frame,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF13233D), BrandColors.void0],
        ).createShader(const Rect.fromLTWH(40, 0, 160, 140)),
    );
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.miter
      ..shader = const LinearGradient(
        colors: [BrandColors.goldLight, BrandColors.gold, BrandColors.goldDark],
      ).createShader(const Rect.fromLTWH(40, 0, 160, 140));
    // Dois cantos em "L" (topo-esquerda e base-direita), como a moldura do LoL.
    canvas
      ..drawPath(
        Path()
          ..moveTo(56, 74)
          ..lineTo(62, 22)
          ..lineTo(126, 16),
        gold,
      )
      ..drawPath(
        Path()
          ..moveTo(182, 64)
          ..lineTo(176, 116)
          ..lineTo(112, 124),
        gold,
      );

    // Cortes vermelhos nos outros dois cantos.
    final red = Paint()..color = BrandColors.red;
    canvas
      ..drawPath(
        Path()
          ..moveTo(150, 12)
          ..lineTo(194, 6)
          ..lineTo(184, 70)
          ..lineTo(178, 70)
          ..lineTo(186, 14)
          ..close(),
        red,
      )
      ..drawPath(
        Path()
          ..moveTo(42, 136)
          ..lineTo(90, 130)
          ..lineTo(48, 132)
          ..lineTo(54, 76)
          ..lineTo(48, 76)
          ..close(),
        red,
      );

    // Losango ciano no topo (a "gema" hextech).
    canvas.drawPath(
      Path()
        ..moveTo(124, 8)
        ..lineTo(130, 14)
        ..lineTo(124, 20)
        ..lineTo(118, 14)
        ..close(),
      Paint()..color = BrandColors.cyan,
    );

    // O squad: duas silhuetas atrás, uma maior na frente.
    _person(canvas, const Offset(84, 50), 0.78);
    _person(canvas, const Offset(156, 50), 0.78);
    _person(canvas, const Offset(120, 38), 1);
  }

  /// Uma silhueta (cabeça arredondada + tronco em trapézio) com sombra
  /// vermelha deslocada, como na referência.
  void _person(Canvas canvas, Offset top, double scale) {
    Path shape(Offset o) {
      final s = scale;
      final head = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: o + Offset(0, 14 * s),
          width: 30 * s,
          height: 28 * s,
        ),
        Radius.circular(9 * s),
      );
      final body = Path()
        ..moveTo(o.dx - 14 * s, o.dy + 34 * s)
        ..lineTo(o.dx + 14 * s, o.dy + 34 * s)
        ..lineTo(o.dx + 30 * s, o.dy + 50 * s)
        ..lineTo(o.dx + 32 * s, o.dy + 72 * s)
        ..lineTo(o.dx - 32 * s, o.dy + 72 * s)
        ..lineTo(o.dx - 30 * s, o.dy + 50 * s)
        ..close();
      return Path()
        ..addRRect(head)
        ..addPath(body, Offset.zero);
    }

    canvas
      ..drawPath(
        shape(top + const Offset(3, 3)),
        Paint()..color = BrandColors.redDark,
      )
      ..drawPath(
        shape(top),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Colors.white, BrandColors.goldLight],
          ).createShader(Rect.fromLTWH(top.dx - 32, top.dy, 64, 72 * scale)),
      )
      ..drawPath(
        shape(top),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = BrandColors.void0,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Livro aberto dourado entre duas linhas vermelhas (as Ciências).
class _BookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 240;
    canvas.scale(u);

    final red = Paint()..color = BrandColors.red;
    // Linhas que afinam para as pontas.
    canvas
      ..drawPath(
        Path()
          ..moveTo(18, 17)
          ..lineTo(92, 15)
          ..lineTo(92, 19)
          ..close(),
        red,
      )
      ..drawPath(
        Path()
          ..moveTo(222, 17)
          ..lineTo(148, 15)
          ..lineTo(148, 19)
          ..close(),
        red,
      );

    // Capa vermelha por trás das páginas.
    canvas.drawPath(
      Path()
        ..moveTo(96, 8)
        ..lineTo(120, 26)
        ..lineTo(144, 8)
        ..lineTo(148, 28)
        ..lineTo(120, 34)
        ..lineTo(92, 28)
        ..close(),
      Paint()..color = BrandColors.redDark,
    );

    final pages = Paint()
      ..shader = const LinearGradient(
        colors: [BrandColors.goldLight, BrandColors.gold],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(const Rect.fromLTWH(96, 2, 48, 28));
    for (final dir in [-1.0, 1.0]) {
      final page = Path()
        ..moveTo(120, 28)
        ..quadraticBezierTo(120 + dir * 10, 4, 120 + dir * 24, 4)
        ..lineTo(120 + dir * 24, 24)
        ..quadraticBezierTo(120 + dir * 10, 22, 120, 28)
        ..close();
      canvas.drawPath(page, pages);
    }
    // Lombada.
    canvas.drawLine(
      const Offset(120, 10),
      const Offset(120, 28),
      Paint()
        ..color = BrandColors.goldDark
        ..strokeWidth = 1.5,
    );
    // Brilho sutil do livro (gema), como uma página "acesa".
    canvas.drawCircle(
      const Offset(120, 6),
      2,
      Paint()..color = BrandColors.cyan,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
