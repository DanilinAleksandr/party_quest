import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'strip_kit.dart';
import 'strip_shapes.dart';
import 'svg_path.dart';

/// The stops on the scene strip, ported from `stop-scenes.js`: the halt in
/// three variants (14b–14d) and the tavern from inside (15f).
///
/// The shadow rule: the left of the strip is dark and holds only the label,
/// the scene sits on the right and comes out of the dark. On entry the strip
/// darkens, then the pieces light up one after another. Warm light comes
/// only from fire, candles and the hearth.
///
/// Coordinates are the prototype's, on a 412 dp strip; a narrower strip
/// keeps the scene against its right edge and loses shadow on the left.

const double kStopWidth = 412;
const double _gy = 46;
const double _h = 56;
const _warm = (185, 122, 82);

Color _w(double a) => Color.fromRGBO(_warm.$1, _warm.$2, _warm.$3, a);

abstract final class _C {
  static final far = hex('#353940');
  static final midfar = hex('#2A2E34');
  static final mid = hex('#1D2024');
  static final ground = hex('#131518');
  static final near = hex('#0A0B0D');
  static final line = hex('#262A2F');
  static final dark = hex('#0B0C0E');
  static const fig = StripColors.figure;
}

/// Which stop, and for the halt, which of its three variants.
enum StopKind { camp1, camp2, camp3, tavern }

/// How a looping part moves, from the prototype's CSS keyframes.
enum StopMotion { flick, glow, sway, laugh, reachLeft, reachRight }

/// A part that moves: recorded once, then transformed or faded per frame
/// about the bottom-centre of its own bounds, as `transform-box: fill-box`.
final class StopAnim {
  final ui.Picture picture;
  final Rect bounds;
  final StopMotion motion;
  final double period;
  final double delay;

  /// The resting opacity a glow breathes around; the keyframes replace it.
  StopAnim(
    this.picture,
    this.bounds,
    this.motion,
    this.period, {
    this.delay = 0,
  });
}

/// One piece of a stop: a still drawing and its moving parts, lit up in the
/// entry by [order] (`data-in` in the prototype); a piece without an order is
/// part of the room or the sky and is there from the first frame.
final class StopPiece {
  final int? order;
  final ui.Picture still;
  final List<StopAnim> anims;

  StopPiece(this.order, this.still, this.anims);
}

/// A stop scene, built once when the party arrives.
final class StopScene {
  final String label;
  final List<StopPiece> pieces;

  StopScene(this.label, this.pieces);

  /// The last piece is lit this long after arrival.
  Duration get entry => Duration(
    milliseconds:
        900 + (pieces.map((p) => p.order ?? 0).fold(0, math.max)) * 300 + 650,
  );

  void dispose() {
    for (final p in pieces) {
      p.still.dispose();
      for (final a in p.anims) {
        a.picture.dispose();
      }
    }
  }
}

// ── a small recording kit ─────────────────────────────────────────────────

final class _Rec {
  final _prims = <StripPrim>[];
  final _anims = <StopAnim>[];
  final _shaded = <void Function(Canvas)>[];

  void add(Iterable<StripPrim> p) => _prims.addAll(p);
  void one(StripPrim p) => _prims.add(p);
  void paint(void Function(Canvas) fn) => _shaded.add(fn);
  void anim(StopAnim a) => _anims.add(a);

  StopPiece piece([int? order]) {
    final r = ui.PictureRecorder();
    final c = Canvas(r);
    for (final p in _prims) {
      p.paint(c);
    }
    for (final fn in _shaded) {
      fn(c);
    }
    return StopPiece(order, r.endRecording(), List.of(_anims));
  }
}

ui.Picture _picture(List<StripPrim> prims) {
  final r = ui.PictureRecorder();
  final c = Canvas(r);
  for (final p in prims) {
    p.paint(c);
  }
  return r.endRecording();
}

Rect _bounds(List<StripPrim> prims) =>
    prims.map((p) => p.path.getBounds()).reduce((a, b) => a.expandToInclude(b));

// ── shared pieces ─────────────────────────────────────────────────────────

