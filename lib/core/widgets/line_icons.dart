import 'package:flutter/material.dart';

/// The drawn icons — thin outlines rather than filled Material glyphs.
///
/// Material's icon set is excellent and completely wrong for this game: its
/// shapes are optimised to read at 20px inside a toolbar, and they carry an
/// unmistakable app-UI accent. A stroked path at the same weight as the
/// hairlines elsewhere in the chrome belongs to the same drawing.
///
/// Every shape is authored on a 24×24 grid and scaled from there, so one
/// stroke width holds across sizes.
enum LineIconShape {
  fir,
  dune,
  peaks,
  wave,
  headstone,
  mug,
  reeds,

  /// Fallback for a biome this file has not been taught yet — content ships
  /// as data, so a new biome id must never crash or draw nothing.
  waypoint,

  /// The prologue: the party has not left yet.
  home,

  flask,
  die,
  trash,
  warning,
  chevronLeft,

  /// The win screen's seal, and the five marks its joke titles wear.
  trophy,
  starBurst,
  lockedChest,
  mask,
  backpack,
  heart,
}

/// Maps a `Biome.id` to its drawn mark. Ids come from
/// `assets/data/biomes/biomes.json`; anything unknown falls back to
/// [LineIconShape.waypoint].
LineIconShape biomeLineIcon(String biomeId) => switch (biomeId) {
  'forest' => LineIconShape.fir,
  'desert' => LineIconShape.dune,
  'mountains' => LineIconShape.peaks,
  'coast' => LineIconShape.wave,
  'graveyard' => LineIconShape.headstone,
  'tavern' => LineIconShape.mug,
  'floodlands' => LineIconShape.reeds,
  _ => LineIconShape.waypoint,
};

class LineIcon extends StatelessWidget {
  final LineIconShape shape;
  final double size;
  final Color color;
  final double strokeWidth;

