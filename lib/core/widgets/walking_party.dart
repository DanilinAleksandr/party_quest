import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/steel_palette.dart';
import 'line_icons.dart';

/// Two figures walking along a dashed road, drawn in the same hairline as
/// `LineIcon` — the party on its way between cards.
///
/// [walking] runs the loop; turning it off stops the loop *where it is*, a
/// stride caught halfway, rather than snapping the figures back to standing
/// or taking them off the screen. A card that interrupts the walk interrupts
/// it mid-step, and the walk picks up from that same frame once the card is
/// dealt with.
class WalkingParty extends StatefulWidget {
  final bool walking;

  const WalkingParty({super.key, required this.walking});

  @override
  State<WalkingParty> createState() => _WalkingPartyState();
}

class _WalkingPartyState extends State<WalkingParty>
    with SingleTickerProviderStateMixin {
  // One full stride: each leg forward once.
  late final AnimationController _stride = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.walking) _stride.repeat();
  }

  @override
  void didUpdateWidget(covariant WalkingParty oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.walking == oldWidget.walking) return;
    if (widget.walking) {
      // `repeat` resumes from the current value, so the stride carries on
      // from the frame it was frozen on.
      _stride.repeat();
    } else {
      _stride.stop();
    }
  }

  @override
  void dispose() {
    _stride.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.walking ? 'Компания в пути' : 'Компания остановилась',
      child: SizedBox(
        height: 30,
        width: double.infinity,
        child: RepaintBoundary(
          child: CustomPaint(painter: _WalkingPainter(_stride)),
        ),
      ),
    );
  }
}

/// What stands in [WalkingParty]'s place while the party is stopped at a
/// tavern or a halt: a campfire at the roadside, and the road going on
/// without anybody on it.
///
/// A placeholder, deliberately plain — the camp's real look is its own
/// piece of work, drawn from a mockup.
class PartyCamp extends StatelessWidget {
  const PartyCamp({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Компания на стоянке',
      child: SizedBox(
        height: 30,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _WalkingPainter(
                  const AlwaysStoppedAnimation(0),
                  figures: false,
                ),
              ),
            ),
            // The campfire's logs sit 20.8 units down its 24-unit grid; this
            // puts them on the road line.
            const Positioned(
              left: 14,
              top: 30 - _WalkingPainter._roadInset - 20.8,
              child: LineIcon(
                shape: LineIconShape.campfire,
                size: 24,
                color: SteelPalette.steel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalkingPainter extends CustomPainter {
  final Animation<double> stride;
  final bool figures;

  _WalkingPainter(this.stride, {this.figures = true}) : super(repaint: stride);

  static const _roadInset = 2.5;

  // The road's dash, in logical pixels. The road slides two dashes per
  // stride, so the loop wraps without a jump.
  static const _dash = 5.0;
  static const _period = 9.0;

  // Legs and arms swing this far either side of straight down, in radians.
  static const _swing = 0.42;

  @override
  void paint(Canvas canvas, Size size) {
    final t = stride.value;
    final ground = size.height - _roadInset;

    final road = Paint()
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          SteelPalette.steel.withValues(alpha: 0.5),
          SteelPalette.steel.withValues(alpha: 0),
        ],
      ).createShader(Offset.zero & size);
    // Dart's `%` is never negative, so this slides leftwards through one
    // period; starting a period early keeps the left edge filled.
    final shift = -(t * 2 * _period) % _period;
    for (var x = shift - _period; x < size.width; x += _period) {
      if (x + _dash <= 0) continue;
      canvas.drawLine(
        Offset(math.max(x, 0), ground),
        Offset(math.min(x + _dash, size.width), ground),
        road,
      );
    }

    if (!figures) return;

    // The leader and one a step behind, out of phase so they do not march.
    _figure(canvas, x: 30, ground: ground - 2, t: t, alpha: 1);
    _figure(canvas, x: 13, ground: ground - 2, t: t + 0.3, alpha: 0.6);
  }

  void _figure(
    Canvas canvas, {
    required double x,
    required double ground,
    required double t,
    required double alpha,
  }) {
    final paint = Paint()
      ..color = SteelPalette.steel.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final angle = math.sin(t * 2 * math.pi) * _swing;
    const leg = 8.0;
    // The hip rides as high as the legs reach, so both feet stay on the
    // road and the body dips at full stride — the bob comes for free.
    final hip = Offset(x, ground - leg * math.cos(angle));
    final shoulder = hip.translate(0.6, -8);
    final head = shoulder.translate(0.5, -3.6);

    canvas.drawLine(hip, shoulder, paint);
    canvas.drawCircle(head, 2.3, paint);
    for (final side in const [1.0, -1.0]) {
      final a = angle * side;
      canvas.drawLine(hip, hip + Offset(math.sin(a), math.cos(a)) * leg, paint);
      // Arms swing against the leg on the same side.
      final arm = -a * 0.8;
      canvas.drawLine(
        shoulder.translate(0, 1),
        shoulder.translate(0, 1) + Offset(math.sin(arm), math.cos(arm)) * 6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WalkingPainter oldDelegate) =>
      oldDelegate.stride != stride || oldDelegate.figures != figures;
}