List<StripPrim> _firs(
  double x0,
  double x1,
  Color col,
  double hMin,
  double hMax,
  double base,
  int seed, [
  (double, double) gap = (-6, 3),
]) {
  final r = stripRng(seed), g = StripGeo(56);
  final out = <StripPrim>[];
  var x = x0;
  while (x < x1) {
    final it = fir(r, g, col, hMin, hMax, base);
    out.addAll(translated(it.prims, x - it.w / 2, 0));
    x += it.w + gap.$1 + r() * (gap.$2 - gap.$1);
  }
  return out;
}

List<StripPrim> _trunks(double x0, double x1, Color col, int seed) {
  final r = stripRng(seed);
  final out = <StripPrim>[];
  var x = x0;
  while (x < x1) {
    final w = 1 + r() * 2.4;
    out.add(rect(x, -2, w, _gy - 1, col));
    x += w + 4 + r() * 16;
  }
  return out;
}

void _fog(_Rec rec, double y0, double y1, [double a = 0.46]) {
  final c = hex('#565C66');
  rec.paint(
    (canvas) => canvas.drawRect(
      Rect.fromLTWH(0, y0, kStopWidth, y1 - y0),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y0),
          Offset(0, y1),
          [
            c.withValues(alpha: 0),
            c.withValues(alpha: a),
            c.withValues(alpha: 0),
          ],
          const [0, 0.55, 1],
        ),
    ),
  );
}

void _ground(_Rec rec, [Color? col]) =>
    rec.one(rect(0, _gy, kStopWidth, _h - _gy, col ?? _C.ground));

/// A soft warm pool of light — the prototype's radial gradient.
ui.Picture _glowPicture(double cx, double cy, double rx, double ry) {
  final r = ui.PictureRecorder();
  final c = Canvas(r);
  c.save();
  c.translate(cx, cy);
  c.scale(1, ry / rx);
  c.drawCircle(
    Offset.zero,
    rx,
    Paint()..shader = ui.Gradient.radial(Offset.zero, rx, [_w(0.38), _w(0)]),
  );
  c.restore();
  return r.endRecording();
}

StopAnim _glow(double cx, double cy, double rx, double ry, double period) =>
    StopAnim(
      _glowPicture(cx, cy, rx, ry),
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      StopMotion.glow,
      period,
    );

const _flameD =
    'M12 3.6C15.8 7.6 17 11.2 15.1 14.4Q13.9 16.2 12 16.2Q10.1 16.2 8.9 14.4C7.3 11.8 8.4 9.2 10.4 7.4Q10.6 9.6 11.9 10.6Q12.9 7.4 12 3.6Z';

StopAnim _flame(double cx, double base, [double s = 0.9, double period = 0.9]) {
  final m = Float64List.fromList([
    s,
    0,
    0,
    0,
    0,
    s,
    0,
    0,
    0,
    0,
    1,
    0,
    cx - 12 * s,
    base - 16.2 * s,
    0,
    1,
  ]);
  final path = parseFlame().transform(m);
  final prims = [
    StripPrim(path, _w(0.9)),
    StripPrim(path, _w(1), strokeWidth: 1 * s, join: StrokeJoin.round),
  ];
  return StopAnim(_picture(prims), _bounds(prims), StopMotion.flick, period);
}

Path parseFlame() => fillD(_flameD, _C.near).path;

void _fire(_Rec rec, double cx) {
  rec.anim(_glow(cx, _gy - 7, 54, 24, 1.8));
  rec.one(ellipse(cx, _gy + 1.5, 30, 3.4, _w(0.2)));
  rec.one(
    strokeD(
      'M${cx - 7} ${_gy}L${cx + 7} ${_gy - 3}M${cx - 7} ${_gy - 3}L${cx + 7} $_gy',
      _C.near,
      1.8,
      round: true,
    ),
  );
  rec.anim(_flame(cx, _gy - 2.6));
}

