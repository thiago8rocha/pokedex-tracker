import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ícone de energia no estilo oficial do Pokémon TCG Pocket.
/// Círculo colorido com símbolo preto no centro.
class PocketEnergyIcon extends StatelessWidget {
  final String type;
  final double size;

  const PocketEnergyIcon({super.key, required this.type, this.size = 24});

  static const Map<String, Color> _bgColors = {
    'Grass':      Color(0xFF3D8B3D),
    'Fire':       Color(0xFFCC2200),
    'Water':      Color(0xFF1A6BB5),
    'Lightning':  Color(0xFFDDAA00),
    'Psychic':    Color(0xFF6A1FAB),
    'Fighting':   Color(0xFFAA3300),
    'Darkness':   Color(0xFF1A2A44),
    'Metal':      Color(0xFF6E7A85),
    'Fairy':      Color(0xFFE8E0D0),
    'Dragon':     Color(0xFF8B7530),
    'Colorless':  Color(0xFFAAAAAA),
    // aliases
    'Electric':   Color(0xFFDDAA00),
    'Dark':       Color(0xFF1A2A44),
    'Steel':      Color(0xFF6E7A85),
  };

  @override
  Widget build(BuildContext context) {
    final bg = _bgColors[type] ?? const Color(0xFFAAAAAA);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EnergyPainter(type: type, bgColor: bg),
      ),
    );
  }
}

class _EnergyPainter extends CustomPainter {
  final String type;
  final Color  bgColor;

