import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/steel_palette.dart';
import '../../../../core/widgets/app_dialog_shell.dart';

/// The moment a gamble is settled, made visible.
///
/// A `chanceCheck` used to resolve in the same silent instant as everything
/// else: the player picked "рискнуть по-крупному" and the dialog closed, with
/// a result plate — or nothing at all — as the only evidence that a coin had
/// been flipped on their behalf. The throw is the most interesting thing
/// that happens on those cards and it was the one thing nobody saw.
///
/// A coin, flipping end over end. The die is still the game's mark for
/// chance in the abstract — the launcher icon, the "Сделать шаг" button —
/// but this screen is not about chance in the abstract: it is one wager with
/// two sides, called or not, and a coin is the object that has exactly two
/// sides. A six-sided die landing on "6 = you won" was always a translation.
///
/// The face is honest: [passed] is the throw the engine will apply, decided
/// before the animation starts, so what lands here is what happens next
/// rather than a decorative spin followed by an unrelated verdict.
///
/// The button lives inside the content rather than in the shell's `actions`
/// because it must not exist until the coin has settled: a dialog you can
/// dismiss before it has told you anything is just a delay.
///
/// [called] and [other] name the two sides of a wager, when the player was
/// given one to call. They change nothing about the throw, but they let the
/// settled screen say what was bet and what came up — the whole difference
/// between "не повезло" and "не повезло, ты ставил на красную".
///
/// [challenger] and [opponent] name the two players of a duel, and are
/// absent for a solo risk. See [_Verdict] for why a duel cannot be reported
/// in the second person.
Future<void> showChanceCheckDialog({
  required BuildContext context,
  required bool passed,
  String? called,
  String? other,
  String? challenger,
  String? opponent,
}) {
  return showAppDialog<void>(
    context: context,
    icon: Icons.toll_outlined,
    title: 'Бросок',
    barrierDismissible: false,
    content: _RollBody(
      passed: passed,
      called: called,
      other: other,
      challenger: challenger,
      opponent: opponent,
    ),
    actions: const [],
  );
}

class _RollBody extends StatefulWidget {
  final bool passed;
  final String? called;
  final String? other;
  final String? challenger;
  final String? opponent;

  const _RollBody({
    required this.passed,
    this.called,
    this.other,
    this.challenger,
    this.opponent,
  });

  @override
  State<_RollBody> createState() => _RollBodyState();
}

