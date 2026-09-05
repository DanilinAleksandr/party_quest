import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';
import 'origin_badge.dart';

/// Wraps [OriginBadge] with a one-shot "moment of discovery" the instant
/// [origin] flips from null to non-null — a brief bright flash behind the
/// badge as it fades and scales in, so a reveal reads as something that
/// *happened* rather than a label quietly changing. Every other rebuild
/// (origin already known, or still unknown) renders the plain badge with no
/// animation at all — the flash is deliberately a one-time event, not a
/// standing effect.
class OriginRevealFlash extends StatefulWidget {
  final Origin? origin;

  const OriginRevealFlash({super.key, required this.origin});

  @override
  State<OriginRevealFlash> createState() => _OriginRevealFlashState();
}

class _OriginRevealFlashState extends State<OriginRevealFlash> {
  bool _revealing = false;

  @override
  void didUpdateWidget(covariant OriginRevealFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.origin == null && widget.origin != null) {
      setState(() => _revealing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = OriginBadge(origin: widget.origin);
    if (!_revealing) return badge;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      onEnd: () => setState(() => _revealing = false),
      builder: (context, t, child) {
        final clamped = t.clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (clamped < 0.5)
              Opacity(
                opacity: (1 - clamped / 0.5).clamp(0.0, 1.0),
                child: Container(
                  width: 72,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withValues(alpha: 0.85),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.6),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            Opacity(
              opacity: clamped,
              child: Transform.scale(scale: 0.6 + 0.4 * clamped, child: child),
            ),
          ],
        );
      },
      child: badge,
    );
  }
}