/// A figure: the same 1.35 dp line and 2.3 dp head as the walking party, and
/// a warm copy of its outline 0.7 dp toward the light, so only a rim of it
/// shows on the side of the fire.
List<StripPrim> _fig(
  String d,
  Pt head,
  double? lightX,
  double x, [
  double alpha = 1,
]) {
  final side = lightX == null ? 0 : (lightX - x).sign;
  final path = parseFromD(d);
  final headPath = Path()
    ..addOval(Rect.fromCircle(center: Offset(head.$1, head.$2), radius: 2.3));
  final out = <StripPrim>[];
  if (side != 0) {
    out.addAll(
      translated(
        [
          StripPrim(
            path,
            _w(0.95),
            strokeWidth: 1,
            cap: StrokeCap.round,
            join: StrokeJoin.round,
          ),
          StripPrim(headPath, _w(0.95), strokeWidth: 1),
        ],
        side * 0.7,
        -0.2,
      ),
    );
  }
  final figure = _C.fig.withValues(alpha: alpha);
  out.addAll([
    StripPrim(
      path,
      figure,
      strokeWidth: 1.35,
      cap: StrokeCap.round,
      join: StrokeJoin.round,
    ),
    StripPrim(headPath, _C.mid),
    StripPrim(headPath, figure, strokeWidth: 1.35),
  ]);
  return out;
}

Path parseFromD(String d) => fillD(d, _C.near).path;

String _p(Pt q) => '${n(q.$1)} ${n(q.$2)}';

enum _Sit { reach, sway, laugh, mug }

StopAnim _sitter(
  double x,
  int d,
  _Sit kind,
  double? lightX, {
  double lift = 0,
  double delay = 0,
  double floor = _gy,
  double scale = 1,
}) {
  final gl = floor - 1 - lift;
  final hip = (x, gl - 1.4);
  final knee = lift != 0 ? (x + d * 4.2, gl - 1.6) : (x + d * 4.4, gl - 5.6);
  final foot = lift != 0
      ? (knee.$1 + d * 0.8, floor - 1)
      : (x + d * 7.6, floor - 1);
  final lean = kind == _Sit.reach ? -d * 1.6 : d * 1.3;
  final sh = (x + lean, hip.$2 - 8);
  final hd = (sh.$1 + (kind == _Sit.laugh ? -d * 0.9 : d * 0.8), sh.$2 - 3.5);
  final s1 = (sh.$1, sh.$2 + 1);
  final h1 = switch (kind) {
    _Sit.reach => (s1.$1 - d * 6.2, s1.$2 + 6.8),
    _Sit.mug => (s1.$1 + d * 4.6, s1.$2 + 2.4),
    _ => (knee.$1 - d * 0.3, knee.$2 + 0.4),
  };
  final h2 = (knee.$1 - d * 1.2, knee.$2 + 1.2);
  final dd =
      'M${_p(hip)}L${_p(sh)}M${_p(hip)}L${_p(knee)}L${_p(foot)}M${_p(s1)}L${_p(h1)}M${_p(s1)}L${_p(h2)}';
  var prims = _fig(dd, hd, lightX, x);
  if (scale != 1) prims = _scaled(prims, x, floor, scale);
  final (motion, period) = switch (kind) {
    _Sit.laugh => (StopMotion.laugh, 2.8),
    _Sit.reach => (d > 0 ? StopMotion.reachLeft : StopMotion.reachRight, 6.5),
    _ => (StopMotion.sway, 3.2 + delay.abs() * 0.3),
  };
  return StopAnim(
    _picture(prims),
    _bounds(prims),
    motion,
    period,
    delay: delay,
  );
}

/// `translate(x y) scale(s) translate(-x -y)`.
List<StripPrim> _scaled(List<StripPrim> prims, double x, double y, double s) {
  final m = Float64List.fromList([
    s,
    0,
    0,
    0,
    0,
    s,
    0,
    0,
    0,
    0,
    1,
    0,
    x - s * x,
    y - s * y,
    0,
    1,
  ]);
  return [for (final p in prims) p.transformed(m)];
}

