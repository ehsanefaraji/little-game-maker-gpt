import 'package:flutter/material.dart';
import 'game_models.dart';

/// Lightweight vector artwork: crisp at every screen density and requires no
/// downloaded images or network access.
class GameTileArt extends StatelessWidget {
  const GameTileArt({
    super.key,
    required this.type,
    required this.value,
    this.character = 0,
    this.isPlayer = false,
  });

  final GameType type;
  final int value;
  final int character;
  final bool isPlayer;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _GameTilePainter(
          type: type,
          value: value,
          character: character,
          isPlayer: isPlayer,
        ),
        child: const SizedBox.expand(),
      );
}

class _GameTilePainter extends CustomPainter {
  _GameTilePainter({
    required this.type,
    required this.value,
    required this.character,
    required this.isPlayer,
  }) : _paint = Paint()..isAntiAlias = true;

  final GameType type;
  final int value;
  final int character;
  final bool isPlayer;

  final Paint _paint;

  void _fill(Color color) => _paint
    ..color = color
    ..style = PaintingStyle.fill;

  void _round(Canvas canvas, Rect rect, double radius, Color color) {
    _fill(color);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), _paint);
  }

  void _circle(Canvas canvas, Offset center, double radius, Color color) {
    _fill(color);
    canvas.drawCircle(center, radius, _paint);
  }

  void _stroke(Canvas canvas, Path path, Color color, double width) {
    _paint
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, _paint);
    _paint.style = PaintingStyle.fill;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = size.shortestSide / 48;
    canvas.save();
    canvas.scale(scale);
    final w = size.width / scale;
    final h = size.height / scale;

    if (type == GameType.driving) {
      _paintRoadCell(canvas, w, h);
    } else if (type == GameType.platformer && value == 1) {
      _paintPlatform(canvas, w, h);
    } else if (type == GameType.maze && value == 1) {
      _paintWall(canvas, w, h);
    } else if (isPlayer) {
      _paintHero(canvas, w, h);
    } else if (value == 2) {
      _paintGem(canvas, w, h);
    } else if (value == 3) {
      _paintEnemy(canvas, w, h);
    } else if (value == 4) {
      _paintGoal(canvas, w, h);
    } else if (value == 5) {
      _paintStart(canvas, w, h);
    }
    canvas.restore();
  }

  void _paintWall(Canvas canvas, double w, double h) {
    _round(canvas, Rect.fromLTWH(3, 7, w - 6, h - 10), 7, const Color(0xFF9279C9));
    _round(canvas, Rect.fromLTWH(4, 5, w - 8, h * .35), 5, const Color(0xFFBBA9EC));
    _fill(const Color(0xFF8067B8));
    canvas.drawLine(Offset(w * .5, 6), Offset(w * .5, h * .37), _paint..strokeWidth = 2);
    canvas.drawLine(Offset(4, h * .65), Offset(w - 4, h * .65), _paint..strokeWidth = 2);
  }

  void _paintPlatform(Canvas canvas, double w, double h) {
    _round(canvas, Rect.fromLTWH(1, 9, w - 2, h - 10), 5, const Color(0xFF95613E));
    _round(canvas, Rect.fromLTWH(1, 5, w - 2, 13), 5, const Color(0xFF65B95E));
    _fill(const Color(0xFF9BDB71));
    for (var x = 8.0; x < w; x += 13) {
      canvas.drawCircle(Offset(x, 9), 3, _paint);
    }
  }

  void _paintGem(Canvas canvas, double w, double h) {
    final path = Path()
      ..moveTo(w * .5, h * .08)
      ..lineTo(w * .88, h * .38)
      ..lineTo(w * .68, h * .9)
      ..lineTo(w * .32, h * .9)
      ..lineTo(w * .12, h * .38)
      ..close();
    _fill(const Color(0xFF22B9D7));
    canvas.drawPath(path, _paint);
    _fill(const Color(0xFF9CF5F5));
    canvas.drawPath(Path()..moveTo(w * .5, h * .08)..lineTo(w * .48, h * .72)..lineTo(w * .12, h * .38)..close(), _paint);
    _fill(const Color(0xFF5DE0E7));
    canvas.drawPath(Path()..moveTo(w * .5, h * .08)..lineTo(w * .88, h * .38)..lineTo(w * .52, h * .72)..close(), _paint);
  }

  void _paintEnemy(Canvas canvas, double w, double h) {
    _circle(canvas, Offset(w * .5, h * .55), w * .34, const Color(0xFFE66C87));
    _circle(canvas, Offset(w * .25, h * .28), w * .13, const Color(0xFFE66C87));
    _circle(canvas, Offset(w * .75, h * .28), w * .13, const Color(0xFFE66C87));
    _circle(canvas, Offset(w * .38, h * .49), 2.8, Colors.white);
    _circle(canvas, Offset(w * .62, h * .49), 2.8, Colors.white);
    _circle(canvas, Offset(w * .39, h * .5), 1.2, const Color(0xFF332B4D));
    _circle(canvas, Offset(w * .63, h * .5), 1.2, const Color(0xFF332B4D));
    final mouth = Path()..moveTo(w * .38, h * .68)..quadraticBezierTo(w * .5, h * .78, w * .63, h * .67);
    _stroke(canvas, mouth, const Color(0xFF8B354C), 1.8);
  }

  void _paintGoal(Canvas canvas, double w, double h) {
    _round(canvas, Rect.fromLTWH(w * .22, h * .16, w * .56, h * .76), 7, const Color(0xFF8C5BBD));
    _round(canvas, Rect.fromLTWH(w * .3, h * .25, w * .4, h * .67), 5, const Color(0xFFFFD36A));
    _circle(canvas, Offset(w * .62, h * .6), 2, const Color(0xFF8C5BBD));
    _circle(canvas, Offset(w * .5, h * .12), 4, const Color(0xFFFFE89A));
  }

  void _paintStart(Canvas canvas, double w, double h) {
    _round(canvas, Rect.fromLTWH(w * .17, h * .2, w * .66, h * .68), 5, const Color(0xFF4DAD82));
    _fill(Colors.white);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        if ((row + col).isEven) {
          canvas.drawRect(Rect.fromLTWH(w * (.25 + col * .17), h * (.3 + row * .17), w * .17, h * .17), _paint);
        }
      }
    }
  }

  void _paintHero(Canvas canvas, double w, double h) {
    final palette = [
      const Color(0xFF5B8FE8), const Color(0xFFE985A6), const Color(0xFFEA9A55),
      const Color(0xFF64BFA2), const Color(0xFFEA8C52), const Color(0xFF8C91A8),
      const Color(0xFFB27BD7), const Color(0xFF55B9C9),
    ];
    final fur = palette[character.clamp(0, palette.length - 1).toInt()];
    final cx = w * .5;
    _circle(canvas, Offset(cx, h * .9), w * .29, const Color(0x22000000));
    // Rounded body, little arms and shoes give the mascot a readable silhouette.
    _round(canvas, Rect.fromLTWH(w*.28,h*.57,w*.44,h*.31), 10, fur);
    _circle(canvas, Offset(w*.24,h*.68), w*.105, fur);
    _circle(canvas, Offset(w*.76,h*.68), w*.105, fur);
    _round(canvas, Rect.fromLTWH(w*.31,h*.82,w*.16,h*.11), 4, const Color(0xFF493B59));
    _round(canvas, Rect.fromLTWH(w*.53,h*.82,w*.16,h*.11), 4, const Color(0xFF493B59));

    if (character == 7) {
      _round(canvas, Rect.fromLTWH(w*.2,h*.12,w*.6,h*.48), 10, const Color(0xFF7A8D9E));
      _round(canvas, Rect.fromLTWH(w*.28,h*.2,w*.44,h*.31), 7, const Color(0xFFBDECF1));
      _circle(canvas, Offset(w*.4,h*.34), 3.1, const Color(0xFF24465D));
      _circle(canvas, Offset(w*.6,h*.34), 3.1, const Color(0xFF24465D));
      _round(canvas, Rect.fromLTWH(w*.42,h*.44,w*.16,h*.035), 3, const Color(0xFF398C9D));
      _stroke(canvas, Path()..moveTo(cx,h*.12)..lineTo(cx,h*.035), const Color(0xFF7A8D9E), 3);
      _circle(canvas, Offset(cx,h*.025), 3.5, const Color(0xFFFFD66B));
      return;
    }

    // Animal ears and species-specific silhouettes.
    if (character == 2 || character == 4) {
      final left = Path()..moveTo(w*.23,h*.34)..lineTo(w*.27,h*.04)..lineTo(w*.46,h*.28)..close();
      final right = Path()..moveTo(w*.54,h*.28)..lineTo(w*.75,h*.04)..lineTo(w*.78,h*.34)..close();
      _fill(fur); canvas.drawPath(left,_paint); canvas.drawPath(right,_paint);
      _fill(const Color(0xFFFFC3C9));
      canvas.drawPath(Path()..moveTo(w*.29,h*.27)..lineTo(w*.30,h*.12)..lineTo(w*.40,h*.27)..close(),_paint);
      canvas.drawPath(Path()..moveTo(w*.60,h*.27)..lineTo(w*.70,h*.12)..lineTo(w*.71,h*.27)..close(),_paint);
    } else if (character == 3) {
      _circle(canvas, Offset(w*.34,h*.23), w*.17, fur);
      _circle(canvas, Offset(w*.66,h*.23), w*.17, fur);
      _circle(canvas, Offset(w*.34,h*.21), w*.095, Colors.white);
      _circle(canvas, Offset(w*.66,h*.21), w*.095, Colors.white);
    } else if (character == 5) {
      _circle(canvas, Offset(w*.29,h*.23), w*.14, const Color(0xFF343746));
      _circle(canvas, Offset(w*.71,h*.23), w*.14, const Color(0xFF343746));
    } else if (character == 6) {
      _circle(canvas, Offset(w*.5,h*.1), w*.07, const Color(0xFFFFD76B));
      final horn=Path()..moveTo(w*.44,h*.2)..lineTo(w*.5,h*.0)..lineTo(w*.56,h*.2)..close();
      _fill(const Color(0xFFFFD76B)); canvas.drawPath(horn,_paint);
      _circle(canvas, Offset(w*.22,h*.39), w*.12, const Color(0xFFEC8DBB));
      _circle(canvas, Offset(w*.78,h*.39), w*.12, const Color(0xFF8D82E5));
    }

    _circle(canvas, Offset(cx,h*.4), w*.29, character == 5 ? const Color(0xFFF5F3EE) : const Color(0xFFFFD9BE));
    if (character == 5) {
      _circle(canvas, Offset(w*.39,h*.39), w*.09, const Color(0xFF343746));
      _circle(canvas, Offset(w*.61,h*.39), w*.09, const Color(0xFF343746));
    }
    _circle(canvas, Offset(w*.39,h*.39), w*.045, Colors.white);
    _circle(canvas, Offset(w*.61,h*.39), w*.045, Colors.white);
    _circle(canvas, Offset(w*.395,h*.395), w*.022, const Color(0xFF342B43));
    _circle(canvas, Offset(w*.605,h*.395), w*.022, const Color(0xFF342B43));
    if (character == 4 || character == 2 || character == 5) {
      _circle(canvas, Offset(cx,h*.49), w*.105, const Color(0xFFFFF0D8));
      _circle(canvas, Offset(cx,h*.46), w*.035, const Color(0xFF594052));
    } else {
      _circle(canvas, Offset(cx,h*.49), w*.025, const Color(0xFFCE7184));
    }
    final smile = Path()..moveTo(w*.43,h*.53)..quadraticBezierTo(cx,h*.59,w*.57,h*.53);
    _stroke(canvas, smile, const Color(0xFF9C5663), 1.8);
    _circle(canvas, Offset(w*.29,h*.49), w*.045, const Color(0x66F28DA1));
    _circle(canvas, Offset(w*.71,h*.49), w*.045, const Color(0x66F28DA1));
  }


  static const inkColor = Color(0xFF332B4D);

  void _paintRoadCell(Canvas canvas, double w, double h) {
    if (isPlayer) {
      _round(canvas, Rect.fromLTWH(w * .23, h * .12, w * .54, h * .76), 9, const Color(0xFF3988E8));
      _round(canvas, Rect.fromLTWH(w * .31, h * .22, w * .38, h * .25), 6, const Color(0xFFBCEBFF));
      _round(canvas, Rect.fromLTWH(w * .31, h * .61, w * .38, h * .16), 4, const Color(0xFF1D4D8E));
      _round(canvas, Rect.fromLTWH(w * .17, h * .2, w * .1, h * .2), 3, const Color(0xFF242A3A));
      _round(canvas, Rect.fromLTWH(w * .73, h * .2, w * .1, h * .2), 3, const Color(0xFF242A3A));
      _round(canvas, Rect.fromLTWH(w * .17, h * .62, w * .1, h * .2), 3, const Color(0xFF242A3A));
      _round(canvas, Rect.fromLTWH(w * .73, h * .62, w * .1, h * .2), 3, const Color(0xFF242A3A));
    } else if (value == 3) {
      _round(canvas, Rect.fromLTWH(w * .25, h * .22, w * .5, h * .58), 5, const Color(0xFFF1A83C));
      _round(canvas, Rect.fromLTWH(w * .32, h * .28, w * .36, h * .13), 3, const Color(0xFFFFE9B2));
      _round(canvas, Rect.fromLTWH(w * .32, h * .6, w * .36, h * .12), 3, const Color(0xFFCE6A3B));
    } else if (value == 2) {
      _circle(canvas, Offset(w * .5, h * .5), w * .22, const Color(0xFFFFD34E));
      _circle(canvas, Offset(w * .5, h * .5), w * .15, const Color(0xFFFFF0A5));
    }
  }

  @override
  bool shouldRepaint(covariant _GameTilePainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.value != value ||
      oldDelegate.character != character || oldDelegate.isPlayer != isPlayer;
}

