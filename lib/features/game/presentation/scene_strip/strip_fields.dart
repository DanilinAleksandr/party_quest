import 'dart:math' as math;
import 'dart:ui';

import 'strip_kit.dart';
import 'strip_shapes.dart';

/// The fields of the prologue (18): the open country the party walks out
/// into from the house — ported from `forest-strip.js` like the rest of the
/// strip, numbers and all.

/// The fields' tone (`TONES.fields`): lighter and roomier than the forest.
final fieldsTone = PathTone(
  skyTop: '#3E434B',
  skyHor: '#6E747D',
  skyLow: '#4C5159',
  hor: 0.42,
  far: '#60666F',
  midfar: '#4A4F57',
  mid: '#2B2E33',
  fog: '#7A808A',
  fogA: 0.34,
  fog2: '#585E67',
  fog2A: 0.24,
);

/// How dense the fields are (`FDENS`): a multiplier on the gaps. The
/// prologue starts at [kFieldsDense] by the house and thins to [kFields]
/// in the open — see `StripWorld.fieldsDensity`.
const double kFieldsDense = 1.7;
const double kFields = 1.0;

double _yAt(List<Pt> pts, double x) {
  for (var i = 1; i < pts.length; i++) {
    if (pts[i].$1 >= x) {
      final a = pts[i - 1], b = pts[i];
      final dx = (b.$1 - a.$1) == 0 ? 1 : (b.$1 - a.$1);
      return a.$2 + (b.$2 - a.$2) * (x - a.$1) / dx;
    }
  }
  return pts.last.$2;
}

/// A round crown: an ellipse and seven to ten circles about it.
List<StripPrim> crown(Rng r, double cx, double cy, double rad, Color col) {
  final prims = [ellipse(cx, cy, rad * 0.85, rad * 0.72, col)];
  final count = 7 + (r() * 4).floor();
  for (var i = 0; i < count; i++) {
    final a = (i / count) * math.pi * 2 + r() * 0.5,
        d = rad * (0.38 + r() * 0.22),
        rr = rad * (0.4 + r() * 0.2);
    prims.add(
      circle(cx + math.cos(a) * d * 1.15, cy + math.sin(a) * d * 0.72, rr, col),
    );
  }
  return prims;
}

StripShape crownTree(
  Rng r,
  StripGeo g,
  Color col,
  double b,
  double hMin,
  double hMax,
) {
  final h = g.h * (hMin + r() * (hMax - hMin)),
      rad = h * (0.3 + r() * 0.07),
      w = rad * 2.5,
      c = w / 2,
      lean = (r() - 0.5) * rad * 0.3,
      cy = b - h + rad * 0.8,
      tw = math.max(0.8, h * 0.05);
  final trunk = poly([
    (c - tw * 1.8, b),
    (c - tw * 0.9, b - h * 0.18),
    (c - tw * 0.6 + lean, cy + rad * 0.2),
    (c + tw * 0.6 + lean, cy + rad * 0.2),
    (c + tw * 0.9, b - h * 0.18),
    (c + tw * 1.8, b),
  ], col);
  final branches = strokeD(
    'M${n(c + lean * 0.6)} ${n(cy + rad * 0.7)}'
    'L${n(c - rad * 0.5 + lean)} ${n(cy + rad * 0.2)}'
    'M${n(c + lean * 0.6)} ${n(cy + rad * 0.8)}'
    'L${n(c + rad * 0.55 + lean)} ${n(cy + rad * 0.3)}',
    col,
    tw * 0.9,
    round: true,
  );
  return StripShape(w, 'дерево', [
    trunk,
    branches,
    ...crown(r, c + lean, cy, rad, col),
  ]);
}

StripShape treeGroup(
  Rng r,
  StripGeo g,
  Color col,
  double b,
  double hMin,
  double hMax,
  int nMax,
) {
  final count = 2 + (r() * (nMax - 1)).floor();
  var x = 0.0, w = 0.0;
  final prims = <StripPrim>[];
  for (var i = 0; i < count; i++) {
    final t = crownTree(r, g, col, b, hMin, hMax);
    prims.addAll(translated(t.prims, x, 0));
    w = math.max(w, x + t.w);
    x += t.w * (0.45 + r() * 0.25);
  }
  return StripShape(w, 'группа деревьев', prims);
}