/// A standing figure in the walking pose of phase [t], still.
List<StripPrim> _stander(
  double x,
  double? lightX, [
  double floor = _gy,
  double t = 0.046,
]) {
  final foot = floor - 1;
  final a = math.sin(t * 2 * math.pi) * 0.42;
  const leg = 8.0;
  final hip = (x, foot - leg * math.cos(a));
  final sh = (hip.$1 + 0.6, hip.$2 - 8);
  final d = StringBuffer('M${_p(hip)}L${_p(sh)}');
  for (final s in const [1, -1]) {
    final b = a * s;
    d.write('M${_p(hip)}l${n(math.sin(b) * leg)} ${n(math.cos(b) * leg)}');
    final r = -b * 0.8;
    d.write(
      'M${n(sh.$1)} ${n(sh.$2 + 1)}l${n(math.sin(r) * 6)} ${n(math.cos(r) * 6)}',
    );
  }
  return _fig(d.toString(), (sh.$1 + 0.5, sh.$2 - 3.6), lightX, x);
}

List<StripPrim> _tent(double x, double w, double h, int fireSide) => [
  poly([(x - w / 2, _gy), (x, _gy - h), (x + w / 2, _gy)], _C.mid),
  poly([(x - 3.6, _gy), (x, _gy - h * 0.55), (x + 3.6, _gy)], _C.dark),
  strokeD('M$x ${_gy - h}L${n(x + fireSide * w / 2)} $_gy', _w(0.62), 0.9),
  strokeD(
    'M$x ${_gy - h}l-1.6-2.4M$x ${_gy - h}l1.6-2.4M${n(x - w / 2)} ${_gy}l-4 0M${n(x + w / 2)} ${_gy}l4 0',
    _C.mid,
    1,
    round: true,
  ),
];

List<StripPrim> _leanTo(double x) => [
  strokeD(
    'M${x - 18} ${_gy}V${_gy - 21}M${x + 16} ${_gy}V${_gy - 10}',
    _C.mid,
    1.5,
    round: true,
  ),
  poly([
    (x - 23, _gy - 21.4),
    (x - 14, _gy - 23),
    (x + 26, _gy - 9),
    (x + 26, _gy - 6.4),
  ], _C.mid),
  strokeD(
    'M${x - 16} ${_gy - 21}l-3 -2.4M${x - 6} ${_gy - 18}l-2.4 -2.8M${x + 6} ${_gy - 14}l-2 -2.6M${x + 16} ${_gy - 10.6}l-2 -2.4',
    _C.mid,
    1,
    round: true,
  ),
  strokeD('M${x - 23} ${_gy - 21.4}L${x - 14} ${_gy - 23}', _w(0.55), 0.8),
];

List<StripPrim> _bag(double x) => [
  fillD('M${x - 3.6} ${_gy}q-.6-5.4 1.4-6.4h4.4q2 1 1.4 6.4z', _C.mid),
  strokeD('M${x - 1.2} ${_gy - 6.4}l1.2-1.8 1.2 1.8', _C.mid, 1),
];

List<StripPrim> _stump(double x) => [
  fillD('M${x - 4} ${_gy}v-5h8v5z', _C.mid),
  ellipse(x, _gy - 5, 4, 1.1, _C.line),
];

List<StripPrim> _oak(double x, double base, Color col) => [
  fillD(
    'M${x - 2} ${base}L${x - 1.1} ${base - 14}L${x + 1.1} ${base - 14}L${x + 2} ${base}Z',
    col,
  ),
  for (final (dx, dy, r) in const [
    (0.0, -24.0, 8.4),
    (-7.4, -19.4, 6.6),
    (7.6, -19.8, 6.8),
    (-3.6, -28.0, 6.2),
    (4.4, -27.6, 6.4),
  ])
    circle(x + dx, base + dy, r, col),
];

// ── the halt ──────────────────────────────────────────────────────────────

