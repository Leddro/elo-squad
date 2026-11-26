import 'package:material_ui/material_ui.dart';

import '../theme/brand_colors.dart';

/// A logo completa: o brasão com asas, "ELO SQUAD" e o filete com a gema.
/// Desenhada em código (vetor), fica nítida em qualquer tamanho. [width]
/// define o tamanho de tudo.
class EloSquadLogo extends StatelessWidget {
  const EloSquadLogo({super.key, this.width = 240});

  final double width;

  @override
  Widget build(BuildContext context) {
    final u = width / 280; // unidade: tudo foi desenhado numa caixa de 280
    return Semantics(
      label: 'Elo Squad',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EloSquadEmblem(size: 200 * u, wings: true),
              SizedBox(height: 10 * u),
              _Wordmark(fontSize: 28 * u),
              SizedBox(height: 10 * u),
              CustomPaint(size: Size(180 * u, 10 * u), painter: _RulePainter()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Só o brasão: o losango dourado, as três lâminas (o squad) e a gema
/// hextech. Sem as asas, é a versão para ícones e espaços pequenos.
class EloSquadEmblem extends StatelessWidget {
  const EloSquadEmblem({super.key, this.size = 48, this.wings = false});

  final double size;
  final bool wings;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _EmblemPainter(wings: wings),
  );
}

/// "ELO SQUAD" serifado, dourado metálico, com contorno escuro.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.fontSize});

  final double fontSize;

  static const _fill = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFF6DF),
      BrandColors.goldLight,
      BrandColors.gold,
      Color(0xFF9C7E44),
    ],
    stops: [0, 0.5, 0.52, 1],
  );

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'Cardo',
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      height: 1,
      letterSpacing: fontSize * 0.18,
      decoration: TextDecoration.none,
    );
    const text = 'ELO SQUAD';
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Stack(
        children: [
          // Contorno: o mesmo texto, só com traço, por baixo.
          Text(
            text,
            style: style.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = fontSize * 0.14
                ..strokeJoin = StrokeJoin.round
                ..color = BrandColors.void0,
            ),
          ),
          ShaderMask(
            shaderCallback: _fill.createShader,
            blendMode: BlendMode.srcIn,
            child: Text(text, style: style.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Filete dourado que some nas pontas, com um losango ciano no meio.
class _RulePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final d = size.height / 2; // meia-diagonal do losango
    final line = size.height * 0.15;
    final gap = d * 2;

    void fade(Rect r, {required bool toRight}) => canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          colors: toRight
              ? [BrandColors.gold.withValues(alpha: 0), BrandColors.gold]
              : [BrandColors.gold, BrandColors.gold.withValues(alpha: 0)],
        ).createShader(r),
    );

    fade(
      Rect.fromLTRB(0, cy - line / 2, cx - gap, cy + line / 2),
      toRight: true,
    );
    fade(
      Rect.fromLTRB(cx + gap, cy - line / 2, size.width, cy + line / 2),
      toRight: false,
    );

    final gem = Path()
      ..moveTo(cx, cy - d)
      ..lineTo(cx + d, cy)
      ..lineTo(cx, cy + d)
      ..lineTo(cx - d, cy)
      ..close();
    canvas
      ..drawPath(gem, Paint()..color = BrandColors.cyan)
      ..drawPath(
        gem,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = d * 0.2
          ..color = BrandColors.gold,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// O brasão, desenhado numa caixa de 200x200.
class _EmblemPainter extends CustomPainter {
  _EmblemPainter({required this.wings});

  final bool wings;

  static const _goldXL = Color(0xFFFFF6DF);
  static const _cyanLight = Color(0xFF9EFFF5);
  static const _cyanDeep = Color(0xFF005A82);

  /// Dourado claro (face iluminada das peças).
  static Paint _light(Rect r) => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_goldXL, BrandColors.gold, Color(0xFFA88A4E)],
      stops: [0, 0.55, 1],
    ).createShader(r);

  /// Dourado escuro (face na sombra).
  static Paint _dark(Rect r) => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [BrandColors.gold, BrandColors.goldDark],
    ).createShader(r);

  static Paint _outline(double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..color = BrandColors.void0;

  static Path _poly(List<Offset> pts) => Path()..addPolygon(pts, true);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200);

    if (wings) _paintWings(canvas);

    // Moldura: losango com fundo azul e borda dourada.
    final outer = _poly(const [
      Offset(100, 10),
      Offset(164, 92),
      Offset(100, 190),
      Offset(36, 92),
    ]);
    final bounds = outer.getBounds();
    canvas
      ..drawPath(
        outer,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0, 0.24),
            radius: 0.6,
            colors: [Color(0xFF123049), Color(0xFF0B1B2E), BrandColors.void0],
            stops: [0, 0.6, 1],
          ).createShader(bounds),
      )
      ..drawPath(
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.miter
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              BrandColors.goldLight,
              BrandColors.gold,
              BrandColors.goldDark,
            ],
            stops: [0, 0.45, 1],
          ).createShader(bounds),
      );

    final inner = _poly(const [
      Offset(100, 24),
      Offset(152, 92),
      Offset(100, 174),
      Offset(48, 92),
    ]);
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = BrandColors.goldDark,
    );

    // Entalhes nas pontas de cima e de baixo.
    final notch = Paint()..color = BrandColors.goldLight;
    canvas
      ..drawPath(
        _poly(const [Offset(94, 10), Offset(100, 18), Offset(106, 10)]),
        notch,
      )
      ..drawPath(
        _poly(const [Offset(94, 190), Offset(100, 182), Offset(106, 190)]),
        notch,
      );

    // Brilho da gema, preso dentro da moldura.
    canvas
      ..save()
      ..clipPath(inner)
      ..drawCircle(
        const Offset(100, 142),
        46,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  BrandColors.cyan.withValues(alpha: 0.75),
                  BrandColors.cyan.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(center: const Offset(100, 142), radius: 46),
              ),
      )
      ..restore();

    // O squad: três lâminas que sobem de uma base comum.
    _blade(canvas, const Offset(70, 58), const Offset(90, 134), 9);
    _blade(canvas, const Offset(130, 58), const Offset(110, 134), 9);
    _blade(canvas, const Offset(100, 36), const Offset(100, 136), 12);

    // Berço que une as lâminas.
    final cradle = Path()
      ..moveTo(62, 122)
      ..quadraticBezierTo(100, 156, 138, 122)
      ..lineTo(134, 134)
      ..quadraticBezierTo(100, 166, 66, 134)
      ..close();
    canvas
      ..drawPath(cradle, _dark(cradle.getBounds()))
      ..drawPath(cradle, _outline(1.4));

    // Gema hextech.
    final gem = _poly(const [
      Offset(100, 128),
      Offset(112, 142),
      Offset(100, 158),
      Offset(88, 142),
    ]);
    canvas
      ..drawPath(
        gem,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_cyanLight, BrandColors.cyan, _cyanDeep],
          ).createShader(gem.getBounds()),
      )
      ..drawPath(
        _poly(const [
          Offset(100, 128),
          Offset(112, 142),
          Offset(100, 144),
          Offset(88, 142),
        ]),
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      )
      ..drawPath(
        gem,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = BrandColors.goldLight,
      );
  }

  /// Lâmina facetada: metade clara, metade escura (efeito de metal).
  void _blade(Canvas canvas, Offset tip, Offset base, double w) {
    final dir = base - tip;
    final normal = Offset(-dir.dy, dir.dx) / dir.distance;
    final shoulder = tip + dir * 0.55;
    final left = _poly([
      tip,
      shoulder + normal * w,
      base + normal * (w * 0.45),
      base,
    ]);
    final right = _poly([
      tip,
      shoulder - normal * w,
      base - normal * (w * 0.45),
      base,
    ]);
    final whole = _poly([
      tip,
      shoulder + normal * w,
      base + normal * (w * 0.45),
      base - normal * (w * 0.45),
      shoulder - normal * w,
    ]);
    canvas
      ..drawPath(left, _light(left.getBounds()))
      ..drawPath(right, _dark(right.getBounds()))
      ..drawPath(whole, _outline(1.6));
  }

  /// Três penas curvas de cada lado, saindo das pontas do losango.
  void _paintWings(Canvas canvas) {
    final feathers = [
      Path()
        ..moveTo(40, 92)
        ..quadraticBezierTo(18, 74, 0, 72)
        ..quadraticBezierTo(16, 82, 22, 90)
        ..quadraticBezierTo(30, 96, 40, 100)
        ..close(),
      Path()
        ..moveTo(38, 100)
        ..quadraticBezierTo(16, 96, 4, 100)
        ..quadraticBezierTo(20, 104, 26, 108)
        ..quadraticBezierTo(32, 110, 42, 108)
        ..close(),
      Path()
        ..moveTo(42, 108)
        ..quadraticBezierTo(24, 116, 14, 126)
        ..quadraticBezierTo(28, 122, 36, 120)
        ..quadraticBezierTo(42, 118, 48, 114)
        ..close(),
    ];
    for (final mirrored in [false, true]) {
      canvas.save();
      if (mirrored) {
        canvas
          ..translate(200, 0)
          ..scale(-1, 1);
      }
      for (var i = 0; i < feathers.length; i++) {
        final f = feathers[i];
        final b = f.getBounds();
        canvas
          ..drawPath(f, i == 1 ? _dark(b) : _light(b))
          ..drawPath(f, _outline(1.2));
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter oldDelegate) =>
      oldDelegate.wings != wings;
}
