import 'package:flutter/material.dart';

/// A generic entrance animation: fades and scales [child] in once, on
/// first build. Reused for dialogs, toasts, and staggered reveals (pass a
/// [delay] to stagger a list of these) — the one animation primitive most
/// of this UI pass's motion is built from.
class FadeScaleIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double startScale;

  const FadeScaleIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 320),
    this.delay = Duration.zero,
    this.startScale = 0.92,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Curves.easeOutCubic,
      builder: (context, rawT, child) {
        final delayFraction = duration.inMilliseconds == 0
            ? 0.0
            : delay.inMilliseconds / (duration + delay).inMilliseconds;
        final t = ((rawT - delayFraction) / (1 - delayFraction)).clamp(0, 1);
        return Opacity(
          opacity: t.toDouble(),
          child: Transform.scale(
            scale: startScale + (1 - startScale) * t,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