/// A halt. With [environment] false the forest behind the camp is left out
/// — the fir rows, the trunks, the oak — and only the camp itself is built:
/// the tent or the lean-to, the fire and the company, which stand in front
/// of whichever biome the party stopped in.
StopScene buildCamp(StopKind kind, {required bool environment}) {
  final pieces = <StopPiece>[];
  void add(int? order, void Function(_Rec r) fn) {
    final rec = _Rec();
    fn(rec);
    pieces.add(rec.piece(order));
  }

  final (farSeed, trunkX, trunkSeed) = switch (kind) {
    StopKind.camp1 => (21, 250.0, 5),
    StopKind.camp2 => (47, 290.0, 9),
    _ => (63, 230.0, 13),
  };
  if (environment) {
    add(
      0,
      (r) => r.add(
        _firs(
          186,
          412,
          _C.far,
          kind == StopKind.camp3 ? 0.34 : (kind == StopKind.camp2 ? 0.3 : 0.32),
          kind == StopKind.camp3 ? 0.52 : 0.5,
          _gy - 8,
          farSeed,
        ),
      ),
    );
    add(null, (r) => _fog(r, 16, _gy - 2));
    add(
      1,
      (r) => r.add(
        _trunks(
          trunkX,
          kind == StopKind.camp3 ? 360 : 412,
          _C.midfar,
          trunkSeed,
        ),
      ),
    );
    add(null, (r) => _fog(r, 24, _gy + 1, 0.36));
  }
  add(null, (r) => _ground(r));

  switch (kind) {
    case StopKind.camp1:
      add(2, (r) => r.add([..._tent(262, 30, 20, 1), ..._bag(284)]));
      if (environment) {
        add(
          3,
          (r) => r.add(_firs(378, 412, _C.mid, 0.56, 0.64, _gy, 31, (2, 6))),
        );
      }
      add(4, (r) => _fire(r, 330));
      add(5, (r) {
        r.anim(_sitter(300, 1, _Sit.reach, 330, delay: -1.2));
        r.anim(_sitter(313, 1, _Sit.sway, 330, delay: -0.4));
        r.anim(_sitter(352, -1, _Sit.laugh, 330, delay: -0.9));
      });
    case StopKind.camp2:
      if (environment) add(2, (r) => r.add(_oak(244, _gy, _C.mid)));
      add(3, (r) => r.add([..._tent(388, 26, 18, -1), ..._bag(370)]));
      add(4, (r) => _fire(r, 328));
      add(5, (r) {
        r.anim(_sitter(296, 1, _Sit.reach, 328, delay: -3));
        r.anim(_sitter(310, 1, _Sit.sway, 328, delay: -1.7));
        r.anim(_sitter(350, -1, _Sit.laugh, 328, delay: -0.2));
      });
    case StopKind.camp3:
      if (environment) {
        add(
          2,
          (r) => r.add([
            ..._firs(214, 244, _C.mid, 0.56, 0.66, _gy, 71, (1, 4)),
            ..._stump(262),
          ]),
        );
      }
      add(3, (r) => r.add([..._leanTo(386), ..._bag(368)]));
      add(4, (r) => _fire(r, 322));
      add(5, (r) {
        r.anim(_sitter(294, 1, _Sit.reach, 322, delay: -2.2));
        r.anim(_sitter(340, -1, _Sit.sway, 322, delay: -0.6));
        r.anim(_sitter(354, -1, _Sit.laugh, 322, delay: -1.4));
      });
    case StopKind.tavern:
      throw ArgumentError('the tavern is not a halt');
  }
  return StopScene('ПРИВАЛ', pieces);
}

// ── the tavern (15f) ──────────────────────────────────────────────────────