StripShape farFields(Rng r, StripGeo g, PathTone t, double b) {
  final w = g.h * (1.6 + r() * 2), h = g.h * (0.06 + r() * 0.1);
  const count = 5;
  final pts = <Pt>[(0, b)];
  for (var i = 1; i < count; i++) {
    pts.add((
      w * i / count,
      b - h * (0.5 + r() * 0.5) * math.sin(math.pi * i / count),
    ));
  }
  pts.add((w, b));
  final prims = [poly(pts, t.far)];
  final furrows = StringBuffer();
  for (var k = 1; k <= 3; k++) {
    furrows.write('M');
    furrows.write(
      pts.map((p) => '${n(p.$1)} ${n(p.$2 + (b - p.$2) * k / 4)}').join('L'),
    );
  }
  prims.add(strokeD(furrows.toString(), hex('#585E67'), 0.5));
  final groves = (r() * 3).floor();
  for (var i = 0; i < groves; i++) {
    final x = w * (0.2 + r() * 0.6),
        y = _yAt(pts, x) + 0.6,
        tree = crownTree(r, g, t.far, 0, 0.1, 0.16);
    prims.addAll(translated(tree.prims, x - tree.w / 2, y));
  }
  if (r() < 0.3) {
    final x = w * (0.3 + r() * 0.4), y = _yAt(pts, x) + 0.4;
    prims.add(
      poly([
        (x, y),
        (x, y - 3.4),
        (x + 3, y - 5.6),
        (x + 6, y - 3.4),
        (x + 6, y),
        (x + 7, y),
        (x + 7, y - 2.6),
        (x + 11, y - 4.2),
        (x + 15, y - 2.6),
        (x + 15, y),
      ], t.far),
    );
  }
  return StripShape(w, 'поля', prims);
}

StripShape stog(Rng r, StripGeo g, Color col, double b) {
  final h = g.h * (0.16 + r() * 0.08), w = h * 0.8, c = w / 2;
  return StripShape(w, 'стог', [
    fillD(
      'M0 ${n(b)}Q${n(-w * 0.05)} ${n(b - h * 0.6)} ${n(c)} ${n(b - h)}'
      'Q${n(w * 1.05)} ${n(b - h * 0.6)} ${n(w)} ${n(b)}Z',
      col,
    ),
    strokeD('M${n(c)} ${n(b - h)}v-3.4', col, 1),
  ]);
}

StripShape kopna(Rng r, StripGeo g, Color col, double b) {
  final w = 12 + r() * 9, h = w * (0.7 + r() * 0.2);
  return StripShape(w + 2, 'копна', [
    fillD(
      'M0 ${n(b)}C${n(-w * 0.04)} ${n(b - h * 1.25)} ${n(w * 1.04)} '
      '${n(b - h * 1.25)} ${n(w)} ${n(b)}Z',
      col,
    ),
    strokeD('M${n(w / 2)} ${n(b - h * 0.92)}v-3', col, 1),
  ]);
}

StripShape scarecrow(Rng r, StripGeo g, Color col, double b) {
  final h = g.h * (0.44 + r() * 0.1),
      arm = b - h * 0.72,
      tilt = (r() - 0.5) * 2.4;
  const c = 9.0;
  return StripShape(18, 'пугало', [
    strokeD(
      'M$c ${n(b)}V${n(b - h + 4)}M${c - 8} ${n(arm)}L${c + 8} ${n(arm + tilt)}',
      col,
      1.3,
      round: true,
    ),
    poly([
      (c - 3, arm - 1),
      (c + 3, arm - 1),
      (c + 4, arm + h * 0.3),
      (c + 1.5, arm + h * 0.25),
      (c, arm + h * 0.32),
      (c - 1.5, arm + h * 0.24),
      (c - 4, arm + h * 0.3),
    ], col),
    poly([
      (c - 8, arm - 0.6),
      (c - 5, arm - 0.6),
      (c - 5.4, arm + 3.6),
      (c - 6.4, arm + 2.6),
      (c - 7.6, arm + 4),
    ], col),
    poly([
      (c + 5, arm + tilt * 0.6 - 0.6),
      (c + 8, arm + tilt - 0.6),
      (c + 7.8, arm + tilt + 3.4),
      (c + 6.6, arm + tilt + 2.4),
      (c + 5.4, arm + tilt + 3.8),
    ], col),
    circle(c, b - h + 4.6, 2.3, col),
    strokeD('M${c - 4.4} ${n(b - h + 3)}h8.8', col, 1.1),
    fillD('M${c - 2.2} ${n(b - h + 3)}l.6 -3h3.2l.6 3z', col),
  ]);
}

