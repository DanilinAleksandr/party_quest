import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../../../game_engine/models/models.dart';

/// One frame of a throw, in the world of the table: how high the coin is
/// above where it would rest, how far it has turned about the table's
/// left-right axis ([angle]: 0 is lying King-side up, π/2 standing on its
/// edge), how far it has wheeled about the upright ([wheel]), and where on
/// the table it is ([drift]: across, and towards the eye).
final class CoinPose {
  final double lift;
  final double angle;
  final double wheel;

  /// How far the axis it tumbles about is tipped towards or away from the
  /// eye — with [wheel], the sway of that axis in the air.
  final double roll;
  final Offset drift;

  const CoinPose({
    this.lift = 0,
    required this.angle,
    this.wheel = 0,
    this.roll = 0,
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

/// The one camera every throw is seen through: above the table and in
/// front of it, looking down at [elevation] — so a coin lying flat is an
/// ellipse, a coin in the air shows its faces and its edge as it turns,
/// and nothing about the view changes from the toss to the rest.
abstract final class CoinCamera {
  static const double elevation = 37 * math.pi / 180;

  /// A little perspective, enough for the near edge to read as nearer.
  static const double perspective = 0.0028;

  /// World (x across, y up, z towards the eye) to the screen's (x right,
  /// y down, z into the screen).
  static final Matrix4 view = Matrix4.identity()
    ..setEntry(1, 1, -math.cos(elevation))
    ..setEntry(1, 2, math.sin(elevation))
    ..setEntry(2, 1, -math.sin(elevation))
    ..setEntry(2, 2, -math.cos(elevation));

  static final Matrix4 projection = Matrix4.identity()
    ..setEntry(3, 2, perspective);
}

/// The whole of one throw, worked out in advance from its [style]: where
/// the coin is at any moment, how long it takes, and when it knocks.
///
/// Pure arithmetic, so a test can ask any variant where it ends up. Every
/// variant ends where the throw came down: on the face it started on (the
/// half-turns are even), risen and turned to face the eye so it can be
/// read — or, for an [edge], standing.
final class CoinMotion {
  final CoinStyle style;
  final bool edge;

  CoinMotion(this.style, {this.edge = false}) {
    _beats = _findBeats();
  }

  /// The usual toss, before [CoinStyle.lift]: two seconds in the air,
  /// seventy-five pixels up.
  static const _baseFlight = 2.0;
  static const _basePeak = 75.0;

  /// How far the tumbling axis sways in the air, at most, and how many
  /// times its sway goes round in one flight.
  static const _sway = 17 * math.pi / 180;
  static const _swayTurns = 0.8;

  /// Each bounce leaves at this fraction of the speed it came down with.
  static const _firstRebound = 0.34;
  static const _nextRebound = 0.45;

  /// Lying still for a moment, then rising towards the eye and turning its
  /// face to it, then still again before the verdict.
  static const _lie = 0.25;
  static const _reveal = 0.4;
  static const _after = 0.2;

  /// A coin standing is left standing a second, so the table can see it.
  static const _edgeHold = 1.0;

  /// The spin's rattle, only in its last moments before it goes over.
  static const _rattle = 0.4;

  /// Turned to face the eye: the face tilted up towards the camera.
  static const double faceOn = math.pi / 2 - CoinCamera.elevation;
  static const double _revealLift = 16;
  static const double _revealNear = 22;

  /// Standing, turned this far round, so both its edge and a sliver of face
  /// show.
  static const double _standTurn = 1.1;

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
  late final double _bouncing = _bounceTimes.fold(0.0, (a, b) => a + b);

  /// When the coin is down for good and starts to rise for the reading.
  late final double _down = spins
      ? flight + style.spinTime + _lie
      : flight + _bouncing + _lie;

  late final double seconds = edge
      ? flight + style.spinTime + _edgeHold
      : _down + _reveal + _after;

  late final List<(double, CoinBeat)> _beats;

  /// When the coin knocks, in order.
  List<(double, CoinBeat)> get beats => _beats;

  /// Where it ends: risen and facing the eye, or standing.
  CoinPose get rest => edge
      ? CoinPose(angle: math.pi / 2, wheel: style.spinDirection * _standTurn)
      : const CoinPose(
          angle: faceOn,
          lift: _revealLift,
          drift: Offset(0, _revealNear),
        );

  /// How far through its turns the coin is, 0..1, at [t] in the air.
  ///
  /// Not honest physics, but how a throw reads: fastest straight off the
  /// hand and on the way up, slowing over the top and down, and coming in
  /// slowly, so its last turns can be seen one by one.
  double _turned(double t) {
    final x = (t / flight).clamp(0.0, 1.0);
    return 1 - math.pow(1 - x, 2.4).toDouble();
  }

  /// Where the sway of the tumbling axis starts round, from the variant.
  late final double _swayFrom = (style.number * 2.39996) % (2 * math.pi);

  static double _ease(double x) {
    final t = x.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  CoinPose poseAt(double t) {
    if (t >= seconds) return rest;
    if (t < flight) {
      // The axis it tumbles about is not fixed: it sways and drifts round,
      // so each turn shows the face at a slightly different slant, and the
      // sway dies away as it comes in to land.
      final x = t / flight;
      final sway =
          _sway *
          math.sin(math.pi * math.min(1, x * 1.6)) *
          math.pow(1 - x, 0.8);
      final round =
          _swayFrom + style.spinDirection * 2 * math.pi * _swayTurns * x;
      return CoinPose(
        lift: _launch * t - _gravity * t * t / 2,
        angle: math.pi * _turns * _turned(t),
        wheel: sway * math.cos(round),
        roll: sway * math.sin(round),
      );
    }
    if (!edge && t >= _down) {
      // Down and still; now it rises towards the eye and turns its face to
      // it, so what came up can be read — the camera never moves.
      final e = _ease((t - _down) / _reveal);
      return CoinPose(
        angle: math.pi * style.halfTurns + faceOn * e,
        lift: _revealLift * e,
        drift: Offset(0, _revealNear * e),
      );
    }
    return spins ? _spinning(t - flight) : _bouncingAt(t - flight);
  }

  /// Down flat: one to three bounces, each lower, the coin tipping a little
  /// and back on each.
  CoinPose _bouncingAt(double since) {
    final flat = math.pi * style.halfTurns;
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
        );
      }
      start += d;
    }
    return CoinPose(angle: flat);
  }

  /// Down on its edge, spinning like a disc on a table: calmly, slow
  /// enough for the eye to follow round.
  CoinPose _spinning(double since) {
    final upright = math.pi * _turns;
    final u = math.min(1.0, since / style.spinTime);
    final dir = style.spinDirection;
    if (u >= 1) {
      if (edge) return CoinPose(angle: upright, wheel: dir * _standTurn);
      return CoinPose(angle: upright - math.pi / 2);
    }
    final wheel = dir * _wheeling(u);
    final double lean;
    var rattle = 0.0;
    if (edge) {
      lean = _edgeLean(u);
    } else {
      lean = math.pi / 2 * math.pow(u, 2.4);
      // The rattle only in the last moments, quickening a little.
      final left = style.spinTime - since;
      if (left < _rattle) {
        final s = _rattle - left;
        final x = s / _rattle;
        rattle = 0.025 * x * math.sin(2 * math.pi * (9 * s + 13.75 * s * s));
      }
    }
    final roll = style.rollRadius * math.sin(math.pi * u);
    return CoinPose(
      angle: upright - lean + rattle,
      wheel: wheel,
      drift: Offset(math.cos(wheel), math.sin(wheel)) * roll,
    );
  }

  /// How far round a spinning coin has wheeled: about a turn a second,
  /// no faster, ending on a whole number of turns (falling, so the face
  /// lies square) or on its standing turn.
  double _wheeling(double u) {
    const rate = 2 * math.pi * 0.95;
    if (edge) {
      final half = rate * style.spinTime / 2;
      final whole = math.max(1, (half / (2 * math.pi)).round());
      return (2 * math.pi * whole + _standTurn) * (1 - math.pow(1 - u, 2));
    }
    // A little quicker towards the end, never more than a third.
    double w(double x) => x + x * x / 6;
    final raw = rate * style.spinTime * w(1);
    final whole = math.max(1, (raw / (2 * math.pi)).round());
    return 2 * math.pi * whole * w(u) / w(1);
  }

  /// A coin that will stand wobbles a little as it spins down, and at most
  /// once dips, barely — never enough to look like a fall.
  double _edgeLean(double u) {
    if (style.nearFalls == 0) return 0.05 * math.sin(math.pi * u);
    final s = math.sin(math.pi * u);
    return 0.16 * s * s;
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
    // A soft tick each half turn round; for a spin going over, the rattle
    // at the end, a tick a shake, quickening with it.
    var lastHalf = 0;
    final end = flight + style.spinTime;
    for (var s = 0.0; s < style.spinTime; s += 0.004) {
      final t = flight + s;
      final left = style.spinTime - s;
      if (!edge && left < _rattle) break;
      final half = (_wheeling(s / style.spinTime) / math.pi).floor();
      if (half != lastHalf) beats.add((t, CoinBeat.tick));
      lastHalf = half;
    }
    if (!edge) {
      var lastShake = -1;
      for (var s = 0.0; s < _rattle; s += 0.002) {
        final shake = (9 * s + 13.75 * s * s).floor();
        if (shake != lastShake && lastShake >= 0) {
          beats.add((end - _rattle + s, CoinBeat.tick));
        }
        lastShake = shake;
      }
    }
    beats.add((end, edge ? CoinBeat.freeze : CoinBeat.land));
    return beats;
  }
}

/// Plays a throw's [CoinMotion.beats] on the phone as the frames pass them:
/// a light knock for the landing, a softer one for each bounce, ticks for a
/// spin, and one clear one when a coin goes still standing.
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

/// The coin on its table, all seen through [CoinCamera]: a faint table and
/// its far edge, the coin's shadow — small and pale while it is high, wide
/// and dark as it comes down — and the coin at [pose].
class CoinTossStage extends StatelessWidget {
  final CoinPose pose;

