import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../game_engine/models/models.dart';

/// An arm-wrestling bout on its table, at time [t] of [scenario] — the
/// design's `svgAt`, drawn one for one. Phantom 3D, like the coin: the table
/// is the plane y = 0, z comes towards the viewer. The near player (the one
/// who threw down the challenge) sits on z+, at the bottom of the frame;
/// the far one on z−, at the top. The elbows stay put on the table and the
/// forearms are rigid levers, so the locked hands swing sideways about the
/// line from elbow to elbow — to the left when the near player wins, to the
/// right when the far one does.
class ArmWrestleStage extends StatelessWidget {
  final ArmWrestleScenario scenario;
  final bool nearWins;
  final double t;

  const ArmWrestleStage({
    super.key,
    required this.scenario,
    required this.nearWins,
    required this.t,
  });

  static const double width = 300;
  static const double height = 184;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: width / height,
        child: CustomPaint(
          painter: _BoutPainter(scenario, nearWins, t),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Plays a bout's [ArmWrestleScenario.beats] as the frames pass them, the
/// way `CoinHaptics` does a coin's.
class ArmWrestleHaptics {
  double _last = -1;

  void advance(ArmWrestleScenario scenario, double now) {
    for (final (t, beat) in scenario.beats) {
      if (t > _last && t <= now) _play(beat);
    }
    _last = now;
  }

  static void _play(ArmBeat beat) {
    final Future<void> knock = switch (beat) {
      ArmBeat.start => HapticFeedback.lightImpact(),
      ArmBeat.tremble => HapticFeedback.selectionClick(),
      ArmBeat.slam => HapticFeedback.heavyImpact(),
    };
    knock.catchError((Object _) {});
  }
}

// «Кованая сталь», nothing warm.
const _zone = Color(0xFF16181C);
const _tableFar = Color(0xFF2E3238);
const _tableNear = Color(0xFF1E2125);
const _edge = Color(0xFF3A3F47);
const _arm = Color(0xFFBCC2CA);
const _upper = Color(0xFF9EA5AE);
const _armBack = Color(0xFF9AA1AA);
const _upperBack = Color(0xFF7F868F);
const _line = Color(0xFF1F2226);
const _knuck = Color(0xFF7A818A);
const _light = Color(0xFFD8DCE0);

const double _deg = math.pi / 180;

// The camera: turned 16°, tilted 42°, perspective F, scale K, centre.
const double _yaw = 16 * _deg, _pitch = 42 * _deg;
const double _f = 420, _k = 1.3, _cx = 150, _cy = 112;

// The rig: elbows at (0, 0, ±_ez), forearms _lf long, the grip swinging on
// a radius _rc about the line between the elbows, never below _floor.
const double _lf = 62, _ez = 30, _floor = 7;
final double _rc = math.sqrt(_lf * _lf - _ez * _ez);

typedef _V3 = (double, double, double);

/// A point on the stage, and how much nearer it is than the centre.
typedef _P = (Offset, double);

_P _proj(_V3 p) {
  final (x, y, z) = p;
  final xr = x * math.cos(_yaw) - z * math.sin(_yaw);
  final zr = x * math.sin(_yaw) + z * math.cos(_yaw);
  final up = y * math.cos(_pitch) - zr * math.sin(_pitch);
  final dd = zr * math.cos(_pitch) + y * math.sin(_pitch);
  final sc = _f / (_f - dd);
  return (Offset(_cx + xr * sc * _k, _cy - up * sc * _k), sc);
}

/// Where a point's shadow falls: the light is above, left and behind.
_P _shadowAt(_V3 p) => _proj((p.$1 + p.$2 * 0.5, 0, p.$3 + p.$2 * 0.16));

class _Rig {
  final _V3 e, p, s, w;
  _Rig(this.e, this.p, this.s, this.w);

  factory _Rig.at(double theta, {required bool near}) {
    final sg = near ? 1.0 : -1.0;
    final cx = -_rc * math.sin(theta);
    final cy = _floor + (_rc - _floor) * math.cos(theta);
    final _V3 e = (0, 0, sg * _ez);
    final _V3 p = (cx, cy, sg * 3);
    // The shoulder stands straight behind the elbow.
    final _V3 s = (sg * 18, 24, sg * (_ez + 70));
    final dx = p.$1 - e.$1, dy = p.$2 - e.$2, dz = p.$3 - e.$3;
    final l = math.sqrt(dx * dx + dy * dy + dz * dz);
    final _V3 w = (p.$1 - dx / l * 9, p.$2 - dy / l * 9, p.$3 - dz / l * 9);
    return _Rig(e, p, s, w);
  }
}

class _BoutPainter extends CustomPainter {
  final ArmWrestleScenario scenario;
  final bool nearWins;
  final double t;

  _BoutPainter(this.scenario, this.nearWins, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / ArmWrestleStage.width);
    _paint(canvas);
    canvas.restore();
  }

  void _paint(Canvas canvas) {
    final th = scenario.theta(nearWins, t);
    final k = t - scenario.hit;
    final kick = k >= 0 ? 2 * math.exp(-16 * k) * math.sin(70 * k) : 0.0;
    final rn = _Rig.at(th, near: true), rf = _Rig.at(th, near: false);

    _table(canvas);

    canvas.saveLayer(
      null,
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.34),
    );
    _shadow(canvas, rf);
    _shadow(canvas, rn);
    canvas.restore();

    // Where the loser's fist meets the table, a pale ring spreads out.
    if (k >= 0 && k < 0.45) {
      final side = nearWins ? 1 : -1;
      final (c, s) = _proj((
        -_rc * math.sin(side * ArmWrestleScenario.pin),
        0,
        0,
      ));
      final e = k / 0.45, r = (10 + 38 * e) * s;
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 2 * r, height: 2 * r * 0.56),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * (1 - e)
          ..color = _light.withValues(alpha: 0.8 * (1 - e)),
      );
    }

    canvas.save();
    canvas.translate(-th.sign * kick, kick.abs() * 0.5);
    _drawArm(canvas, rf, near: false);
    _drawArm(canvas, rn, near: true);
    // The winner's fist on top.
    if (th > 0.02) {
      _fistOf(canvas, rf, near: false);
      _fistOf(canvas, rn, near: true);
    } else if (th < -0.02) {
      _fistOf(canvas, rn, near: true);
      _fistOf(canvas, rf, near: false);
    } else {
      _fistOf(canvas, rf, near: false);
      _fistOf(canvas, rn, near: true);
    }
    canvas.restore();
  }

  void _table(Canvas canvas) {
    const vw = ArmWrestleStage.width, vh = ArmWrestleStage.height;
    final q = [
      _proj((-80, 0, -220)).$1,
      _proj((80, 0, -220)).$1,
      _proj((80, 0, 220)).$1,
      _proj((-80, 0, 220)).$1,
    ];
    final top = q.map((p) => p.dy).reduce(math.min);
    final bot = q.map((p) => p.dy).reduce(math.max);
    canvas.drawRect(const Rect.fromLTWH(0, 0, vw, vh), Paint()..color = _zone);
    canvas.drawPath(
      Path()..addPolygon(q, true),
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [_tableFar, _tableNear],
            ).createShader(
              Rect.fromLTRB(0, math.max(0, top), vw, math.min(vh, bot)),
            ),
    );
    // A faint light over the whole stage — a radial gradient on the
    // stage's own box, so an ellipse as wide and as tall as the box.
    canvas.save();
    canvas.translate(0.38 * vw, 0.36 * vh);
    canvas.scale(1, vh / vw);
    canvas.drawRect(
      Rect.fromLTWH(-0.38 * vw, -0.36 * vw, vw, vw),
      Paint()
        ..shader = RadialGradient(
          colors: [_light.withValues(alpha: 0.07), _light.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 0.55 * vw)),
    );
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(q[0].dx, q[0].dy)
        ..lineTo(q[3].dx, q[3].dy)
        ..moveTo(q[1].dx, q[1].dy)
        ..lineTo(q[2].dx, q[2].dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _edge,
    );
  }

  void _shadow(Canvas canvas, _Rig r) {
    final (e, es) = _shadowAt(r.e);
    final (w, ws) = _shadowAt(r.w);
    final (p, ps) = _shadowAt(r.p);
    final lift = r.p.$2 / 60;
    _limb(canvas, e, w, 15 * es * _k, 11 * ws * _k, const Color(0xFF000000));
    canvas.drawOval(
      Rect.fromCenter(
        center: p,
        width: 2 * 12 * ps * _k * (1 + lift * 0.3),
        height: 2 * 7 * ps * _k * (1 + lift * 0.3),
      ),
      Paint()..color = const Color(0xFF000000),
    );
  }

  void _drawArm(Canvas canvas, _Rig r, {required bool near}) {
    final (pe, se) = _proj(r.e);
    final (ps, ss) = _proj(r.s);
    final (pw, sw) = _proj(r.w);
    final fa = near ? _arm : _armBack, ua = near ? _upper : _upperBack;
    _limb(canvas, ps, pe, 19 * ss * _k, 16 * se * _k, ua, stroke: _line);
    final elbow = Rect.fromCenter(
      center: pe + Offset(0, 1.5 * se),
      width: 2 * 9 * se * _k,
      height: 2 * 5.4 * se * _k,
    );
    canvas.drawOval(elbow, Paint()..color = ua);
    canvas.drawOval(elbow, _strokePaint(_line, 1.3));
    _limb(canvas, pe, pw, 15 * se * _k, 10.5 * sw * _k, fa, stroke: _line);
  }

  void _fistOf(Canvas canvas, _Rig r, {required bool near}) {
    final (pe, _) = _proj(r.e);
    final (pp, sp) = _proj(r.p);
    final deg = math.atan2(pp.dx - pe.dx, -(pp.dy - pe.dy));
    _fist(canvas, pp, deg, sp * _k * 1.05, near ? _arm : _armBack, !near);
  }

  /// The fist of the first version: a rounded block, the knuckles' ridges
  /// down one side, the thumb tucked under. Its local "up" carries on from
  /// the forearm; the far one is mirrored.
  void _fist(
    Canvas canvas,
    Offset c,
    double angle,
    double scale,
    Color fill,
    bool flip,
  ) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    canvas.scale(scale * (flip ? -1 : 1), scale);
    final block = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-7.5, -9.5, 15, 19),
      const Radius.circular(5.5),
    );
    canvas.drawRRect(block, Paint()..color = fill);
    canvas.drawRRect(block, _strokePaint(_line, 1.3 / scale));
    final knuckles = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 / scale
      ..strokeCap = StrokeCap.round
      ..color = _knuck;
    for (final y in [-4.5, 0.0, 4.5]) {
      canvas.drawLine(Offset(-7, y), Offset(-3.6, y), knuckles);
    }
    _limb(
      canvas,
      const Offset(2, 6),
      const Offset(10, 3.5),
      6,
      5,
      fill,
      stroke: _line,
      strokeWidth: 1.3 / scale,
    );
    canvas.restore();
  }

  static Paint _strokePaint(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  /// A tapered limb from [a] to [b], [wa] wide at one end and [wb] at the
  /// other, with round ends.
  static void _limb(
    Canvas canvas,
    Offset a,
    Offset b,
    double wa,
    double wb,
    Color fill, {
    Color? stroke,
    double strokeWidth = 1.3,
  }) {
    final d = b - a;
    final l = d.distance == 0 ? 1.0 : d.distance;
    final n = Offset(-d.dy / l, d.dx / l);
    final path = Path()
      ..moveTo(a.dx + n.dx * wa / 2, a.dy + n.dy * wa / 2)
      ..lineTo(b.dx + n.dx * wb / 2, b.dy + n.dy * wb / 2)
      ..arcToPoint(
        b - n * (wb / 2),
        radius: Radius.circular(wb / 2),
        clockwise: false,
      )
      ..lineTo(a.dx - n.dx * wa / 2, a.dy - n.dy * wa / 2)
      ..arcToPoint(
        a + n * (wa / 2),
        radius: Radius.circular(wa / 2),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    if (stroke != null) {
      canvas.drawPath(path, _strokePaint(stroke, strokeWidth));
    }
  }

  @override
  bool shouldRepaint(_BoutPainter old) =>
      old.t != t || old.scenario != scenario || old.nearWins != nearWins;
}