class GameBackdropPainter extends CustomPainter {
  const GameBackdropPainter(this.background);
  final int background;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final tops = [const Color(0xFF86CFF2), const Color(0xFF73C7EA), const Color(0xFF17204F), const Color(0xFFFFAFCB)];
    final bottoms = [const Color(0xFFFFE5AE), const Color(0xFFFFE3A1), const Color(0xFF6854A0), const Color(0xFFFFE5B8)];
    final index = background.clamp(0, tops.length - 1).toInt();
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [tops[index], bottoms[index]]).createShader(rect));

    final night = index == 2;
    final sunCenter = Offset(size.width * .78, size.height * .16);
    canvas.drawCircle(sunCenter, size.width * .105, Paint()..color = (night ? const Color(0x3379B8FF) : const Color(0x44FFF4B0)));
    canvas.drawCircle(sunCenter, size.width * .065, Paint()..color = night ? const Color(0xFFE4E8FF) : const Color(0xFFFFE99B));

    if (night) {
      final stars = Paint()..color = const Color(0xFFFFF4C6);
      for (var i = 0; i < 34; i++) {
        final x = size.width * ((i * 37 % 97) / 100);
        final y = size.height * ((i * 19 % 53) / 100);
        canvas.drawCircle(Offset(x, y), i % 4 == 0 ? 2.1 : 1.1, stars);
      }
    } else {
      final cloud = Paint()..color = Colors.white.withOpacity(.62);
      for (var i = 0; i < 5; i++) {
        final x = size.width * (i * .23 + .04);
        final y = size.height * (.13 + (i % 3) * .105);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y + 5), width: 66, height: 18), const Radius.circular(12)), cloud);
        canvas.drawCircle(Offset(x - 15, y), 13, cloud);
        canvas.drawCircle(Offset(x + 1, y - 7), 17, cloud);
        canvas.drawCircle(Offset(x + 19, y + 1), 12, cloud);
      }
    }

    void hill(double y, Color color, double amplitude, double phase) {
      final path = Path()..moveTo(0, size.height * y);
      path.cubicTo(size.width * .18, size.height * (y - amplitude), size.width * .34, size.height * (y + amplitude * .55), size.width * .54, size.height * (y - phase));
      path.cubicTo(size.width * .73, size.height * (y - amplitude), size.width * .87, size.height * (y + amplitude), size.width, size.height * (y - .025));
      path.lineTo(size.width, size.height); path.lineTo(0, size.height); path.close();
      canvas.drawPath(path, Paint()..color = color);
    }
    hill(.68, night ? const Color(0xFF34366F) : const Color(0xFF8BB6A2), .15, .025);
    hill(.78, night ? const Color(0xFF42417F) : const Color(0xFF5DAB86), .12, .04);
    hill(.88, night ? const Color(0xFF282D60) : const Color(0xFF347A5D), .09, .015);

    // Layered foreground foliage frames the play area without obscuring controls.
    final leaf = Paint()..color = (night ? const Color(0xFF272C62) : const Color(0xFF286C56)).withOpacity(.92);
    for (var side = 0; side < 2; side++) {
      final x = side == 0 ? size.width * .025 : size.width * .975;
      for (var i = 0; i < 4; i++) {
        final y = size.height * (.68 + i * .075);
        canvas.drawCircle(Offset(x + (side == 0 ? 1 : -1) * i * 4, y), size.width * (.045 - i * .004), leaf);
      }
    }
    final grass = Paint()..color = const Color(0x6683D77D)..strokeWidth = 2..strokeCap = StrokeCap.round;
    if (!night) {
      for (var i = 0; i < 28; i++) {
        final x = size.width * (i / 28);
        final y = size.height * (.91 + (i % 3) * .012);
        canvas.drawLine(Offset(x, y), Offset(x - 3, y - 7 - (i % 4)), grass);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GameBackdropPainter oldDelegate) => oldDelegate.background != background;
}