class _RollBodyState extends State<_RollBody>
    with SingleTickerProviderStateMixin {
  static const _spin = Duration(milliseconds: 1150);

  /// Whole half-turns before it lands. Even, so the coin finishes showing
  /// the same face it started on, which lets the starting face be chosen
  /// from the outcome instead of the turn count having to be tuned per
  /// result.
  static const _halfTurns = 8;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _spin,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

        // The flip itself: the coin's width collapses to nothing and opens
        // out again, once per half-turn. `cos` gives that for free, and its
        // sign says which face is pointing at the table.
        final turn = t * math.pi * _halfTurns;
        final squash = math.cos(turn);
        final showingBack = squash < 0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 132,
              child: Center(
                child: Transform.translate(
                  // Tossed and caught: up through the first half of the
                  // flight, back down onto the table.
                  offset: Offset(0, -26 * math.sin(t * math.pi)),
                  child: Transform(
                    alignment: Alignment.center,
                    // A hair of perspective so the collapse reads as a coin
                    // turning rather than a disc being squeezed.
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0015)
                      ..scaleByDouble(
                        1.0,
                        squash.abs().clamp(0.06, 1.0),
                        1.0,
                        1.0,
                      ),
                    child: _Coin(
                      // The spin ends on an even half-turn, so at rest this
                      // is exactly `passed` — which is the point: the coin
                      // is started on whichever side it has to finish on.
                      face: showingBack != widget.passed,
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
            // nothing below it moves when the words arrive.
            _Verdict(
              settled: settled,
              passed: widget.passed,
              challenger: widget.challenger,
              opponent: widget.opponent,
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
            // button's height at the exact moment the eye is on the coin.
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

/// Who won, in the words that fit who was playing.
///
/// A solo risk is addressed to the player who took it — "Повезло" is exactly
/// right when there is nobody else in the sentence. A duel is not: two named
/// players are in it, the loser's penalty may land on the *other* one, and
/// "не повезло" leaves the table guessing which of them is being talked
/// about. So a duel says both names and which way it went, before a single
/// effect is applied.
class _Verdict extends StatelessWidget {
  final bool settled;
  final bool passed;
  final String? challenger;
  final String? opponent;

  const _Verdict({
    required this.settled,
    required this.passed,
    this.challenger,
    this.opponent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final challenger = this.challenger;
    final opponent = this.opponent;
    final isDuel = challenger != null && opponent != null;

    final headline = isDuel
        ? (passed ? challenger : opponent)
        : (passed ? 'Повезло' : 'Не повезло');

    return SizedBox(
      height: isDuel ? 62 : 34,
      child: settled
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              builder: (context, value, child) =>
                  Opacity(opacity: value, child: child),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDuel)
                    Text(
                      '$challenger и $opponent',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: SteelPalette.textLow.withValues(alpha: 0.72),
                      ),
                    ),
                  Text(
                    // "Победа: X" rather than "выиграл X" or "X против Y":
                    // player names are typed by the table and arrive in no
                    // known gender or case. A verb would have to agree with
                    // them and "против" would have to decline them, and both
                    // get it wrong half the time. A label and a name in the
                    // nominative are right for every name anyone types.
                    isDuel ? 'Победа: $headline' : headline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: SteelPalette.textHigh,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class _Coin extends StatelessWidget {
  /// True is the face that is up when the throw came off — see
  /// `_RollBodyState.build`. Which of the two that is carries no meaning of
  /// its own; it only has to be the same one every time.
  final bool face;
  final Color color;

  const _Coin({required this.face, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 84,
      child: CustomPaint(
        painter: _CoinPainter(face: face, color: color),
      ),
    );
  }
}

/// Two faces struck on the same blank, on the same 24-unit grid every drawn
/// mark in this app uses.
///
/// They differ enough to be told apart at a glance mid-spin — a filled
/// centre against a hollow ring — without either one meaning "good" or
/// "bad". The coin is not the verdict; the words under it are.
class _CoinPainter extends CustomPainter {
  final bool face;
  final Color color;

  const _CoinPainter({required this.face, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 24;
    canvas.save();
    canvas.scale(unit);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / unit
      ..strokeCap = StrokeCap.round;
    final hairline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9 / unit
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const centre = Offset(12, 12);
    canvas.drawCircle(centre, 10, stroke);
    canvas.drawCircle(centre, 7.6, hairline);

    if (face) {
      // Reverse: a hollow ring inside the rim, with four small notches at
      // the quarters — a milled edge seen face-on.
      canvas.drawCircle(centre, 3.4, stroke);
      for (var i = 0; i < 4; i++) {
        final angle = math.pi / 4 + i * math.pi / 2;
        canvas.drawLine(
          centre + Offset(math.cos(angle), math.sin(angle)) * 5.2,
          centre + Offset(math.cos(angle), math.sin(angle)) * 6.6,
          stroke,
        );
      }
    } else {
      // Obverse: a struck boss with rays, the side a mint puts a head on.
      canvas.drawCircle(centre, 2.6, fill);
      for (var i = 0; i < 6; i++) {
        final angle = i * math.pi / 3;
        canvas.drawLine(
          centre + Offset(math.cos(angle), math.sin(angle)) * 4.3,
          centre + Offset(math.cos(angle), math.sin(angle)) * 6.3,
          stroke,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoinPainter oldDelegate) =>
      oldDelegate.face != face || oldDelegate.color != color;
}
