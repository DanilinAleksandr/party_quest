import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
/// [sides] and [calledIndex] are the wager's two faces and the one the
/// player called, when the scene offered a call. They change nothing about
/// the throw, but they decide which face the coin comes to rest on and let
/// the settled screen say what was bet against what came up — the whole
/// difference between "платишь" and "платишь, а ставил ты на Короля".
///
/// [challenger] and [opponent] name the two players of a duel, and are
/// absent for a solo risk. See [_Verdict] for why a duel cannot be reported
/// in the second person, and why it names the one who pays.
Future<void> showChanceCheckDialog({
  required BuildContext context,
  required bool passed,
  List<String>? sides,
  int? calledIndex,
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
      sides: sides,
      calledIndex: calledIndex,
      challenger: challenger,
      opponent: opponent,
    ),
    actions: const [],
  );
}

class _RollBody extends StatefulWidget {
  final bool passed;
  final List<String>? sides;
  final int? calledIndex;
  final String? challenger;
  final String? opponent;

  const _RollBody({
    required this.passed,
    this.sides,
    this.calledIndex,
    this.challenger,
    this.opponent,
  });

  @override
  State<_RollBody> createState() => _RollBodyState();
}

class _RollBodyState extends State<_RollBody>
    with SingleTickerProviderStateMixin {
  static const _throw = Duration(milliseconds: 2000);

  /// Whole half-turns before it lands. Even, so the coin finishes showing
  /// the same face it started on, which lets the starting face be chosen
  /// from the outcome instead of the turn count having to be tuned per
  /// result. The simulation below is built to travel exactly this far.
  static const _halfTurns = 8;

  /// How long the coin is off the table, and how high it gets, in seconds
  /// and logical pixels. Everything else about the arc follows from these
  /// two: a toss that peaks at [_peak] and lands after [_flight] needs
  /// `g = 8·peak/flight²` and a launch speed of `g·flight/2`.
  static const _flight = 1.35;
  static const _peak = 34.0;
  static const _gravity = 8 * _peak / (_flight * _flight);

  /// The hop it makes on landing, as a fraction of the launch speed. Real
  /// enough to see it settle rather than stick, small enough not to read as
  /// a second toss.
  static const _rebound = 0.34;

  /// Both arcs measure downward from the table, which is where
  /// [GravitySimulation] puts its origin: the coin starts at 0 moving up,
  /// gravity brings it back.
  static final _toss = GravitySimulation(
    _gravity,
    0,
    0,
    -_gravity * _flight / 2,
  );
  static final _hop = GravitySimulation(
    _gravity,
    0,
    0,
    -_gravity * _flight / 2 * _rebound,
  );

  /// Angular speed with drag on it, rather than a curve pretending to be
  /// one. A [FrictionSimulation] loses a fixed fraction of its speed per
  /// second, so the total distance it will ever cover is `-v/ln(drag)` —
  /// run that backwards to launch it at exactly the speed that spends
  /// [_halfTurns] and no more.
  static const _drag = 0.1;
  static final _spin = FrictionSimulation(
    _drag,
    0,
    -_halfTurns * math.log(_drag),
  );

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _throw,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Height above the table at [seconds]: the toss, then the hop, then
  /// still.
  double _height(double seconds) {
    if (seconds < _flight) return -_toss.x(seconds);
    final since = seconds - _flight;
    if (since < _flight * _rebound) return -_hop.x(since);
    return 0;
  }

  /// Which face the coin is showing once it stops.
  ///
  /// With a call, it is the side that was called if the throw came off and
  /// the other one if it did not — which is exactly what winning a called
  /// bet means, and is what keeps the coin from contradicting the line
  /// underneath it.
  ///
  /// With no call there is no side to be right about, so the coin falls back
  /// to the plain reading of its two faces: the King when the attempt held,
  /// the Jester when it did not.
  bool get _restingFace {
    final called = widget.calledIndex;
    if (called == null) return !widget.passed;
    return widget.passed ? called == 1 : called == 0;
  }

  String? get _call {
    final sides = widget.sides;
    final called = widget.calledIndex;
    if (sides == null || called == null || sides.length != 2) return null;
    // Two labelled fields rather than a sentence, for the same reason the
    // duel says "Платит: X": the sides are named by content and carry their
    // own gender, so "она и выпала" is wrong the moment the side is a Шут.
    // A label and a name agree with everything.
    final up = widget.passed ? sides[called] : sides[1 - called];
    return 'Ставка: ${sides[called]}  ·  Выпало: $up';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // The controller is only a clock here — the motion comes from the
        // two simulations, read at the elapsed time in seconds.
        final seconds = _controller.value * _throw.inMilliseconds / 1000;
        final settled = _controller.isCompleted;

        // The flip itself: the coin's width collapses to nothing and opens
        // out again, once per half-turn. `cos` of the spin's position gives
        // that for free, and its sign says which face is pointing at the
        // table. Friction leaves the last fraction of a degree unspent, so
        // the settled frame is squared up by hand rather than left to land
        // on exactly even by luck.
        final squash = settled ? 1.0 : math.cos(math.pi * _spin.x(seconds));
        final showingBack = squash < 0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 132,
              child: Center(
                child: Transform.translate(
                  // Thrown, not eased: a parabola under gravity, and a small
                  // second one when it lands.
                  offset: Offset(0, -_height(seconds)),
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
                      // is exactly `_restingFace` — which is the point: the
                      // coin is started on whichever side it must finish on.
                      face: showingBack != _restingFace,
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
            // in from a hidden widget: a "Платишь" sitting at zero opacity
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

/// Who pays, in the words that fit who was playing.
///
/// Names the *loser*, not the winner. This is a drinking game: the winner
/// gets to carry on as they were, and the only person who has to do
/// something about the result is the one who lost. The screen that tells
/// the table what just happened should say who owes, the same way the
/// outcome text does.
///
/// A duel names them, because two named players are in it, the penalty may
/// land on the *other* one, and an impersonal line leaves the table guessing
/// which. A solo risk stays in the second person — there is nobody else in
/// the sentence — and says what it costs rather than what it won.
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

    // `passed` is "the challenger's throw came off", so the one who pays is
    // whichever of the two it was not.
    final headline = isDuel
        ? (passed ? opponent : challenger)
        : (passed ? 'Обошлось' : 'Платишь');

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
                    // "Платит: X" rather than "платит X" or "X проиграл":
                    // player names are typed by the table and arrive in no
                    // known gender or case, so a past-tense verb would have
                    // to agree with them and get it wrong half the time. A
                    // label and a name in the nominative are right for every
                    // name anyone types — the same rule the outcome text and
                    // the wager receipt follow.
                    //
                    // The solo lines are already gender-free for the same
                    // reason: "Платишь" is second person, "Обошлось" is
                    // impersonal, and neither has to know who is playing.
                    isDuel ? 'Платит: $headline' : headline,
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

/// The lot-casting coin, struck with a King on one side and a Jester on the
/// other.
///
/// Not a generic heads/tails: the two faces are a proposition about the
/// world. The King is order and control, the Jester is chance and mischief,
/// and calling a side is calling which of them holds this time. It is an
/// object anybody on the road carries — a tavern keeper, a pedlar — not an
/// inventory item anybody has to find first.
///
/// The marks come from the same game-icons.net library the 35 origins use,
/// tinted the same way, and neither collides with a shape an origin already
/// owns: a chess king is not the crown of the Наследник древних королей, and
/// a jester's hat is not the pointed hat of the Наследник ведьм.
class _Coin extends StatelessWidget {
  /// True is the Jester's side, false the King's — the two entries of a
  /// card's `sides` in order.
  final bool face;
  final Color color;

  const _Coin({required this.face, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The blank the mark is struck on, drawn rather than imported so
          // the rim keeps the same hairline weight as the rest of the
          // chrome at every size.
          CustomPaint(
            size: const Size.square(84),
            painter: _BlankPainter(color),
          ),
          SvgPicture.asset(
            face
                ? 'assets/icons/coin/coin_jester.svg'
                : 'assets/icons/coin/coin_king.svg',
            width: 40,
            height: 40,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ],
      ),
    );
  }
}

/// The rim and the inner ring, on the same 24-unit grid every drawn mark in
/// this app uses.
class _BlankPainter extends CustomPainter {
  final Color color;

  const _BlankPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 24;
    canvas.save();
    canvas.scale(unit);

    const centre = Offset(12, 12);
    canvas.drawCircle(
      centre,
      11,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / unit,
    );
    canvas.drawCircle(
      centre,
      9.4,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9 / unit,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BlankPainter oldDelegate) =>
      oldDelegate.color != color;
}
