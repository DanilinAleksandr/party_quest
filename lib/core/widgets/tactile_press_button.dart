import 'package:flutter/material.dart';

/// A control that answers a tap by *being pressed* — it sinks away from the
/// light over the first half of [duration], comes back over the second, and
/// only then runs [onPressed].
///
/// Extracted from the main menu so the game screen's "Сделать шаг" and the
/// menu entries share one implementation. The split is deliberate: this
/// widget owns the timing, the curve and the re-entrancy guard, while
/// [builder] owns what "pressed" *looks like* — the menu dims a word and its
/// lozenges, the step button dims a whole plate. Both get the scale for
/// free, because the motion is the part that must not drift between them.
///
/// There is no ink splash anywhere in here. A rectangular highlight is a
/// statement about a plate's bounds, and half the things using this widget
/// have no plate.
class TactilePressButton extends StatefulWidget {
  /// Half of this going down, half coming back.
  final Duration duration;

  /// How far in the surface travels: 0.06 means it bottoms out at 94%.
  final double scaleDepth;

  /// Asks an owner further up whether a press may start — used where more
  /// than one of these sits on screen and only one may fire (the two menu
  /// entries). Returning false swallows the tap. Omit it when the widget's
  /// own "already animating" check is the whole story.
  final bool Function()? beginPress;

  /// Runs when the press has finished playing, not when the finger lands.
  /// Null disables the control: no animation, no callback.
  final VoidCallback? onPressed;

  /// Receives the press depth — 0 at rest, 1 at the bottom — so colour,
  /// glow and opacity can follow the movement.
  final Widget Function(BuildContext context, double press) builder;

  const TactilePressButton({
    super.key,
    required this.builder,
    required this.onPressed,
    this.beginPress,
    this.duration = const Duration(milliseconds: 750),
    this.scaleDepth = 0.06,
  });

  @override
  State<TactilePressButton> createState() => _TactilePressButtonState();
}

class _TactilePressButtonState extends State<TactilePressButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addStatusListener(_onStatusChanged);

  /// 0 at rest, 1 at the bottom of the press. `easeIn` going down and
  /// `easeOut` coming back is what gives it weight: the surface gathers
  /// speed as it is pushed in, then eases up to rest instead of snapping.
  late final Animation<double> _press = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 1,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(covariant TactilePressButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      widget.onPressed?.call();
    }
  }

  void _handleTap() {
    if (widget.onPressed == null || _controller.isAnimating) return;
    if (widget.beginPress != null && !widget.beginPress!()) return;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      // A bare GestureDetector announces nothing; without this the control
      // is invisible to a screen reader.
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, _) => Transform.scale(
            scale: 1 - widget.scaleDepth * _press.value,
            child: widget.builder(context, _press.value),
          ),
        ),
      ),
    );
  }
}
