import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../../../game_engine/models/models.dart';

/// One frame of a throw: how high the coin is, how far it has turned about
/// its horizontal axis (0 is a face square to the eye, π/2 standing on
/// edge), how far it has wheeled about the eye's own axis, and how far it
/// has rolled off its spot.
final class CoinPose {
  final double lift;
  final double angle;
  final double wheel;
  final Offset drift;

  const CoinPose({
    this.lift = 0,
    required this.angle,
    this.wheel = 0,
    this.drift = Offset.zero,
  });
}

/// A moment in a throw the hand should feel.
enum CoinBeat {
  /// The coin hits the table.
  land,

  /// It comes down again from a bounce.
  bounce,

  /// One rattle of a coin spinning on its edge.
  tick,

  /// A coin on its edge goes still, standing.
  freeze,
}

/// The whole of one throw, worked out in advance from its [style]: where
/// the coin is at any moment, how long it takes, and when it knocks.
///
/// Pure arithmetic, so a test can ask any variant where it ends up. Every
/// variant ends where the throw came down: flat on the face it started on
/// (the half-turns are even), or, for an [edge], standing.
final class CoinMotion {
  final CoinStyle style;
  final bool edge;

  CoinMotion(this.style, {this.edge = false}) {
    _beats = _findBeats();
  }

  /// The usual toss, before [CoinStyle.lift]: two seconds in the air, fifty
  /// pixels up.
  static const _baseFlight = 2.0;
  static const _basePeak = 50.0;

  /// Each bounce leaves at this fraction of the speed it came down with.
  static const _firstRebound = 0.34;
  static const _nextRebound = 0.45;

  /// Still on the table before the verdict; longer for a coin standing, so
  /// the table has time to see it.
  static const _rest = 0.3;
  static const _edgeHold = 1.0;

  bool get spins => edge || style.spins;

  /// A higher toss is a longer one under the same gravity.
  late final double flight = _baseFlight * math.sqrt(style.lift);
  late final double peak = _basePeak * style.lift;
  late final double _gravity = 8 * peak / (flight * flight);
  late final double _launch = _gravity * flight / 2;

  late final double _turns = style.halfTurns + (spins ? 0.5 : 0.0);

  late final List<double> _bounceSpeeds = [
    for (var k = 0; k < style.bounces; k++)
      _launch * _firstRebound * math.pow(_nextRebound, k),
  ];
  late final List<double> _bounceTimes = [
    for (final v in _bounceSpeeds) 2 * v / _gravity,
  ];

  late final double seconds = spins
      ? flight + style.spinTime + (edge ? _edgeHold : _rest)
      : flight + _bounceTimes.fold(0.0, (a, b) => a + b) + _rest;

  late final List<(double, CoinBeat)> _beats;

  /// When the coin knocks, in order.
  List<(double, CoinBeat)> get beats => _beats;

  /// Where it ends: flat and square, or standing.
  CoinPose get rest => CoinPose(angle: edge ? math.pi / 2 : 0);

  /// How far through its turns the coin is, 0..1, at [t] in the air: a
  /// brisk, nearly even spin that eases off to nothing just as it lands.
  double _turned(double t) {
    final x = (t / flight).clamp(0.0, 1.0);
    return 1 - math.pow(1 - x, 1.5).toDouble();
  }

  CoinPose poseAt(double t) {
    if (t >= seconds) return rest;
    if (t < flight) {
      return CoinPose(
        lift: _launch * t - _gravity * t * t / 2,
        angle: math.pi * _turns * _turned(t),
        wheel: style.axisTilt,
      );
    }
    return spins ? _spinning(t - flight) : _bouncing(t - flight);
  }