/// A wattle fence by the path.
StripShape pletyen(Rng r, StripGeo g) {
  final w = 30 + r() * 40, b = g.gy + 0.5, h = 10 + r() * 2, sp = 6 + r() * 2;
  final col = StripColors.mid, xs = <double>[];
  for (var x = 1.0; x < w; x += sp) {
    xs.add(x);
  }
  final stakes = StringBuffer(), weave = StringBuffer();
  for (final x in xs) {
    stakes.write(
      'M${n(x)} ${n(b)}L${n(x + (r() - 0.5))} ${n(b - h - 1.6 - r() * 1.4)}',
    );
  }
  for (var k = 0; k < 4; k++) {
    final y = b - 1.8 - k * (h - 2) / 3.2;
    weave.write('M${n(xs[0])} ${n(y)}');
    for (var i = 1; i < xs.length; i++) {
      final mx = (xs[i - 1] + xs[i]) / 2;
      weave.write(
        'Q${n(mx)} ${n(y + ((i + k) % 2 == 1 ? 1.4 : -1.4))} ${n(xs[i])} ${n(y)}',
      );
    }
  }
  return StripShape(w, 'плетень', [
    strokeD(weave.toString(), col, 1.5),
    strokeD(stakes.toString(), col, 1.3, round: true),
  ]);
}

/// A rail fence: posts and two sagging rails, one now and then down.
StripShape zherdi(Rng r, StripGeo g) {
  final count = 2 + (r() * 3).floor(),
      sp = 14 + r() * 6,
      w = count * sp + 2,
      b = g.gy + 0.5;
  final col = StripColors.mid, tops = <Pt>[];
  final posts = StringBuffer(), rails = StringBuffer();
  for (var i = 0; i <= count; i++) {
    final x = 1 + i * sp, t = (r() - 0.5) * 1.6, hh = 11 + r() * 2;
    tops.add((x + t, hh));
    posts.write('M${n(x)} ${n(b)}L${n(x + t)} ${n(b - hh)}');
  }
  for (final q in const [0.4, 0.75]) {
    for (var i = 0; i < count; i++) {
      if (r() < 0.12) {
        rails.write(
          'M${n(tops[i].$1)} ${n(b - tops[i].$2 * q)}'
          'l${n(sp * 0.6)} ${n(tops[i].$2 * q * 0.7)}',
        );
        continue;
      }
      rails.write(
        'M${n(tops[i].$1 - 1.5)} ${n(b - tops[i].$2 * q)}'
        'Q${n(tops[i].$1 + sp / 2)} ${n(b - tops[i].$2 * q + 0.9)} '
        '${n(tops[i + 1].$1 + 1.5)} ${n(b - tops[i + 1].$2 * q)}',
      );
    }
  }
  return StripShape(w, 'жерди', [
    strokeD(posts.toString(), col, 1.7, round: true),
    strokeD(rails.toString(), col, 1.1, round: true),
  ]);
}

/// A picket fence.
StripShape palisade(Rng r, StripGeo g) {
  final w = 20 + r() * 34, b = g.gy + 0.5, h = 8 + r() * 2;
  final col = StripColors.mid, d = StringBuffer();
  for (var x = 1.0; x < w - 1; x += 3) {
    if (r() < 0.08) continue;
    final hh = h * (0.92 + r() * 0.12);
    d.write(
      'M${n(x - 0.8)} ${n(b)}V${n(b - hh)}L${n(x)} ${n(b - hh - 1.4)}'
      'L${n(x + 0.8)} ${n(b - hh)}V${n(b)}Z',
    );
  }
  return StripShape(w, 'штакетник', [
    fillD(d.toString(), col),
    strokeD(
      'M0 ${n(b - h * 0.3)}H${n(w)}M0 ${n(b - h * 0.75)}H${n(w)}',
      col,
      1,
    ),
  ]);
}

/// A boundary stone.
StripShape stone(Rng r, StripGeo g) {
  final b = g.gy + 0.6, w = 4 + r() * 3, h = 5 + r() * 3;
  return StripShape(w + 2, 'межевой камень', [
    poly([
      (0, b),
      (0.3, b - h * 0.85),
      (w * 0.4, b - h),
      (w, b - h * 0.8),
      (w + 0.4, b),
    ], StripColors.mid),
  ]);
}

