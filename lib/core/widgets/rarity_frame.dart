import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';
import '../theme/app_colors.dart';

/// Wraps [child] in a border/glow whose weight scales with [rarity] — the
/// single visual language used everywhere something's rarity should be felt
/// (item chips, origin badges, event dialogs). [AppColors.glowFor] is the
/// single source of truth for the five-tier ramp (common near-bare through
/// legendary's pulse); this widget just renders whatever spec it returns.
///
/// [color] overrides the tier's default hue while keeping its glow *shape*
/// — used where a dialog's accent needs to stay type-colored (a curse stays
/// reddish) but should still visually communicate its card's rarity tier.
/// [backgroundAlpha] optionally tints the fill too (0 = no fill, the
/// default — most callers just want a border/glow around existing content).
///
/// The pulse is a looping implicit animation (a [TweenAnimationBuilder]
/// that flips its target on `onEnd`), not an [AnimationController] — kept
/// this way deliberately so the whole UI pass stays on Flutter SDK
/// primitives with no manual ticker/vsync plumbing.
class RarityFrame extends StatefulWidget {
  final Rarity rarity;
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double backgroundAlpha;

  const RarityFrame({
    super.key,
    required this.rarity,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding = EdgeInsets.zero,
    this.color,
    this.backgroundAlpha = 0,
  });

  @override
  State<RarityFrame> createState() => _RarityFrameState();
}

class _RarityFrameState extends State<RarityFrame> {
  bool _glowUp = true;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.rarityColor(widget.rarity);
    final glow = AppColors.glowFor(widget.rarity);

    if (!glow.pulse) return _frame(color, glow, glow.shadowAlpha);

    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: _glowUp ? glow.shadowAlpha * 0.45 : glow.shadowAlpha,
        end: _glowUp ? glow.shadowAlpha : glow.shadowAlpha * 0.45,
      ),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeInOut,
      onEnd: () => setState(() => _glowUp = !_glowUp),
      builder: (context, shadowAlpha, child) => _frame(color, glow, shadowAlpha),
      child: widget.child,
    );
  }

  Widget _frame(Color color, RarityGlow glow, double shadowAlpha) {
    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        color: widget.backgroundAlpha == 0
            ? null
            : color.withValues(alpha: widget.backgroundAlpha),
        border: Border.all(
          color: color.withValues(alpha: glow.borderAlpha),
          width: 1.4,
        ),
        boxShadow: glow.blurRadius == 0
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: shadowAlpha),
                  blurRadius: glow.blurRadius,
                  spreadRadius: 0.5,
                ),
              ],
      ),
      child: widget.child,
    );
  }
}