  /// Down flat: one to three bounces, each lower, the coin tipping a little
  /// and back on each, the lean of its axis dying away with them.
  CoinPose _bouncing(double since) {
    final flat = math.pi * style.halfTurns;
    final total = _bounceTimes.fold(0.0, (a, b) => a + b);
    var start = 0.0;
    for (var k = 0; k < _bounceTimes.length; k++) {
      final d = _bounceTimes[k];
      if (since < start + d) {
        final s = since - start;
        final v = _bounceSpeeds[k];
        final tip = 0.45 * math.pow(0.5, k) * math.sin(math.pi * s / d);
        return CoinPose(
          lift: v * s - _gravity * s * s / 2,
          angle: flat + (k.isEven ? tip : -tip),
          wheel: style.axisTilt * (1 - (start + s) / total),
        );
      }
      start += d;
    }
    return CoinPose(angle: flat);
  }

  /// Down on its edge, spinning like a disc on a table.
  CoinPose _spinning(double since) {
    final upright = math.pi * _turns;
    final u = math.min(1.0, since / style.spinTime);
    if (u >= 1) {
      if (edge) return CoinPose(angle: upright);
      // Flat after the clatter, with a last quick shiver.
      final after = since - style.spinTime;
      final shiver =
          0.07 * math.exp(-after / 0.07) * math.sin(2 * math.pi * after * 14);
      return CoinPose(angle: upright - math.pi / 2 + shiver);
    }
    final dir = style.spinDirection;
    final lean = edge ? _edgeLean(u) : math.pi / 2 * math.pow(u, 2.2);
    final wheeling = _wheeling(u);
    final rattle = 0.035 * u * math.sin(3 * wheeling);
    final wheel = style.axisTilt * (1 - u) + dir * wheeling;
    final roll = style.rollRadius * math.sin(math.pi * u);
    return CoinPose(
      angle: upright - lean + rattle,
      wheel: wheel,
      drift: Offset(math.cos(wheel), math.sin(wheel)) * roll,
    );
  }

  /// How far round a spinning coin has wheeled, always a whole number of
  /// turns by the end, so the face lies square.
  ///
  /// Falling flat it is Euler's disk — the wheeling speeds up as the lean
  /// grows; standing, it slows to a stop.
  double _wheeling(double u) {
    if (edge) return 2 * math.pi * 2 * (1 - math.pow(1 - u, 2));
    const c = 0.96;
    final g = 1 - math.sqrt(1 - c * u);
    final g1 = 1 - math.sqrt(1 - c);
    return 2 * math.pi * 4 * g / g1;
  }

  /// A coin that will stand leans like any other, and nearly goes over
  /// [CoinStyle.nearFalls] times before it rights itself for good — nobody
  /// can tell until the last second.
  double _edgeLean(double u) {
    final n = style.nearFalls;
    final s = math.sin(n * math.pi * math.pow(u, 0.85));
    return 0.75 * (1 - 0.45 * u) * s * s;
  }

  List<(double, CoinBeat)> _findBeats() {
    final beats = <(double, CoinBeat)>[(flight, CoinBeat.land)];
    if (!spins) {
      var t = flight;
      for (final d in _bounceTimes) {
        t += d;
        beats.add((t, CoinBeat.bounce));
      }
      return beats;
    }
    // A tick each time the rattle comes round; it quickens with the
    // wheeling, and is never faster than the hand can tell apart.
    var last = flight;
    var lastTurn = 0;
    for (var s = 0.0; s < style.spinTime; s += 0.004) {
      final turn = (3 * _wheeling(s / style.spinTime) / (2 * math.pi)).floor();
      if (turn != lastTurn && flight + s - last > 0.045) {
        beats.add((flight + s, CoinBeat.tick));
        last = flight + s;
      }
      lastTurn = turn;
    }
    beats.add((
      flight + style.spinTime,
      edge ? CoinBeat.freeze : CoinBeat.land,
    ));
    return beats;
  }
}

/// Plays a throw's [CoinMotion.beats] on the phone as the frames pass them:
/// a light knock for the landing, a softer one for each bounce, ticks for a
/// spinning rattle, and one clear one when a coin goes still standing.
class CoinHaptics {
  double _last = -1;

  void advance(CoinMotion motion, double now) {
    for (final (t, beat) in motion.beats) {
      if (t > _last && t <= now) _play(beat);
    }
    _last = now;
  }

  void reset() => _last = -1;