/// A well: a log box, two posts, a little roof and a bucket.
StripShape well(StripGeo g) {
  final b = g.gy + 0.5, col = StripColors.mid;
  const x0 = 4.0, bw = 14.0;
  return StripShape(22, 'колодец', [
    rect(x0, b - 7.5, bw, 7.5, col),
    strokeD(
      'M$x0 ${n(b - 2.5)}h${bw}M$x0 ${n(b - 5)}h$bw',
      hex('#2C3036'),
      0.5,
    ),
    strokeD('M${x0 - 0.6} ${n(b - 7.5)}h${bw + 1.2}', hex('#363B43'), 0.8),
    strokeD(
      'M${x0 + 1.5} ${n(b - 7.5)}V${n(b - 21)}'
      'M${x0 + bw - 1.5} ${n(b - 7.5)}V${n(b - 21)}',
      col,
      1.5,
    ),
    poly([
      (x0 - 2, b - 20.4),
      (x0 + bw / 2, b - 26),
      (x0 + bw + 2, b - 20.4),
    ], hex('#16181B')),
    strokeD('M${x0 + 1.5} ${n(b - 15)}H${x0 + bw + 2.6}v3', col, 1.2),
    strokeD('M${x0 + bw / 2} ${n(b - 15)}V${n(b - 10.5)}', hex('#3A3F47'), 0.5),
    fillD('M${x0 + bw / 2 - 1.6} ${n(b - 10.5)}h3.2l-.5 2.6h-2.2Z', col),
  ]);
}

/// Big rails in the near plane.
StripShape zherdiNear(Rng r, StripGeo g) {
  final count = 1 + (r() * 2).floor(),
      sp = 34 + r() * 14,
      w = count * sp + 4,
      b = g.h + 2;
  final tops = <Pt>[], posts = StringBuffer(), rails = StringBuffer();
  for (var i = 0; i <= count; i++) {
    final x = 2 + i * sp, hh = g.h * (0.42 + r() * 0.14);
    tops.add((x, hh));
    posts.write('M${n(x)} ${n(b)}L${n(x + (r() - 0.5) * 3)} ${n(b - hh)}');
  }
  for (var i = 0; i < count; i++) {
    for (final q in const [0.45, 0.8]) {
      rails.write(
        'M${n(tops[i].$1 - 3)} ${n(b - tops[i].$2 * q)}'
        'Q${n(tops[i].$1 + sp / 2)} ${n(b - tops[i].$2 * q + 2)} '
        '${n(tops[i + 1].$1 + 3)} ${n(b - tops[i + 1].$2 * q)}',
      );
    }
  }
  return StripShape(w, 'жерди', [
    strokeD(posts.toString(), StripColors.near, 3.6, round: true),
    strokeD(rails.toString(), StripColors.near, 2.4, round: true),
  ]);
}

StripShape bushNear(Rng r, StripGeo g) {
  final rad = 9 + r() * 7;
  return StripShape(
    rad * 2.4,
    'куст',
    crown(r, rad * 1.2, g.h + rad * 0.25, rad, StripColors.near),
  );
}

// ── the house the party leaves (18a/18b) ─────────────────────────────────

/// The prologue's timings and places (`ForestStrip.PRO`), in seconds from
/// the start and in the prototype's 412-wide coordinates.
abstract final class Prologue {
  static const double doorOpenFrom = 0.5, doorOpenTo = 1.1;
  static const double firstExit = 0.8, exitEvery = 0.35;
  static const double walk = 36, center = 206, ramp = 0.8;
  static const double doorCloseFrom = 3.2, doorCloseTo = 3.8;
  static const double doorX = 46;

  /// The yard: the house and its well, where the first fill puts nothing.
  static const double yardFrom = 8, yardTo = 132;

  /// Where the yard's well stands.
  static const double wellX = 102;
}

const double _houseX = 18, _houseW = 46;
const double _porch = _houseX + _houseW + 9;
final Color _warm = const Color.fromRGBO(185, 122, 82, 1);