StopScene buildTavern() {
  final pieces = <StopPiece>[];
  void add(int? order, void Function(_Rec r) fn) {
    final rec = _Rec();
    fn(rec);
    pieces.add(rec.piece(order));
  }

  const hx = 348.0;
  final p10 = hex('#101214'),
      p0f = hex('#0F1113'),
      p0e = hex('#0E1012'),
      p0b = hex('#0B0C0E');

  // The room: wall, light, beams, floor.
  add(null, (r) {
    r.one(rect(0, 0, kStopWidth, _gy, hex('#1A1C20')));
    final d = StringBuffer();
    for (var x = 4; x < kStopWidth; x += 8) {
      d.write('M$x 5V$_gy');
    }
    r.one(strokeD(d.toString(), hex('#141619'), 0.8));
    r.anim(_glow(hx, 34, 190, 70, 2.4));
    r.one(rect(0, 0, kStopWidth, 5, hex('#0D0E10')));
    r.one(rect(212, 0, 4, _gy, p0f));
    r.one(rect(392, 0, 4, _gy, p0f));
    r.one(rect(0, _gy, kStopWidth, _h - _gy, _C.ground));
    r.one(
      strokeD(
        'M0 ${_gy + 3.4}H${kStopWidth}M0 ${_gy + 7}H$kStopWidth',
        hex('#15171A'),
        0.6,
      ),
    );
    r.one(ellipse(300, _gy + 3, 80, 5, _w(0.18)));
  });

  // Shelves, the keeper, the counter.
  add(0, (r) {
    r.one(rect(218, 13, 44, 1.4, p0f));
    r.one(rect(218, 22, 44, 1.4, p0f));
    const bottles = [
      (222.0, 13.0),
      (228.0, 13.0),
      (236.0, 13.0),
      (244.0, 13.0),
      (252.0, 13.0),
      (224.0, 22.0),
      (232.0, 22.0),
      (248.0, 22.0),
      (256.0, 22.0),
    ];
    for (var i = 0; i < bottles.length; i++) {
      final (x, y) = bottles[i];
      if (i % 3 == 2) {
        r.one(fillD('M$x ${y}V${y - 4.6}l.9-1.3.9 1.3V${y}z', p10));
      } else {
        r.one(rect(x, y - 3.4, 3.2, 3.4, p10));
        r.one(strokeD('M${x + 3.2} ${y - 2.6}h1v1.8h-1', p10, 0.7));
      }
    }
    r.add(_stander(244, hx, 45, 0.1));
    r.one(rect(216, 29, 50, 2.6, hex('#101215')));
    r.one(rect(218, 31.6, 46, _gy - 31.6, hex('#131518')));
    final d = StringBuffer();
    for (var x = 228; x < 264; x += 11) {
      d.write('M$x 33v11');
    }
    r.one(strokeD(d.toString(), p0e, 0.8));
    r.one(rect(226, 25.6, 3.2, 3.4, p10));
    r.one(rect(256, 25.6, 3.2, 3.4, p10));
  });

  // Barrels at the edge of the shadow, and by the hearth.
  add(1, (r) {
    List<StripPrim> barrel(double x, double b, double s) => _scaled(
      [
        fillD('M${x - 5.4} ${b}q-1.2-5 0-10h10.8q1.2 5 0 10z', p0f),
        strokeD(
          'M${x - 5.8} ${b - 3}h11.6M${x - 5.8} ${b - 7}h11.6',
          hex('#20242A'),
          0.7,
        ),
      ],
      x,
      b,
      s,
    );
    r.add([
      ...barrel(198, _h - 1, 1.35),
      ...barrel(214, _h - 1, 1.35),
      ...barrel(206, _h - 14.4, 1.3),
      ...barrel(404, _gy, 1),
      ...barrel(404, _gy - 10, 1),
    ]);
  });

  // The hearth: masonry, an arch of wedges, three tongues of flame.
  add(2, (r) {
    r.one(rect(326, 5, 44, 11, hex('#131518')));
    r.one(rect(318, 15.4, 60, 2.4, p0f));
    r.one(fillD('M320 ${_gy}V17.8H376V${_gy}Z', hex('#1C1F23')));
    r.one(
      strokeD(
        'M320 24h56M320 31h7M369 31h7M320 38h7M369 38h7M326 17.8v6.2M340 17.8v6.2M356 17.8v6.2M370 17.8v6.2M323 24v7M373 24v7M323 31v7M373 31v7',
        hex('#2A2E34'),
        0.7,
      ),
    );
    final arch = fillD(
      'M330 ${_gy}V32A18 13 0 0 1 366 32V${_gy}Z',
      _C.near,
    ).path;
    r.paint(
      (c) => c.drawPath(
        arch,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, 19),
            const Offset(0, _gy),
            [_w(0.45), _w(0.9)],
          ),
      ),
    );
    r.one(strokeD('M330 32A18 13 0 0 1 366 32', hex('#2A2E34'), 2.2));
    r.one(
      strokeD(
        'M333 25.6l-2-2.4M341 21.4l-1-2.8M348 20v-3M355 21.4l1-2.8M363 25.6l2-2.4',
        hex('#1C1F23'),
        1,
      ),
    );
    r.one(
      strokeD(
        'M336 ${_gy}L360 ${_gy - 4}M336 ${_gy - 4}L360 $_gy',
        _C.near,
        2.2,
        round: true,
      ),
    );
    r.anim(_flame(hx, _gy - 3.4, 1.3));
    r.anim(_flame(340, _gy - 2.6, 0.7));
    r.anim(_flame(357, _gy - 2.6, 0.62));
  });

  // A guest on the bench by the wall.
  add(3, (r) {
    r.anim(_sitter(388, -1, _Sit.sway, hx, lift: 5, delay: -2));
    r.one(rect(380, 39.6, 12, 1.4, p0e));
  });

  // The company at the table, the largest thing in the frame, and the candle.
  add(4, (r) {
    r.anim(
      _sitter(
        252,
        1,
        _Sit.mug,
        hx,
        lift: 5.6,
        delay: -0.7,
        floor: 53,
        scale: 1.3,
      ),
    );
    r.add(_scaled(_stander(284, hx, 50, 0.3), 284, 50, 1.26));
    r.anim(
      _sitter(
        318,
        -1,
        _Sit.laugh,
        hx,
        lift: 5.6,
        delay: -1.3,
        floor: 53,
        scale: 1.3,
      ),
    );
    r.one(rect(256, 39, 58, 2.8, p0b));
    r.one(strokeD('M262 41.8V${_h}M308 41.8V$_h', p0b, 2.2));
    for (final x in const [264.0, 276.0, 300.0]) {
      r.one(rect(x, 34.4, 4, 4.6, p10));
      r.one(strokeD('M${x + 4} 35.4h1.4v2.4h-1.4', p10, 0.9));
    }
    r.anim(_glow(290, 33, 26, 13, 1.6));
    r.one(rect(289, 33.4, 2.2, 5.6, _w(0.55)));
    final wick = fillD('M290.1 28.6q1.5 2.2 0 4.8q-1.5-2.6 0-4.8z', _w(0.95));
    r.anim(
      StopAnim(_picture([wick]), wick.path.getBounds(), StopMotion.flick, 0.8),
    );
  });

  return StopScene('ТАВЕРНА', pieces);
}