  const LineIcon({
    super.key,
    required this.shape,
    required this.color,
    this.size = 24,
    this.strokeWidth = 1.35,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _LineIconPainter(
          shape: shape,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _LineIconPainter extends CustomPainter {
  final LineIconShape shape;
  final Color color;
  final double strokeWidth;

  const _LineIconPainter({
    required this.shape,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Everything below is drawn on a 24-unit grid; the stroke is applied
    // after the scale so it keeps its authored thickness in real pixels.
    final unit = size.shortestSide / 24;
    canvas.save();
    canvas.scale(unit);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth / unit
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (shape) {
      case LineIconShape.fir:
        // Three tiers and a trunk.
        for (final tier in const [
          [7.0, 4.0, 10.5],
          [5.5, 9.5, 13.0],
          [4.0, 15.0, 16.0],
        ]) {
          canvas.drawPath(
            Path()
              ..moveTo(tier[0], tier[2])
              ..lineTo(12, tier[1])
              ..lineTo(24 - tier[0], tier[2]),
            stroke,
          );
        }
        canvas.drawLine(const Offset(12, 16), const Offset(12, 20.5), stroke);

      case LineIconShape.dune:
        canvas.drawCircle(const Offset(16, 7.5), 3, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(2.5, 18)
            ..quadraticBezierTo(7, 11.5, 11.5, 18)
            ..moveTo(9.5, 20.5)
            ..quadraticBezierTo(15, 14.5, 21.5, 20.5),
          stroke,
        );

      case LineIconShape.peaks:
        canvas.drawPath(
          Path()
            ..moveTo(1.5, 19)
            ..lineTo(8, 8)
            ..lineTo(12.5, 15)
            ..lineTo(15.5, 10.5)
            ..lineTo(22.5, 19),
          stroke,
        );
        canvas.drawLine(const Offset(6, 12.5), const Offset(10, 12.5), stroke);

      case LineIconShape.wave:
        for (var i = 0; i < 3; i++) {
          final y = 8.5 + i * 3.8;
          canvas.drawPath(
            Path()
              ..moveTo(2.5, y)
              ..quadraticBezierTo(6, y - 2.4, 9.5, y)
              ..quadraticBezierTo(13, y + 2.4, 16.5, y)
              ..quadraticBezierTo(19, y - 1.7, 21.5, y),
            stroke,
          );
        }

      case LineIconShape.headstone:
        canvas.drawPath(
          Path()
            ..moveTo(6.5, 20)
            ..lineTo(6.5, 10)
            ..arcToPoint(
              const Offset(17.5, 10),
              radius: const Radius.circular(5.5),
            )
            ..lineTo(17.5, 20),
          stroke,
        );
        canvas.drawLine(const Offset(12, 7.5), const Offset(12, 15), stroke);
        canvas.drawLine(const Offset(9, 10.5), const Offset(15, 10.5), stroke);
        canvas.drawLine(const Offset(4, 20), const Offset(20, 20), stroke);

      case LineIconShape.mug:
        canvas.drawPath(
          Path()
            ..moveTo(6, 8.5)
            ..lineTo(6, 19)
            ..arcToPoint(
              const Offset(9, 21.5),
              radius: const Radius.circular(3),
            )
            ..lineTo(13.5, 21.5)
            ..arcToPoint(
              const Offset(16.5, 19),
              radius: const Radius.circular(3),
            )
            ..lineTo(16.5, 8.5)
            ..close(),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(16.5, 11)
            ..lineTo(19.5, 11)
            ..arcToPoint(
              const Offset(19.5, 16.5),
              radius: const Radius.circular(2.8),
            )
            ..lineTo(16.5, 16.5),
          stroke,
        );
        // The head on the beer, drawn as one soft crest.
        canvas.drawPath(
          Path()
            ..moveTo(6, 8.5)
            ..quadraticBezierTo(8, 5.2, 11.25, 7)
            ..quadraticBezierTo(14.5, 4.4, 16.5, 8.5),
          stroke,
        );

      case LineIconShape.reeds:
        canvas.drawPath(
          Path()
            ..moveTo(2.5, 18.5)
            ..quadraticBezierTo(6, 16.4, 9.5, 18.5)
            ..quadraticBezierTo(13, 20.6, 16.5, 18.5)
            ..quadraticBezierTo(19, 17, 21.5, 18.5),
          stroke,
        );
        for (final x in const [7.0, 12.0, 17.0]) {
          canvas.drawLine(Offset(x, 15.5), Offset(x, 5.5), stroke);
          canvas.drawPath(
            Path()
              ..moveTo(x, 8.5)
              ..quadraticBezierTo(x + 1.6, 6.6, x, 4.5)
              ..quadraticBezierTo(x - 1.6, 6.6, x, 8.5),
            stroke,
          );
        }

      case LineIconShape.waypoint:
        canvas.drawCircle(const Offset(12, 12), 6.5, stroke);
        canvas.drawCircle(const Offset(12, 12), 1.6, fill);

      case LineIconShape.home:
        // Roof, walls, and a door standing open — the house you are about
        // to leave, not the one you live in.
        canvas.drawPath(
          Path()
            ..moveTo(3, 11.5)
            ..lineTo(12, 4)
            ..lineTo(21, 11.5),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(5.5, 10)
            ..lineTo(5.5, 20)
            ..lineTo(18.5, 20)
            ..lineTo(18.5, 10),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(9.8, 20)
            ..lineTo(9.8, 14.2)
            ..lineTo(14.2, 14.2)
            ..lineTo(14.2, 20),
          stroke,
        );

      case LineIconShape.flask:
        canvas.drawPath(
          Path()
            ..moveTo(9.5, 3)
            ..lineTo(14.5, 3)
            ..moveTo(10.2, 3)
            ..lineTo(10.2, 7.2)
            ..lineTo(7.2, 10.4)
            ..arcToPoint(
              const Offset(6.2, 13.4),
              radius: const Radius.circular(3),
            )
            ..lineTo(6.2, 18)
            ..arcToPoint(const Offset(9, 21), radius: const Radius.circular(3))
            ..lineTo(15, 21)
            ..arcToPoint(
              const Offset(17.8, 18),
              radius: const Radius.circular(3),
            )
            ..lineTo(17.8, 13.4)
            ..arcToPoint(
              const Offset(16.8, 10.4),
              radius: const Radius.circular(3),
            )
            ..lineTo(13.8, 7.2)
            ..lineTo(13.8, 3),
          stroke,
        );
        canvas.drawLine(
          const Offset(6.4, 14.6),
          const Offset(17.6, 14.6),
          stroke,
        );

      case LineIconShape.die:
        // The same five-pip face the launcher icon is struck with.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.5, 3.5, 17, 17),
            const Radius.circular(4),
          ),
          stroke,
        );
        for (final pip in const [
          Offset(8.2, 8.2),
          Offset(15.8, 8.2),
          Offset(12, 12),
          Offset(8.2, 15.8),
          Offset(15.8, 15.8),
        ]) {
          canvas.drawCircle(pip, 1.35, fill);
        }

      case LineIconShape.trash:
        canvas.drawLine(const Offset(4, 7), const Offset(20, 7), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(9.5, 7)
            ..lineTo(9.5, 4.8)
            ..lineTo(14.5, 4.8)
            ..lineTo(14.5, 7),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(6.5, 7)
            ..lineTo(7.4, 19.4)
            ..arcToPoint(
              const Offset(10.4, 21.2),
              radius: const Radius.circular(2),
            )
            ..lineTo(13.6, 21.2)
            ..arcToPoint(
              const Offset(16.6, 19.4),
              radius: const Radius.circular(2),
            )
            ..lineTo(17.5, 7),
          stroke,
        );
        canvas.drawLine(
          const Offset(10.5, 10.6),
          const Offset(10.8, 17.6),
          stroke,
        );
        canvas.drawLine(
          const Offset(13.5, 10.6),
          const Offset(13.2, 17.6),
          stroke,
        );

      case LineIconShape.warning:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3.6)
            ..lineTo(22, 20.4)
            ..lineTo(2, 20.4)
            ..close(),
          stroke,
        );
        canvas.drawLine(const Offset(12, 10), const Offset(12, 15.2), stroke);
        canvas.drawCircle(const Offset(12, 17.8), 0.9, fill);

      case LineIconShape.chevronLeft:
        canvas.drawPath(
          Path()
            ..moveTo(15, 4.5)
            ..lineTo(8, 12)
            ..lineTo(15, 19.5),
          stroke,
        );

      case LineIconShape.trophy:
        canvas.drawPath(
          Path()
            ..moveTo(7.5, 3.6)
            ..lineTo(16.5, 3.6)
            ..lineTo(16.5, 9.4)
            ..arcToPoint(
              const Offset(7.5, 9.4),
              radius: const Radius.circular(4.5),
            )
            ..close(),
          stroke,
        );
        // The two handles the cup is held by.
        canvas.drawPath(
          Path()
            ..moveTo(7.5, 5)
            ..lineTo(4.4, 5)
            ..lineTo(4.4, 7.4)
            ..arcToPoint(
              const Offset(7.5, 10.2),
              radius: const Radius.circular(3),
            ),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(16.5, 5)
            ..lineTo(19.6, 5)
            ..lineTo(19.6, 7.4)
            ..arcToPoint(
              const Offset(16.5, 10.2),
              radius: const Radius.circular(3),
              clockwise: false,
            ),
          stroke,
        );
        canvas.drawLine(const Offset(12, 13), const Offset(12, 17), stroke);
        canvas.drawLine(const Offset(8, 20.4), const Offset(16, 20.4), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(9, 20.4)
            ..lineTo(10, 17)
            ..lineTo(14, 17)
            ..lineTo(15, 20.4),
          stroke,
        );

      case LineIconShape.starBurst:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3.4)
            ..lineTo(14.4, 9)
            ..lineTo(20.4, 9.6)
            ..lineTo(15.9, 13.6)
            ..lineTo(17.2, 19.5)
            ..lineTo(12, 16.4)
            ..lineTo(6.8, 19.5)
            ..lineTo(8.1, 13.6)
            ..lineTo(3.6, 9.6)
            ..lineTo(9.6, 9)
            ..close(),
          stroke,
        );

      case LineIconShape.lockedChest:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.4, 9.4, 17.2, 11.2),
            const Radius.circular(2.4),
          ),
          stroke,
        );
        // The shackle of the padlock, standing above the lid.
        canvas.drawPath(
          Path()
            ..moveTo(8.2, 9.4)
            ..lineTo(8.2, 6.6)
            ..arcToPoint(
              const Offset(15.8, 6.6),
              radius: const Radius.circular(3.8),
            )
            ..lineTo(15.8, 9.4),
          stroke,
        );
        canvas.drawLine(const Offset(12, 13.4), const Offset(12, 16.6), stroke);

      case LineIconShape.mask:
        canvas.drawPath(
          Path()
            ..moveTo(4.6, 6.6)
            ..lineTo(19.4, 6.6)
            ..lineTo(19.4, 12.6)
            ..arcToPoint(
              const Offset(12, 20.6),
              radius: const Radius.circular(8),
            )
            ..arcToPoint(
              const Offset(4.6, 12.6),
              radius: const Radius.circular(8),
            )
            ..close(),
          stroke,
        );
        canvas.drawCircle(const Offset(9, 12), 1.3, fill);
        canvas.drawCircle(const Offset(15, 12), 1.3, fill);

      case LineIconShape.backpack:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4.6, 7.6, 14.8, 13),
            const Radius.circular(4),
          ),
          stroke,
        );
        // The carry loop over the top.
        canvas.drawPath(
          Path()
            ..moveTo(9, 7.6)
            ..lineTo(9, 6)
            ..arcToPoint(const Offset(15, 6), radius: const Radius.circular(3))
            ..lineTo(15, 7.6),
          stroke,
        );
        canvas.drawLine(const Offset(4.6, 14), const Offset(19.4, 14), stroke);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(10.2, 15.8, 3.6, 3),
            const Radius.circular(1),
          ),
          stroke,
        );

      case LineIconShape.heart:
        canvas.drawPath(
          Path()
            ..moveTo(12, 20.4)
            ..lineTo(4.9, 13.4)
            ..arcToPoint(
              const Offset(12, 6.6),
              radius: const Radius.circular(5),
            )
            ..arcToPoint(
              const Offset(19.1, 13.4),
              radius: const Radius.circular(5),
            )
            ..close(),
          stroke,
        );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LineIconPainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