  const _EnergyPainter({required this.type, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    // Fundo circular
    final bgPaint = Paint()..color = bgColor;
    canvas.drawCircle(Offset(cx, cy), r, bgPaint);

    // Símbolo preto
    final symPaint = Paint()
      ..color = _symbolColor()
      ..style = PaintingStyle.fill;

    final symStroke = Paint()
      ..color = _symbolColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final s = size.width * 0.55; // tamanho do símbolo
    final ox = cx - s / 2;
    final oy = cy - s / 2;

    switch (type) {
      case 'Grass':
        _drawGrass(canvas, cx, cy, s, symPaint, symStroke);
        break;
      case 'Fire':
        _drawFire(canvas, cx, cy, s, symPaint);
        break;
      case 'Water':
        _drawWater(canvas, cx, cy, s, symPaint);
        break;
      case 'Lightning':
      case 'Electric':
        _drawLightning(canvas, cx, cy, s, symPaint);
        break;
      case 'Psychic':
        _drawPsychic(canvas, cx, cy, s, symPaint, symStroke);
        break;
      case 'Fighting':
        _drawFighting(canvas, cx, cy, s, symPaint);
        break;
      case 'Darkness':
      case 'Dark':
        _drawDarkness(canvas, cx, cy, s, symPaint);
        break;
      case 'Metal':
      case 'Steel':
        _drawMetal(canvas, cx, cy, s, symPaint, symStroke);
        break;
      case 'Fairy':
        _drawFairy(canvas, cx, cy, s, symPaint);
        break;
      case 'Dragon':
        _drawDragon(canvas, cx, cy, s, symPaint, symStroke);
        break;
      default: // Colorless
        _drawColorless(canvas, cx, cy, s, symPaint);
    }
  }

  Color _symbolColor() {
    // Fairy usa símbolo escuro, os demais usam preto
    if (type == 'Fairy') return const Color(0xFF333333);
    return Colors.black;
  }

  // ── Grass: folha arredondada ─────────────────────────────────
  void _drawGrass(Canvas c, double cx, double cy, double s,
      Paint fill, Paint stroke) {
    final path = Path();
    final r = s * 0.45;
    // Folha: elipse inclinada
    path.addOval(Rect.fromCenter(
        center: Offset(cx, cy), width: s * 0.55, height: s * 0.9));
    // Rotacionar 15 graus
    final matrix = Matrix4.identity()
      ..translate(cx, cy)
      ..rotateZ(-0.26)
      ..translate(-cx, -cy);
    c.save();
    c.transform(matrix.storage);
    c.drawPath(path, fill);
    // Nervura central
    final vein = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.07;
    c.drawLine(Offset(cx, cy - r * 0.8), Offset(cx, cy + r * 0.8), vein);
    c.restore();
  }

  // ── Fire: chama ──────────────────────────────────────────────
  void _drawFire(Canvas c, double cx, double cy, double s, Paint fill) {
    final path = Path();
    final h = s * 0.9;
    final w = s * 0.65;
    // Chama principal
    path.moveTo(cx, cy - h * 0.5);
    path.cubicTo(
      cx + w * 0.5, cy - h * 0.1,
      cx + w * 0.4, cy + h * 0.3,
      cx, cy + h * 0.5,
    );
    path.cubicTo(
      cx - w * 0.4, cy + h * 0.3,
      cx - w * 0.5, cy - h * 0.1,
      cx, cy - h * 0.5,
    );
    c.drawPath(path, fill);
    // Chama interna (negativa — cor de fundo)
    final inner = Path();
    final iw = w * 0.45;
    final ih = h * 0.55;
    inner.moveTo(cx, cy - ih * 0.2);
    inner.cubicTo(
      cx + iw * 0.4, cy + ih * 0.1,
      cx + iw * 0.3, cy + ih * 0.4,
      cx, cy + ih * 0.5,
    );
    inner.cubicTo(
      cx - iw * 0.3, cy + ih * 0.4,
      cx - iw * 0.4, cy + ih * 0.1,
      cx, cy - ih * 0.2,
    );
    final innerPaint = Paint()..color = bgColor;
    c.drawPath(inner, innerPaint);
  }

  // ── Water: gota ──────────────────────────────────────────────
  void _drawWater(Canvas c, double cx, double cy, double s, Paint fill) {
    final path = Path();
    final h = s * 0.9;
    final w = s * 0.65;
    // Gota: ponta em cima, base redonda em baixo
    path.moveTo(cx, cy - h * 0.5);
    path.cubicTo(
      cx + w * 0.5, cy,
      cx + w * 0.45, cy + h * 0.25,
      cx, cy + h * 0.5,
    );
    path.cubicTo(
      cx - w * 0.45, cy + h * 0.25,
      cx - w * 0.5, cy,
      cx, cy - h * 0.5,
    );
    c.drawPath(path, fill);
  }

  // ── Lightning: raio ──────────────────────────────────────────
  void _drawLightning(Canvas c, double cx, double cy, double s, Paint fill) {
    final path = Path();
    final h = s * 0.9;
    final w = s * 0.6;
    // Raio em Z
    path.moveTo(cx + w * 0.2, cy - h * 0.5);
    path.lineTo(cx - w * 0.15, cy - h * 0.02);
    path.lineTo(cx + w * 0.12, cy - h * 0.02);
    path.lineTo(cx - w * 0.2, cy + h * 0.5);
    path.lineTo(cx + w * 0.15, cy + h * 0.02);
    path.lineTo(cx - w * 0.12, cy + h * 0.02);
    path.close();
    c.drawPath(path, fill);
  }

  // ── Psychic: olho ────────────────────────────────────────────
  void _drawPsychic(Canvas c, double cx, double cy, double s,
      Paint fill, Paint stroke) {
    // Contorno do olho
    final eyePath = Path();
    eyePath.moveTo(cx - s * 0.45, cy);
    eyePath.cubicTo(
      cx - s * 0.1, cy - s * 0.38,
      cx + s * 0.1, cy - s * 0.38,
      cx + s * 0.45, cy,
    );
    eyePath.cubicTo(
      cx + s * 0.1, cy + s * 0.38,
      cx - s * 0.1, cy + s * 0.38,
      cx - s * 0.45, cy,
    );
    c.drawPath(eyePath, fill);
    // Pupila (cor de fundo)
    final pupilPaint = Paint()..color = bgColor;
    c.drawCircle(Offset(cx, cy), s * 0.18, pupilPaint);
    // Brilho pupila (preto)
    c.drawCircle(Offset(cx, cy), s * 0.1, fill);
  }

  // ── Fighting: punho ──────────────────────────────────────────
  void _drawFighting(Canvas c, double cx, double cy, double s, Paint fill) {
    // Punho simplificado: retângulo arredondado com dedos
    final fist = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + s * 0.05),
          width: s * 0.75, height: s * 0.55),
      Radius.circular(s * 0.12),
    );
    c.drawRRect(fist, fill);
    // Linha separando dedos (cor fundo)
    final linePaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.06;
    final top = cy - s * 0.22;
    final bot = cy + s * 0.3;
    for (final x in [cx - s * 0.17, cx, cx + s * 0.17]) {
      c.drawLine(Offset(x, top), Offset(x, bot), linePaint);
    }
    // Polegar
    final thumb = Path();
    thumb.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - s * 0.38, cy - s * 0.28, s * 0.22, s * 0.32),
      Radius.circular(s * 0.08),
    ));
    c.drawPath(thumb, fill);
  }

  // ── Darkness: círculo com lua ────────────────────────────────
  void _drawDarkness(Canvas c, double cx, double cy, double s, Paint fill) {
    // Círculo cheio com recorte de lua
    c.drawCircle(Offset(cx, cy), s * 0.42, fill);
    final cutPaint = Paint()..color = bgColor;
    c.drawCircle(Offset(cx + s * 0.18, cy - s * 0.1), s * 0.32, cutPaint);
  }

  // ── Metal: triângulo geométrico (escudo) ─────────────────────
  void _drawMetal(Canvas c, double cx, double cy, double s,
      Paint fill, Paint stroke) {
    // Hexágono estilizado / escudo triangular
    final path = Path();
    final r = s * 0.42;
    // Triângulo apontando pra baixo com cantos cortados
    path.moveTo(cx, cy - r);
    path.lineTo(cx + r * 0.7, cy - r * 0.3);
    path.lineTo(cx + r * 0.45, cy + r);
    path.lineTo(cx - r * 0.45, cy + r);
    path.lineTo(cx - r * 0.7, cy - r * 0.3);
    path.close();
    c.drawPath(path, fill);
    // Recorte interno
    final inner = Path();
    final ri = r * 0.55;
    inner.moveTo(cx, cy - ri * 0.7);
    inner.lineTo(cx + ri * 0.5, cy - ri * 0.15);
    inner.lineTo(cx + ri * 0.32, cy + ri * 0.7);
    inner.lineTo(cx - ri * 0.32, cy + ri * 0.7);
    inner.lineTo(cx - ri * 0.5, cy - ri * 0.15);
    inner.close();
    c.drawPath(inner, Paint()..color = bgColor);
  }

  // ── Fairy: estrela ───────────────────────────────────────────
  void _drawFairy(Canvas c, double cx, double cy, double s, Paint fill) {
    final path = Path();
    const spikes = 6;
    final outerR = s * 0.43;
    final innerR = s * 0.2;
    for (int i = 0; i < spikes * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = (i * math.pi / spikes) - math.pi / 2;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    c.drawPath(path, fill);
  }

  // ── Dragon: garra ────────────────────────────────────────────
  void _drawDragon(Canvas c, double cx, double cy, double s,
      Paint fill, Paint stroke) {
    // Garra curvada
    final path = Path();
    final w = s * 0.65;
    final h = s * 0.8;
    path.moveTo(cx - w * 0.1, cy - h * 0.5);
    path.cubicTo(
      cx + w * 0.5, cy - h * 0.3,
      cx + w * 0.5, cy + h * 0.2,
      cx, cy + h * 0.5,
    );
    path.cubicTo(
      cx - w * 0.2, cy + h * 0.2,
      cx - w * 0.3, cy - h * 0.1,
      cx - w * 0.1, cy - h * 0.5,
    );
    c.drawPath(path, fill);
  }

  // ── Colorless: estrela simples ───────────────────────────────
  void _drawColorless(Canvas c, double cx, double cy, double s, Paint fill) {
    final path = Path();
    const spikes = 4;
    final outerR = s * 0.42;
    final innerR = s * 0.16;
    for (int i = 0; i < spikes * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = (i * math.pi / spikes) - math.pi / 4;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    c.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(_EnergyPainter old) =>
      old.type != type || old.bgColor != bgColor;
}