// ── motion ────────────────────────────────────────────────────────────────

double _ease(double t) =>
    t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;

/// Piecewise keyframes, eased within each segment as CSS eases them.
double _frames(double p, List<(double, double)> keys) {
  for (var i = 1; i < keys.length; i++) {
    if (p <= keys[i].$1) {
      final (p0, v0) = keys[i - 1];
      final (p1, v1) = keys[i];
      final t = p1 == p0 ? 1.0 : (p - p0) / (p1 - p0);
      return v0 + (v1 - v0) * _ease(t);
    }
  }
  return keys.last.$2;
}

/// Where a looping part stands at time [t] seconds: a transform about the
/// bottom-centre of its bounds, and an opacity.
({Float64List? m, double opacity}) motionAt(StopAnim a, double t) {
  final raw = (t - a.delay) / a.period;
  double cycle(bool alternate) {
    final k = raw.floor(), p = raw - k;
    return alternate && k.isOdd ? 1 - p : p;
  }

  final ox = a.bounds.center.dx, oy = a.bounds.bottom;
  Float64List about(double sx, double sy, double skewX, double rot, double ty) {
    // translate(o) · rotate · skewX · scale · translate(-o)
    final c = math.cos(rot), s = math.sin(rot), k = math.tan(skewX);
    final a11 = c * sx,
        a12 = c * k * sy - s * sy,
        a21 = s * sx,
        a22 = s * k * sy + c * sy;
    return Float64List.fromList([
      a11, a21, 0, 0, a12, a22, 0, 0, 0, 0, 1, 0, //
      ox - a11 * ox - a12 * oy, oy + ty - a21 * ox - a22 * oy, 0, 1,
    ]);
  }

  switch (a.motion) {
    case StopMotion.flick:
      final p = cycle(true);
      final sy = _frames(p, const [(0, 1), (0.5, 0.86), (1, 1.07)]);
      final sk = _frames(p, const [(0, 0), (0.5, -4), (1, 3)]);
      return (m: about(1, sy, radians(sk), 0, 0), opacity: 1);
    case StopMotion.glow:
      return (
        m: null,
        opacity: _frames(cycle(false), const [(0, 0.9), (0.5, 0.62), (1, 0.9)]),
      );
    case StopMotion.sway:
      final deg = _frames(cycle(true), const [(0, -2.4), (1, 2.4)]);
      return (m: about(1, 1, 0, radians(deg), 0), opacity: 1);
    case StopMotion.laugh:
      final y = _frames(cycle(false), const [
        (0, 0),
        (0.56, 0),
        (0.6, -0.9),
        (0.64, 0),
        (0.68, -0.9),
        (0.72, 0),
        (0.76, -0.9),
        (0.8, 0),
        (1, 0),
      ]);
      return (m: about(1, 1, 0, 0, y), opacity: 1);
    case StopMotion.reachLeft:
    case StopMotion.reachRight:
      final sign = a.motion == StopMotion.reachLeft ? -1 : 1;
      final deg = _frames(cycle(false), [
        (0, 0),
        (0.52, 0),
        (0.66, sign * 13.0),
        (0.82, sign * 13.0),
        (1, 0),
      ]);
      return (m: about(1, 1, 0, radians(deg), 0), opacity: 1);
  }
}

