import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';
import '../theme/app_colors.dart';
import '../theme/steel_palette.dart';
import 'rarity_frame.dart';

/// A player's origin, or the state before it surfaces. [origin] null means
/// `Player.originId` hasn't been revealed yet.
///
/// That state is drawn as a dashed outline with no icon and no fill —
/// something sketched in rather than something missing. The wording is
/// "Происхождение забыто", not "Неизвестный": the character *has* an
/// origin from the first step of the journey, the table simply has not
/// remembered it yet. "Unknown" would describe a blank; "forgotten"
/// describes a person.
///
/// Once revealed, the badge picks up its rarity colour through
/// [RarityFrame] and a small filled lozenge ahead of the name — the same
/// mark the main menu uses, tinted here by how rare the origin is.
class OriginBadge extends StatelessWidget {
  final Origin? origin;

  const OriginBadge({super.key, required this.origin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final origin = this.origin;

    if (origin == null) {
      final muted = SteelPalette.textLow.withValues(alpha: 0.5);
      return CustomPaint(
        painter: _DashedBorderPainter(color: muted),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'Происхождение забыто',
            style: theme.textTheme.labelMedium?.copyWith(
              color: muted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return RarityFrame(
      rarity: origin.rarity,
      borderRadius: BorderRadius.circular(20),
      backgroundAlpha: 0.16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: math.pi / 4,
            child: SizedBox.square(
              dimension: 4,
              child: ColoredBox(color: AppColors.rarityColor(origin.rarity)),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              origin.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `Border` has no dashed style, so the outline is walked by hand: take the
/// rounded-rect path, then extract short pieces of it at a fixed stride.
class _DashedBorderPainter extends CustomPainter {
  final Color color;

  static const double _dash = 3.5;
  static const double _gap = 3;
  static const double _radius = 20;

  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(_radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            math.min(distance + _dash, metric.length),
          ),
          paint,
        );
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
