import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

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
/// [edge] is the rare third way down: the coin comes to rest standing on
/// its milled edge, rocks, and stays there. It favours the thrower
/// whatever was called, so [passed] is true with it.
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
  bool edge = false,
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
      passed: passed || edge,
      edge: edge,
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
  final bool edge;
  final List<String>? sides;
  final int? calledIndex;
  final String? challenger;
  final String? opponent;

  const _RollBody({
    required this.passed,
    this.edge = false,
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
  /// result. The simulation below is built to travel exactly this far — or,
  /// for a coin that stands on its edge, half a turn more than that.
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

  /// When the hop is over and the coin is down for good.
  static const _landed = _flight * (1 + _rebound);

  /// A coin on its edge rocks for this long after landing, and then stands
  /// still for [_edgeHold] before the verdict, so the table has time to see
  /// it standing.
  static const _edgeRock = 1.5;
  static const _edgeHold = 1.0;
  static final _edgeThrow = Duration(
    milliseconds: ((_landed + _edgeRock + _edgeHold) * 1000).round(),
  );

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
  static FrictionSimulation _spinFor(double halfTurns) =>
      FrictionSimulation(_drag, 0, -halfTurns * math.log(_drag));
  static final _spin = _spinFor(_halfTurns.toDouble());
  static final _edgeSpin = _spinFor(_halfTurns + 0.5);

  late final Duration _duration = widget.edge ? _edgeThrow : _throw;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
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

  /// How far the coin has turned about its horizontal axis, in radians: 0
  /// is a face square to the table's eye, π/2 the coin standing on edge.
  ///
  /// Friction leaves the last fraction of a degree unspent, so the settled
  /// frame is squared up by hand rather than left to land on exactly even
  /// by luck.
  double _angle(double seconds, {required bool settled}) {
    if (!widget.edge) {
      return settled ? 0 : math.pi * _spin.x(seconds);
    }
    if (settled) return math.pi / 2;
    var angle = math.pi * _edgeSpin.x(seconds);
    // Down on its edge, it rocks from side to side and dies away: two or
    // three swings, each smaller than the last.
    final since = seconds - _landed;
    if (since > 0) {
      final fade = math.exp(-since / 0.42);
      angle += 0.42 * fade * math.sin(2 * math.pi * since / 0.52);
      // What is left of the spin is folded into the rock, so it comes to
      // rest exactly upright rather than a degree off.
      final rest = math.pi * (_halfTurns + 0.5);
      angle = rest + (angle - rest) * math.min(1, fade * 3);
    }
    return angle;
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
    if (widget.edge) return 'Ставка: ${sides[called]}  ·  Выпало: ребро';
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
        final seconds = _controller.value * _duration.inMilliseconds / 1000;
        final settled = _controller.isCompleted;
        final angle = _angle(seconds, settled: settled);
        // Which face is turned towards the table's eye; its sign flips once
        // per half-turn.
        final showingBack = math.cos(angle) < 0;

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
                  child: _SolidCoin(
                    angle: angle,
                    // The spin ends on an even half-turn, so at rest this is
                    // exactly `_restingFace` — which is the point: the coin
                    // is started on whichever side it must finish on.
                    face: showingBack != _restingFace,
                    settled: settled,
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
              edge: widget.edge,
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
///
/// A coin on its edge has nobody to name: it is «Ребро», said as plainly
/// as the thing itself.
class _Verdict extends StatelessWidget {
  final bool settled;
  final bool passed;
  final bool edge;
  final String? challenger;
  final String? opponent;

  const _Verdict({
    required this.settled,
    required this.passed,
    this.edge = false,
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
    final headline = edge
        ? 'Ребро'
        : isDuel
        ? 'Платит: ${passed ? opponent : challenger}'
        : (passed ? 'Обошлось' : 'Платишь');
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: SteelPalette.textLow.withValues(alpha: 0.72),
    );

    return SizedBox(
      height: (isDuel ? 62 : 34) + (edge ? 24 : 0),
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
                      style: muted,
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
                    headline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: SteelPalette.textHigh,
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (edge)
                    Text(
                      'Монета встала на ребро.',
                      textAlign: TextAlign.center,
                      style: muted,
                    ),
                ],
              ),
            )
          : null,
    );
  }
}

/// The coin as a solid: two struck faces and the milled edge between them.
///
/// It turns about its horizontal axis in real perspective. The face turned
/// towards the eye is a widget carried by the same matrix the edge is
/// projected with, so the two meet exactly; the edge is painted underneath
/// it, a band that narrows to nothing when a face looks straight up and is
/// the whole coin when it stands on end.
class _SolidCoin extends StatelessWidget {
  final double angle;

  /// True is the Jester's side, false the King's — the two entries of a
  /// card's `sides` in order.
  final bool face;
  final bool settled;

  const _SolidCoin({
    required this.angle,
    required this.face,
    required this.settled,
  });

  static const double diameter = 84;

  /// About a ninth of the diameter: thick enough to stand on.
  static const double thickness = 9.5;

  /// A little perspective, enough for the near edge to read as nearer.
  static const double _perspective = 0.003;

  static Matrix4 matrixFor(double angle) => Matrix4.identity()
    ..setEntry(3, 2, _perspective)
    ..rotateX(angle);

  @override
  Widget build(BuildContext context) {
    final matrix = matrixFor(angle);
    // The near face sits at whichever end of the coin is closer: the King's
    // end while the King looks up, the other once it has turned over.
    final nearZ = math.cos(angle) >= 0 ? -thickness / 2 : thickness / 2;
    final edgeOn = math.cos(angle).abs() < 0.015;
    return SizedBox.square(
      dimension: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(diameter),
            painter: _EdgePainter(
              angle: angle,
              radius: diameter / 2,
              half: thickness / 2,
              matrix: matrix,
            ),
          ),
          if (!edgeOn)
            Transform(
              alignment: Alignment.center,
              transform: matrix.clone()..translateByDouble(0, 0, nearZ, 1),
              child: _Coin(face: face, settled: settled),
            ),
        ],
      ),
    );
  }
}