  /// How high the toss goes at its peak, to fade the shadow by.
  final double peak;

  /// The mark on the side that ends face up: true the Jester, false the
  /// King. The other side carries the other.
  final bool face;
  final bool settled;

  const CoinTossStage({
    super.key,
    required this.pose,
    required this.peak,
    required this.face,
    required this.settled,
  });

  static const double height = 240;

  /// Where on the stage the spot the coin rests on is seen.
  static const double _originY = 184;

  @override
  Widget build(BuildContext context) {
    const radius = _SolidCoin.diameter / 2;
    const half = _SolidCoin.thickness / 2;
    // The coin's centre stands as high as its lowest point needs: a coin
    // lying flat on its face, one on end on its edge, one leaning by its
    // rim — so it is always on the table, whatever way up.
    final ground =
        radius * math.sin(pose.angle).abs() + half * math.cos(pose.angle).abs();
    final world = Matrix4.translationValues(
      pose.drift.dx,
      ground + pose.lift,
      pose.drift.dy,
    );
    final orientation = Matrix4.rotationY(pose.wheel)
      ..rotateZ(pose.roll)
      ..rotateX(pose.angle)
      ..rotateX(math.pi / 2);
    final turn = CoinCamera.view * orientation as Matrix4;
    final place = CoinCamera.projection * CoinCamera.view * world as Matrix4;
    final high = (pose.lift / (peak * 1.1)).clamp(0.0, 1.0);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final origin = Offset(box.maxWidth / 2, _originY);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _TablePainter(
                    origin: origin,
                    shadowAt: pose.drift,
                    // The footprint of a coin lying flat, shrinking as it
                    // stands up and as it rises.
                    shadowRadius:
                        radius *
                        (0.55 + 0.45 * math.cos(pose.angle).abs()) *
                        (1 - 0.45 * high),
                    shadowOpacity: 0.6 * (1 - 0.75 * high),
                  ),
                ),
              ),
              Positioned(
                left: origin.dx - radius,
                top: origin.dy - radius,
                child: _SolidCoin(
                  place: place,
                  turn: turn,
                  orientation: orientation,
                  face: face,
                  settled: settled,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The table, seen through the camera: a faint far edge, and the coin's
/// shadow on it.
class _TablePainter extends CustomPainter {
  final Offset origin;
  final Offset shadowAt;
  final double shadowRadius;
  final double shadowOpacity;

  const _TablePainter({
    required this.origin,
    required this.shadowAt,
    required this.shadowRadius,
    required this.shadowOpacity,
  });

  Offset _project(double x, double z) {
    final m = CoinCamera.projection * CoinCamera.view as Matrix4;
    final v = m.perspectiveTransform(Vector3(x, 0, z));
    return origin + Offset(v.x, v.y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // The far edge of the table, well behind the coin.
    final left = _project(-150, -95), right = _project(150, -95);
    canvas.drawLine(
      left,
      right,
      Paint()
        ..strokeWidth = 1
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromPoints(left, right.translate(0, 1))),
    );
    // The shadow: a circle on the table, so an ellipse to the eye.
    final centre = _project(shadowAt.dx, shadowAt.dy);
    final across = _project(shadowAt.dx + shadowRadius, shadowAt.dy);
    final deep = _project(shadowAt.dx, shadowAt.dy + shadowRadius);
    canvas.drawOval(
      Rect.fromCenter(
        center: centre,
        width: 2 * (across.dx - centre.dx),
        height: 2 * (deep.dy - centre.dy).abs(),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: shadowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(covariant _TablePainter old) =>
      old.shadowAt != shadowAt ||
      old.shadowRadius != shadowRadius ||
      old.shadowOpacity != shadowOpacity ||
      old.origin != origin;
}

/// The coin as a solid: two struck faces and the milled edge between them,
/// placed by [place] and turned by [orientation], all through the one
/// camera. The face turned towards the eye is a widget carried by the same
/// matrix the edge is projected with, so the two meet exactly; the edge is
/// painted underneath it.
class _SolidCoin extends StatelessWidget {
  /// Projection, camera and where the coin is on the table.
  final Matrix4 place;

  /// The camera and the coin's turn, without its place: for which way its
  /// faces and edge look.
  final Matrix4 turn;
  final Matrix4 orientation;

  /// The mark on the King-end side — the side that ends face up.
  final bool face;
  final bool settled;

  const _SolidCoin({
    required this.place,
    required this.turn,
    required this.orientation,
    required this.face,
    required this.settled,
  });

  static const double diameter = 84;

  /// About a ninth of the diameter: thick enough to stand on.
  static const double thickness = 9.5;

  @override
  Widget build(BuildContext context) {
    final matrix = place * orientation as Matrix4;
    // Which end of the coin faces the eye: the end at local −z, or the
    // other. Negative z is towards the eye.
    final kingEndNormal = turn.transform3(Vector3(0, 0, -1));
    final kingEndShows = kingEndNormal.z < 0;
    final edgeOn = kingEndNormal.z.abs() < 0.02;
    final faceMatrix = kingEndShows
        ? (matrix.clone()..translateByDouble(0, 0, -thickness / 2, 1))
        // The far end, seen from its own side: flipped once more so its
        // mark reads the right way round, not mirrored.
        : (matrix.clone()
            ..translateByDouble(0, 0, thickness / 2, 1)
            ..scaleByDouble(1, -1, 1, 1));
    return SizedBox.square(
      dimension: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(diameter),
            painter: _EdgePainter(
              radius: diameter / 2,
              half: thickness / 2,
              matrix: matrix,
              turn: turn,
            ),
          ),
          if (!edgeOn)
            Transform(
              alignment: Alignment.center,
              transform: faceMatrix,
              child: _Coin(face: kingEndShows ? face : !face, settled: settled),
            ),
        ],
      ),
    );
  }
}

/// The milled edge, projected through the coin's own matrix: a strip of
/// quads around the rim, lit from above and to the left so a highlight
/// slides along it as the coin turns, and crossed by fine light reeding.
class _EdgePainter extends CustomPainter {
  final double radius;
  final double half;
  final Matrix4 matrix;
  final Matrix4 turn;

  _EdgePainter({
    required this.radius,
    required this.half,
    required this.matrix,
    required this.turn,
  });

  static const _segments = 72;
  static const _dark = Color(0xFF3F444B);
  static const _lit = Color(0xFFB9BFC7);
  static const _shine = Color(0xFFE6E9ED);

  /// Towards the light, on the screen: up, to the left, and out towards
  /// the eye (negative z is nearer).
  static final _light = Vector3(-0.35, -0.75, -0.55)..normalize();

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);

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
      final normal = turn.transform3(Vector3(math.cos(mid), math.sin(mid), 0));
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
      final depth = turn
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
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final reed = Paint()
      ..color = _shine.withValues(alpha: 0.28)
      ..strokeWidth = 0.55;
    for (final q in quads) {
      final base = Color.lerp(_dark, _lit, 0.12 + 0.7 * math.pow(q.lit, 1.4))!;
      fill.color = Color.lerp(base, _shine, math.pow(q.lit, 14).toDouble())!;
      canvas.drawPath(q.path, fill);
      // A hairline of the same colour closes the seams between quads.
      canvas.drawPath(q.path, seam..color = fill.color);
      canvas.drawLine(q.a, q.b, reed);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) =>
      oldDelegate.matrix != matrix;
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