/// The veil over the strip on arrival: dark by 30 % of 1.8 s, held to 50 %,
/// gone by the end.
double veilAt(double t) {
  if (t >= 1.8) return 0;
  return _frames(t / 1.8, const [(0, 0), (0.3, 1), (0.5, 1), (1, 0)]);
}

/// How far a piece of order [order] has come in: 0 until it starts, then up
/// to 1 over 650 ms, 900 ms + 300 ms per step after arrival.
double pieceAt(int? order, double t) {
  if (order == null) return 1;
  final start = 0.9 + order * 0.3;
  if (t <= start) return 0;
  final p = ((t - start) / 0.65).clamp(0.0, 1.0);
  return 1 - math.pow(1 - p, 2).toDouble();
}

/// Paints [scene] at stop time [t], shifted by [dx] so it keeps to the right
/// edge of a strip narrower than the prototype's.
void paintStop(Canvas canvas, StopScene scene, double t, {required double dx}) {
  canvas.save();
  canvas.translate(dx, 0);
  for (final piece in scene.pieces) {
    final k = pieceAt(piece.order, t);
    if (k <= 0) continue;
    canvas.save();
    canvas.translate(2 * (1 - k), 0);
    if (k < 1) {
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, k));
    }
    canvas.drawPicture(piece.still);
    for (final a in piece.anims) {
      final m = motionAt(a, t);
      if (m.opacity < 1) {
        canvas.saveLayer(
          null,
          Paint()..color = Color.fromRGBO(0, 0, 0, m.opacity),
        );
      } else {
        canvas.save();
      }
      if (m.m != null) canvas.transform(m.m!);
      canvas.drawPicture(a.picture);
      canvas.restore();
    }
    if (k < 1) canvas.restore();
    canvas.restore();
  }
  canvas.restore();
}

/// The shadow over the left of a stop and its label on it.
void paintStopShade(
  Canvas canvas,
  Size size,
  String label,
  TextStyle style,
  double t,
) {
  final dark = _C.dark;
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, 0),
        [dark, dark, dark.withValues(alpha: 0.72), dark.withValues(alpha: 0)],
        const [0, 0.32, 0.47, 0.6],
      ),
  );
  final tp = TextPainter(
    text: TextSpan(text: 'ОСТАНОВКА · $label', style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  // The prototype sets the baseline at y = 31.
  tp.paint(
    canvas,
    Offset(
      16,
      31 - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic),
    ),
  );
  final veil = veilAt(t);
  if (veil > 0) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark.withValues(alpha: veil),
    );
  }
}

/// The sky of a stop in the forest, the prototype's own.
void paintStopSky(Canvas canvas, Size size) {
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        [StripColors.skyTop, StripColors.skyHor, StripColors.skyHor],
        const [0, 0.68, 1],
      ),
  );
}