/// The milled edge, projected through the coin's own matrix: a strip of
/// quads around the rim, lit from the upper left so a highlight slides
/// along it as the coin turns, and crossed by fine light reeding.
class _EdgePainter extends CustomPainter {
  final double angle;
  final double radius;
  final double half;
  final Matrix4 matrix;

  _EdgePainter({
    required this.angle,
    required this.radius,
    required this.half,
    required this.matrix,
  });

  static const _segments = 72;
  static const _dark = Color(0xFF3F444B);
  static const _lit = Color(0xFFB9BFC7);
  static const _shine = Color(0xFFE6E9ED);

  /// Towards the light: up, to the left, and out towards the eye (negative
  /// z is nearer under this perspective).
  static final _light = Vector3(-0.35, -0.75, -0.55)..normalize();

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final rotation = Matrix4.rotationX(angle);

    Offset project(double x, double y, double z) {
      final v = matrix.perspectiveTransform(Vector3(x, y, z));
      return centre + Offset(v.x, v.y);
    }

    final quads =
        <({double depth, Path path, Offset a, Offset b, double lit})>[];
    for (var i = 0; i < _segments; i++) {
      final p0 = 2 * math.pi * i / _segments;
      final p1 = 2 * math.pi * (i + 1) / _segments;
      final mid = (p0 + p1) / 2;
      final normal = rotation.transform3(
        Vector3(math.cos(mid), math.sin(mid), 0),
      );
      // Only the side of the rim that faces the eye is drawn: the coin is
      // convex, so the rest is behind the near face or the near rim.
      if (normal.z >= 0) continue;
      final x0 = radius * math.cos(p0), y0 = radius * math.sin(p0);
      final x1 = radius * math.cos(p1), y1 = radius * math.sin(p1);
      final a0 = project(x0, y0, -half), b0 = project(x0, y0, half);
      final a1 = project(x1, y1, -half), b1 = project(x1, y1, half);
      final path = Path()
        ..moveTo(a0.dx, a0.dy)
        ..lineTo(a1.dx, a1.dy)
        ..lineTo(b1.dx, b1.dy)
        ..lineTo(b0.dx, b0.dy)
        ..close();
      final depth = rotation
          .transform3(
            Vector3(radius * math.cos(mid), radius * math.sin(mid), 0),
          )
          .z;
      quads.add((
        depth: depth,
        path: path,
        a: a0,
        b: b0,
        lit: math.max(0, normal.dot(_light)),
      ));
    }
    quads.sort((p, q) => q.depth.compareTo(p.depth));

    final fill = Paint()..isAntiAlias = true;
    final reed = Paint()
      ..color = _shine.withValues(alpha: 0.28)
      ..strokeWidth = 0.55;
    for (final q in quads) {
      final base = Color.lerp(_dark, _lit, 0.12 + 0.7 * math.pow(q.lit, 1.4))!;
      fill.color = Color.lerp(base, _shine, math.pow(q.lit, 14).toDouble())!;
      // A hairline of the same colour closes the seams between quads.
      canvas.drawPath(q.path, fill);
      canvas.drawPath(
        q.path,
        Paint()
          ..color = fill.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
      canvas.drawLine(q.a, q.b, reed);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) =>
      oldDelegate.angle != angle;
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
/// and neither collides with a shape an origin already owns: a chess king is
/// not the crown of the Наследник древних королей, and a jester's hat is not
/// the pointed hat of the Наследник ведьм. Struck into a filled steel face
/// a tone darker than the metal, the way a die leaves them.
class _Coin extends StatelessWidget {
  final bool face;

  /// Settled, the metal brightens: the coin is at rest and lit.
  final bool settled;

  const _Coin({required this.face, required this.settled});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _SolidCoin.diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(_SolidCoin.diameter),
            painter: _FacePainter(settled: settled),
          ),
          SvgPicture.asset(
            face
                ? 'assets/icons/coin/coin_jester.svg'
                : 'assets/icons/coin/coin_king.svg',
            width: 40,
            height: 40,
            colorFilter: ColorFilter.mode(
              settled ? const Color(0xFF5E646C) : const Color(0xFF4A4F56),
              BlendMode.srcIn,
            ),
          ),
        ],
      ),
    );
  }
}

/// A struck face: a filled steel disc lit from the upper left, with the
/// rim's raised border and an inner ring, both a tone darker.
class _FacePainter extends CustomPainter {
  final bool settled;

  const _FacePainter({required this.settled});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: centre, radius: radius);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: settled
              ? const [Color(0xFFE2E5E9), Color(0xFFA3AAB2)]
              : const [Color(0xFFC3C8CF), Color(0xFF7F868F)],
        ).createShader(rect),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = (settled ? const Color(0xFF7C838B) : const Color(0xFF626870))
          .withValues(alpha: 0.9);
    canvas.drawCircle(centre, radius - 1.2, line..strokeWidth = 2.2);
    canvas.drawCircle(centre, radius * 0.8, line..strokeWidth = 1.0);
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) =>
      oldDelegate.settled != settled;
}
