import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/steel_palette.dart';
import '../../../../core/widgets/app_dialog_shell.dart';
import '../../../../core/widgets/line_icons.dart';

/// The moment a gamble is settled, made visible.
///
/// A `chanceCheck` used to resolve in the same silent instant as everything
/// else: the player picked "рискнуть по-крупному" and the dialog closed, with
/// a result plate — or nothing at all — as the only evidence that a coin had
/// been flipped on their behalf. The roll is the most interesting thing that
/// happens on those cards and it was the one thing nobody saw.
///
/// A die rather than a coin, because the die is already the game's symbol for
/// chance: the launcher icon, the "Сделать шаг" button and this all show the
/// same object. And the face is honest — [passed] is the roll the engine will
/// apply, decided before the animation starts, so what lands here is what
/// happens next rather than a decorative tumble followed by an unrelated
/// verdict.
///
/// The button lives inside the content rather than in the shell's `actions`
/// because it must not exist until the die has settled: a dialog you can
/// dismiss before it has told you anything is just a delay.
///
/// [called] and [other] name the two sides of a wager, when the player was
/// given one to call. They change nothing about the throw — the die is the
/// die — but they let the settled screen say what was bet and what came up,
/// which is the whole difference between "не повезло" and "не повезло, ты
/// ставил на красную".
Future<void> showChanceCheckDialog({
  required BuildContext context,
  required bool passed,
  String? called,
  String? other,
}) {
  return showAppDialog<void>(
    context: context,
    icon: Icons.casino_outlined,
    title: 'Бросок',
    barrierDismissible: false,
    content: _RollBody(passed: passed, called: called, other: other),
    actions: const [],
  );
}

class _RollBody extends StatefulWidget {
  final bool passed;
  final String? called;
  final String? other;

  const _RollBody({required this.passed, this.called, this.other});

  @override
  State<_RollBody> createState() => _RollBodyState();
}

class _RollBodyState extends State<_RollBody>
    with SingleTickerProviderStateMixin {
  static const _tumble = Duration(milliseconds: 1150);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _tumble,
  )..forward();

  /// The faces flicker past on their own clock rather than off the curve, so
  /// the die keeps changing at a readable rate while it visibly slows down.
  static const _facesPerSecond = 11;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// High is good: a passed check lands on five or six, a failed one on one
  /// or two. Three and four never come up as a final face — a middling
  /// result would read as "and?" at a table that has just been told to look
  /// at the die.
  int get _finalPips => widget.passed ? 6 : 1;

  /// The side that came up is the one that was called if the throw came off,
  /// and the other one if it did not — which is exactly what winning a
  /// called bet means, and keeps this line from ever contradicting the
  /// verdict above it.
  String? get _call {
    final called = widget.called;
    final other = widget.other;
    if (called == null || other == null) return null;
    return widget.passed
        ? 'Ставка: $called — она и выпала'
        : 'Ставка: $called — выпала $other';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        final settled = _controller.isCompleted;
        final pips = settled
            ? _finalPips
            : 1 + ((t * _tumble.inMilliseconds * _facesPerSecond) ~/ 1000) % 6;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 132,
              child: Center(
                child: Transform.rotate(
                  // Two and a bit turns, easing to a stop — and a last
                  // fraction of a turn left over so the settled die sits
                  // very slightly off square, like a thrown object.
                  angle: t * math.pi * 4.6,
                  child: Transform.scale(
                    // Thrown up and caught: it grows through the first half
                    // of the tumble and comes back down onto the table.
                    scale: 0.85 + 0.35 * math.sin(t * math.pi),
                    child: _Die(
                      pips: pips,
                      color: settled
                          ? SteelPalette.textHigh
                          : SteelPalette.steel,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // The verdict is built only once it is true, rather than faded
            // in from a hidden widget: a "Повезло" sitting at zero opacity
            // is still there to be read out by a screen reader, and still
            // there to be found by a test that means to check the table
            // cannot see it yet. The slot keeps its height either way so
            // nothing below it moves when the word arrives.
            SizedBox(
              height: 34,
              child: settled
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 220),
                      builder: (context, value, child) =>
                          Opacity(opacity: value, child: child),
                      child: Text(
                        widget.passed ? 'Повезло' : 'Не повезло',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: SteelPalette.textHigh,
                          letterSpacing: 0.6,
                        ),
                      ),
                    )
                  : null,
            ),
            // What was called against what came up, for a wager that had a
            // side to call. It sits under the verdict rather than replacing
            // it: the verdict is the news, this is the receipt.
            if (_call != null)
              SizedBox(
                height: 26,
                child: settled
                    ? Text(
                        _call!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: SteelPalette.textLow.withValues(alpha: 0.72),
                        ),
                      )
                    : null,
              ),
            const SizedBox(height: 18),
            // Reserved rather than inserted, so the dialog does not jump a
            // button's height at the exact moment the eye is on the die.
            SizedBox(
              width: double.infinity,
              child: settled
                  ? FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Дальше'),
                    )
                  : const SizedBox(height: 52),
            ),
          ],
        );
      },
    );
  }
}

class _Die extends StatelessWidget {
  final int pips;
  final Color color;

  const _Die({required this.pips, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 84,
      child: CustomPaint(
        painter: _DiePainter(pips: pips, color: color),
      ),
    );
  }
}

class _DiePainter extends CustomPainter {
  final int pips;
  final Color color;

  const _DiePainter({required this.pips, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Same 24-unit grid and same stroke discipline as `LineIcon`, since it
    // is the same die.
    final unit = size.shortestSide / 24;
    canvas.save();
    canvas.scale(unit);
    paintDieFace(
      canvas,
      pips: pips,
      stroke: Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / unit
        ..strokeJoin = StrokeJoin.round,
      fill: Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DiePainter oldDelegate) =>
      oldDelegate.pips != pips || oldDelegate.color != color;
}