  static void _play(CoinBeat beat) {
    final Future<void> knock = switch (beat) {
      CoinBeat.land => HapticFeedback.lightImpact(),
      CoinBeat.bounce || CoinBeat.tick => HapticFeedback.selectionClick(),
      CoinBeat.freeze => HapticFeedback.mediumImpact(),
    };
    // A phone with no motor, or a test with no platform, is no reason to
    // fail a throw.
    knock.catchError((Object _) {});
  }
}

/// The coin on its table: a faint floor line, a shadow that is small and
/// pale while the coin is high and dense and wide as it comes down, and the
/// coin itself at [pose].
class CoinTossStage extends StatelessWidget {
  final CoinPose pose;

  /// How high the toss goes at its peak, to scale the shadow by.
  final double peak;

  /// True is the Jester's side showing, false the King's.
  final bool face;
  final bool settled;

  const CoinTossStage({
    super.key,
    required this.pose,
    required this.peak,
    required this.face,
    required this.settled,
  });

  static const double height = 176;

  /// Where the floor is, from the top.
  static const double _floorY = 150;

  @override
  Widget build(BuildContext context) {
    const radius = _SolidCoin.diameter / 2;
    // The coin stands on the floor whatever way up it is: its lowest point,
    // as it is turned now, rests on the line — a flat coin by its rim, one
    // on end by its edge, a spinning one by wherever it leans.
    final extent =
        radius * math.cos(pose.angle).abs() +
        _SolidCoin.thickness / 2 * math.sin(pose.angle).abs();
    final centreY = _floorY - extent - pose.lift;
    final high = (pose.lift / (peak * 1.1)).clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: _floorY,
            child: Center(
              child: Container(
                width: 200,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _floorY - 8,
            height: 16,
            child: CustomPaint(
              painter: _ShadowPainter(
                dx: pose.drift.dx,
                width: 80 * (1 - 0.55 * high),
                opacity: 0.6 * (1 - 0.75 * high),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: centreY - radius,
            child: Center(
              child: Transform.translate(
                offset: pose.drift,
                child: _SolidCoin(
                  angle: pose.angle,
                  wheel: pose.wheel,
                  face: face,
                  settled: settled,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The coin's shadow on the floor: a soft ellipse, wide and dark when the
/// coin is down, small and pale when it is high.
class _ShadowPainter extends CustomPainter {
  final double dx;
  final double width;
  final double opacity;

  const _ShadowPainter({
    required this.dx,
    required this.width,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero) + Offset(dx, 0);
    canvas.drawOval(
      Rect.fromCenter(center: centre, width: width, height: width * 0.14),
      Paint()
        ..color = Colors.black.withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(covariant _ShadowPainter old) =>
      old.dx != dx || old.width != width || old.opacity != opacity;
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

  /// How far it has wheeled about the eye's axis — a spinning coin's
  /// precession, seen from above.
  final double wheel;

  /// True is the Jester's side, false the King's — the two entries of a
  /// card's `sides` in order.
  final bool face;
  final bool settled;

  const _SolidCoin({
    required this.angle,
    this.wheel = 0,
    required this.face,
    required this.settled,
  });

  static const double diameter = 84;

  /// About a ninth of the diameter: thick enough to stand on.
  static const double thickness = 9.5;

  /// A little perspective, enough for the near edge to read as nearer.
  static const double _perspective = 0.003;

  static Matrix4 matrixFor(double angle, double wheel) => Matrix4.identity()
    ..setEntry(3, 2, _perspective)
    ..rotateZ(wheel)
    ..rotateX(angle);

  @override
  Widget build(BuildContext context) {
    final matrix = matrixFor(angle, wheel);
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
              wheel: wheel,
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
  final double wheel;
  final double radius;
  final double half;
  final Matrix4 matrix;

  _EdgePainter({
    required this.angle,
    required this.wheel,
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
    final rotation = Matrix4.rotationZ(wheel)..rotateX(angle);

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
      oldDelegate.angle != angle || oldDelegate.wheel != wheel;
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