/// The house and its well, all that stands still in them.
StripShape house(StripGeo g) {
  final b = g.gy, top = b - 28, dx = Prologue.doorX, mid = StripColors.mid;
  const x = _houseX, w = _houseW, pr = _porch;
  final seams = StringBuffer();
  final prims = <StripPrim>[rect(x, top, w, b - top, mid)];
  for (var y = top + 3.4; y < b; y += 3.4) {
    seams.write('M$x ${n(y)}h$w');
    prims
      ..add(rect(x - 1.6, y - 2.7, 1.8, 2.4, mid))
      ..add(rect(x + w - 0.2, y - 2.7, 1.8, 2.4, mid));
  }
  prims
    ..add(strokeD(seams.toString(), hex('#17191C'), 0.6))
    ..add(
      poly([
        (x - 5, b - 27),
        (x + w / 2, b - 42),
        (x + w + 5, b - 27),
      ], hex('#111316')),
    )
    ..add(
      strokeD(
        'M${x - 5} ${b - 27}L${x + w / 2} ${b - 42}L${x + w + 5} ${b - 27}',
        hex('#2C3036'),
        0.8,
      ),
    )
    ..add(rect(x + 32, b - 41, 4.4, 6, hex('#111316')))
    ..add(rect(x + w / 2 - 2, b - 35, 4, 3.4, hex('#0A0B0D')))
    ..add(rect(x + 6, b - 20, 10, 9, _warm.withValues(alpha: 0.78)))
    ..add(strokeD('M${x + 11} ${b - 20}v9M${x + 6} ${b - 15.5}h10', mid, 1))
    ..add(rect(x + 3.4, b - 20.6, 2.6, 10.2, hex('#121417')))
    ..add(rect(x + 16, b - 20.6, 2.6, 10.2, hex('#121417')))
    ..add(rect(x + 5, b - 10.6, 12, 1.2, hex('#121417')))
    ..add(rect(dx - 3, b - 2.4, pr - dx + 3, 2.4, hex('#16181B')))
    ..add(rect(pr, b - 1.2, 3, 1.2, hex('#16181B')))
    ..add(
      poly([
        (dx - 4, b - 28.4),
        (pr + 1.5, b - 26.4),
        (pr + 1.5, b - 25.2),
        (dx - 4, b - 27.2),
      ], hex('#111316')),
    )
    ..add(strokeD('M$pr ${b - 25.8}V${b - 2.4}', hex('#16181B'), 1.3))
    ..add(rect(dx, b - 26.4, 10, 24, hex('#0A0B0D')))
    ..addAll(translated(well(g).prims, Prologue.wellX, 0));
  return StripShape(Prologue.wellX + 22, 'дом', prims);
}

/// What moves on the house at [time] seconds into the prologue, drawn at the
/// house's own origin: the warm light in the doorway and on the porch, the
/// door turning on its left hinge, the smoke from the chimney.
void paintHouseMotion(Canvas canvas, StripGeo g, double time) {
  final b = g.gy, dx = Prologue.doorX;
  final open =
      _smooth(
        (time - Prologue.doorOpenFrom) /
            (Prologue.doorOpenTo - Prologue.doorOpenFrom),
      ) *
      (1 -
          _smooth(
            (time - Prologue.doorCloseFrom) /
                (Prologue.doorCloseTo - Prologue.doorCloseFrom),
          ));
  if (open > 0) {
    canvas.drawRect(
      Rect.fromLTWH(dx, b - 26.4, 10, 24),
      Paint()..color = _warm.withValues(alpha: 0.7 * open),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(dx + 10, b + 0.6), width: 32, height: 4.8),
      Paint()..color = _warm.withValues(alpha: 0.32 * open),
    );
  }
  canvas.save();
  canvas.translate(dx, 0);
  canvas.scale(1 - open * 0.82, 1);
  canvas.translate(-dx, 0);
  canvas.drawRect(
    Rect.fromLTWH(dx, b - 26.4, 10, 24),
    Paint()..color = hex('#24282D'),
  );
  strokeD(
    'M${dx + 3.3} ${b - 26.4}v24M${dx + 6.7} ${b - 26.4}v24'
    'M$dx ${b - 20}h10M$dx ${b - 8}h10',
    hex('#17191C'),
    0.6,
  ).paint(canvas);
  canvas.drawCircle(
    Offset(dx + 8.4, b - 14),
    0.7,
    Paint()..color = hex('#4A5058'),
  );
  canvas.restore();
  // Smoke: three puffs a third of a cycle apart, rising and swelling
  // (`@keyframes smoke`, 3.3 s, as the village chimneys).
  for (final delay in const [0.0, 1.1, 2.2]) {
    final p = ((time + delay) % 3.3) / 3.3;
    final opacity = p < 0.15 ? 0.45 * p / 0.15 : 0.45 * (1 - p) / 0.85;
    canvas.drawCircle(
      Offset(_houseX + 34.2 + 3 * p, b - 42 - 12 * p),
      2 * (0.6 + 1.2 * p),
      Paint()..color = hex('#8C929B').withValues(alpha: opacity),
    );
  }
}

double _smooth(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}
