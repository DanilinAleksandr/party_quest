import 'dart:math' as math;
import 'dart:ui';

import 'strip_kit.dart';

/// The shape makers of the scene strip, ported from `forest-strip.js`:
/// the forest of round 2 (14a) and the five paths of round 4 (16a–16e).
/// Each returns one item drawn from x = 0; numbers are the prototype's.
///
/// Makers of rounds that were not picked (12–13, 15a–15e) are not ported.

String n(double v) => f(v).toString();

// ── shared by the forest and the paths ────────────────────────────────────

StripShape fir(
  Rng r,
  StripGeo g,
  Color col,
  double hMin,
  double hMax,
  double base,
) {
  final h = g.h * (hMin + r() * (hMax - hMin)),
      w = h * (0.36 + r() * 0.16),
      cx = w / 2;
  final n0 = 5 + (r() * 4).floor();
  final right = <Pt>[], left = <Pt>[];
  for (var i = 1; i <= n0; i++) {
    final y = base - h + h * 0.9 * (i / n0),
        hw = (w / 2) * (i / n0) * (0.8 + r() * 0.4),
        th = h * 0.9 / n0;
    right.addAll([(cx + hw, y), (cx + hw * (0.35 + r() * 0.2), y - th * 0.2)]);
    left.insertAll(0, [
      (cx - hw * (0.35 + r() * 0.2), y - th * 0.2),
      (cx - hw * (0.8 + r() * 0.35), y),
    ]);
  }
  final tw = math.max(1.0, w * 0.06);
  return StripShape(w, 'ель', [
    poly([
      (cx, base - h),
      ...right,
      (cx + tw, base - h * 0.08),
      (cx + tw, base),
      (cx - tw, base),
      (cx - tw, base - h * 0.08),
      ...left,
    ], col),
  ]);
}

StripShape tuft(Rng r, StripGeo g) {
  final w = 5 + r() * 7, count = 3 + (r() * 3).floor();
  final d = StringBuffer();
  for (var i = 0; i < count; i++) {
    final x = w * (i + 0.5) / count,
        h = (2.5 + r() * 3.5) * math.max(g.k, 0.7),
        lean = (r() - 0.5) * 3;
    d.write(
      'M${n(x - 0.9)} ${n(g.gy + 0.5)}L${n(x + lean)} ${n(g.gy - h)}L${n(x + 0.9)} ${n(g.gy + 0.5)}Z',
    );
  }
  return StripShape(w, 'трава', [fillD(d.toString(), StripColors.ground)]);
}

StripShape grass(
  Rng r,
  StripGeo g,
  double base,
  Color col,
  double hMin,
  double hMax, [
  String type = 'трава',
]) {
  final w = 6 + r() * 10, count = 5 + (r() * 5).floor();
  final d = StringBuffer();
  for (var i = 0; i < count; i++) {
    final x = w * (i + 0.5) / count,
        h = hMin + r() * (hMax - hMin),
        l = (r() - 0.5) * 5;
    d.write(
      'M${n(x - 0.7)} ${n(base)}Q${n(x + l * 0.3)} ${n(base - h * 0.6)} ${n(x + l)} ${n(base - h)}'
      'Q${n(x + l * 0.3 + 0.5)} ${n(base - h * 0.6)} ${n(x + 0.7)} ${n(base)}Z',
    );
  }
  return StripShape(w, type, [fillD(d.toString(), col)]);
}

// ── the forest, round 2 (14a) ─────────────────────────────────────────────

StripShape midfarTrunk(Rng r, StripGeo g) {
  final w = (2 + r() * 2.6) * g.k + 1, base = g.gy - g.h * 0.05;
  return StripShape(w, 'ствол', [rect(0, -4, w, base + 4, StripColors.midfar)]);
}

StripShape midTrunk2(Rng r, StripGeo g) {
  final base = (2.6 + r() * 3.6) * g.k + 0.8,
      tw = base * (0.28 + math.pow(r(), 1.3) * 1.72);
  final bw = tw * (1.15 + r() * 0.35),
      fl = tw * (0.4 + r() * 0.6),
      w = bw + fl * 2 + 4,
      c = w / 2;
  final col = StripColors.mid;
  var prims = [
    poly([
      (c - tw / 2, -6),
      (c + tw / 2, -6),
      (c + bw / 2, g.gy - 6 * g.k),
      (c + bw / 2 + fl, g.gy + 1),
      (c - bw / 2 - fl, g.gy + 1),
      (c - bw / 2, g.gy - 6 * g.k),
    ], col),
  ];
  var type = tw < base * 0.6
      ? 'тонкий'
      : tw > base * 1.4
      ? 'толстый'
      : 'ствол';
  if (r() < 0.4) {
    final yf = g.h * (0.16 + r() * 0.3),
        dir = r() < 0.5 ? -1 : 1,
        dx = dir * g.h * (0.14 + r() * 0.22),
        bt = math.max(0.8, tw * 0.5);
    prims.add(
      poly([
        (c - bt / 2, yf + 5),
        (c + bt / 2, yf),
        (c + dx + bt / 3, -6),
        (c + dx - bt / 3, -6),
      ], col),
    );
    type = 'развилка';
  }
  if (r() < 0.55) {
    final a = (2 + r() * 3) * (r() < 0.5 ? -1 : 1);
    prims = rotated(prims, a, c, g.gy);
  }
  return StripShape(w, type, prims);
}

StripShape canopy2(Rng r, StripGeo g) {
  final w = g.h * (0.45 + r() * 0.95), top = -6.0;
  final pts = <Pt>[(0, top), (w, top)];
  var x = w;
  while (x > 0) {
    final s = (4 + r() * 7) * math.max(g.k, 0.7),
        shoulder = g.h * (0.04 + r() * 0.1);
    final tip = r() < 0.38
        ? g.h * (0.28 + r() * 0.3)
        : g.h * (0.1 + r() * 0.12);
    pts.addAll([(x, shoulder), (math.max(0, x - s * (0.35 + r() * 0.3)), tip)]);
    if (r() < 0.5) r();
    x -= s;
  }
  pts.add((0, g.h * (0.05 + r() * 0.08)));
  return StripShape(w, 'полог', [poly(pts, StripColors.mid)]);
}

StripShape nearTrunk(Rng r, StripGeo g) {
  final bw = (12 + r() * 10) * math.max(g.k, 0.6),
      tw = bw * (0.78 + r() * 0.12),
      fl = bw * (0.35 + r() * 0.35);
  final w = bw + fl * 2, c = w / 2;
  final broken = r() < 0.22;
  final top = broken ? g.h * (0.22 + r() * 0.2) : -6.0;
  final pts = <Pt>[
    (c - bw / 2 - fl, g.h + 2),
    (c - bw / 2, g.gy - 4 * g.k),
    (c - tw / 2, top),
  ];
  if (broken) {
    final s = tw / 4;
    pts.addAll([
      (c - tw / 2 + s, top - 6 * g.k),
      (c, top + 2),
      (c + s * 0.6, top - 9 * g.k),
      (c + tw / 2, top + 3),
    ]);
  } else {
    pts.add((c + tw / 2, top));
  }
  pts.addAll([(c + bw / 2, g.gy - 4 * g.k), (c + bw / 2 + fl, g.h + 2)]);
  final prims = [poly(pts, StripColors.near)];
  if (!broken && r() < 0.7) {
    final y = g.h * (0.12 + r() * 0.2),
        dir = r() < 0.5 ? -1 : 1,
        len = g.h * (0.16 + r() * 0.14);
    prims.add(
      poly([
        (c + dir * tw * 0.3, y + 5 * g.k),
        (c + dir * tw * 0.3, y),
        (c + dir * (tw / 2 + len), y - len * 0.7),
        (c + dir * (tw / 2 + len * 0.9), y - len * 0.7 + 3 * g.k),
      ], StripColors.near),
    );
  }
  return StripShape(w, broken ? 'сломанный' : 'ствол', prims);
}

StripShape fern(Rng r, StripGeo g) {
  final w = g.h * (0.22 + r() * 0.2);
  final leaves = StringBuffer(), stems = StringBuffer();
  final count = 3 + (r() * 3).floor();
  for (var i = 0; i < count; i++) {
    final x0 = w / 2 + (r() - 0.5) * w * 0.3, y0 = g.h + 2;
    final dir =
        (i / (count - 1 == 0 ? 1 : count - 1)) * 2 - 1 + (r() - 0.5) * 0.4;
    final len = g.h * (0.2 + r() * 0.2) * (1 - dir.abs() * 0.3);
    final x2 = x0 + dir * len * 0.9,
        y2 = y0 - len * (1 - dir.abs() * 0.35),
        cx1 = x0 + dir * len * 0.1,
        cy1 = y0 - len * 0.9;
    const steps = 9;
    for (var j = 1; j < steps; j++) {
      final t = j / steps, u = 1 - t;
      final px = u * u * x0 + 2 * u * t * cx1 + t * t * x2,
          py = u * u * y0 + 2 * u * t * cy1 + t * t * y2;
      final tx = 2 * u * (cx1 - x0) + 2 * t * (x2 - cx1),
          ty = 2 * u * (cy1 - y0) + 2 * t * (y2 - cy1);
      final tl = math.sqrt(tx * tx + ty * ty) == 0
          ? 1
          : math.sqrt(tx * tx + ty * ty);
      final nx = -ty / tl,
          ny = tx / tl,
          ll = len * 0.22 * (1 - t * 0.7),
          st = len / steps;
      for (final s in const [1, -1]) {
        leaves.write(
          'M${n(px)} ${n(py)}L${n(px + nx * s * ll + tx / tl * ll * 0.5)} ${n(py + ny * s * ll + ty / tl * ll * 0.5)}'
          'L${n(px + tx / tl * st)} ${n(py + ty / tl * st)}Z',
        );
      }
    }
    stems.write('M${n(x0)} ${n(y0)}Q${n(cx1)} ${n(cy1)} ${n(x2)} ${n(y2)}');
  }
  return StripShape(w, 'папоротник', [
    fillD(leaves.toString(), StripColors.near),
    strokeD(stems.toString(), StripColors.near, 1.2 * g.k + 0.4),
  ]);
}

StripShape bump(Rng r, StripGeo g) {
  final rx = (18 + r() * 34) * g.k + 6,
      ry = (g.h - g.gy) * (0.7 + r() * 0.55) + 2;
  return StripShape(rx * 2, 'кочка', [
    ellipse(rx, g.h + 2, rx, ry, StripColors.near),
  ]);
}

// ── round 3 pieces the round 4 paths still use ────────────────────────────

StripShape tombstone(Rng r, StripGeo g, Color col, double b) {
  final w0 = 4 + r() * 6,
      h = w0 * (1.2 + r() * 0.9),
      tilt = (r() - 0.5) * 8,
      round = r() < 0.7;
  final prim = round
      ? fillD(
          'M0 ${n(b)}V${n(b - h + w0 / 2)}A${n(w0 / 2)} ${n(w0 / 2)} 0 0 1 ${n(w0)} ${n(b - h + w0 / 2)}V${n(b)}Z',
          col,
        )
      : fillD(
          'M${n(w0 * 0.38)} ${n(b)}V${n(b - h)}h${n(w0 * 0.24)}V${n(b)}Z'
          'M0 ${n(b - h * 0.72)}h${n(w0)}v${n(math.max(1.2, w0 * 0.22))}H0Z',
          col,
        );
  return StripShape(
    w0,
    round ? 'надгробие' : 'крест',
    rotated([prim], tilt, w0 / 2, b),
  );
}

StripShape sunkLog(Rng r, StripGeo g) {
  final s = math.max(g.k, 0.6),
      w = (18 + r() * 16) * s,
      dir = r() < 0.5 ? 1 : -1;
  final x0 = dir > 0 ? 0.0 : w,
      x1 = dir > 0 ? w : 0.0,
      y1 = g.h - (8 + r() * 10) * s;
  final near = StripColors.near;
  return StripShape(w, 'топляк', [
    strokeD(
      'M${n(x0)} ${n(g.h + 2)}L${n(x1)} ${n(y1)}',
      near,
      3 + r() * 2,
      round: true,
    ),
    strokeD(
      'M${n(x0 + (x1 - x0) * 0.6)} ${n(g.h + 2 + (y1 - g.h - 2) * 0.6)}l${n(dir * 3.0)} -4',
      near,
      1.3,
      round: true,
    ),
  ]);
}

StripShape ripple(Rng r, StripGeo g, double y0, double y1) {
  final w = 10 + r() * 20, y = y0 + r() * (y1 - y0);
  return StripShape(w, 'рябь', [
    strokeD('M0 ${n(y)}h${n(w)}', hex('#4A5058', 0.7), 0.5),
  ]);
}

// ── round 4: the five paths (16a–16e) ─────────────────────────────────────

/// The tones of each path (`TONES` in the prototype, over `T0`).
final class PathTone {
  final Color skyTop, skyHor, skyLow, far, midfar, mid, fog, fog2, snow;
  final Color? midfarS, midS;
  final double hor, fogA, fog2A;

  PathTone({
    String skyTop = '#3A3E46',
    String skyHor = '#767C86',
    String skyLow = '#4A4F57',
    this.hor = 0.36,
    String far = '#686E77',
    String midfar = '#4E535B',
    String mid = '#2C2F34',
    String fog = '#8C929B',
    this.fogA = 0.5,
    String fog2 = '#5A6069',
    this.fog2A = 0.34,
    String snow = '#AEB4BD',
    String? midfarS,
    String? midS,
  }) : skyTop = hex(skyTop),
       skyHor = hex(skyHor),
       skyLow = hex(skyLow),
       far = hex(far),
       midfar = hex(midfar),
       mid = hex(mid),
       fog = hex(fog),
       fog2 = hex(fog2),
       snow = hex(snow),
       midfarS = midfarS == null ? null : hex(midfarS),
       midS = midS == null ? null : hex(midS);

  PathTone withFar(Color c) => PathTone._copy(this, far: c);

  PathTone._copy(PathTone t, {required this.far})
    : skyTop = t.skyTop,
      skyHor = t.skyHor,
      skyLow = t.skyLow,
      hor = t.hor,
      midfar = t.midfar,
      mid = t.mid,
      fog = t.fog,
      fogA = t.fogA,
      fog2 = t.fog2,
      fog2A = t.fog2A,
      snow = t.snow,
      midfarS = t.midfarS,
      midS = t.midS;
}

List<StripPrim> refl(List<StripPrim> s, double b, [double op = 0.3]) =>
    mirrored(s, b, op);

double _yAt(List<Pt> pts, double x) {
  for (var i = 1; i < pts.length; i++) {
    if (pts[i].$1 >= x) {
      final a = pts[i - 1], b = pts[i];
      final dx = (b.$1 - a.$1) == 0 ? 1 : (b.$1 - a.$1);
      final t = (x - a.$1) / dx;
      return a.$2 + (b.$2 - a.$2) * t;
    }
  }
  return pts.last.$2;
}

StripShape peak4(Rng r, StripGeo g, PathTone t) {
  final w = g.h * (1 + r() * 1.3),
      h = g.h * (0.45 + r() * 0.4),
      b = g.gy - g.h * 0.16,
      px = w * (0.38 + r() * 0.24),
      py = b - h;
  final left = <Pt>[
    (0, b),
    (w * 0.12, b - h * (0.3 + r() * 0.15)),
    (w * 0.22, b - h * (0.42 + r() * 0.1)),
    (px - w * 0.1, py + h * (0.2 + r() * 0.1)),
    (px, py),
  ];
  final right = <Pt>[
    (px + w * 0.06, py + h * 0.12),
    (px + w * 0.16, py + h * (0.3 + r() * 0.1)),
    (w * 0.8, b - h * (0.36 + r() * 0.16)),
    (w, b),
  ];
  final sn = <Pt>[
    (px - h * 0.16, py + h * 0.22),
    (px - h * 0.08, py + h * 0.14),
    (px, py),
    (px + h * 0.1, py + h * 0.1),
    (px + h * 0.2, py + h * 0.28),
    (px + h * 0.1, py + h * 0.21),
    (px + h * 0.02, py + h * 0.32),
    (px - h * 0.06, py + h * 0.23),
  ];
  return StripShape(w, 'пик', [
    poly([...left, ...right], t.far),
    poly([(px, py), ...right, (px + w * 0.05, b)], hex('#60666F')),
    poly(sn, t.snow),
  ]);
}

StripShape tierPine(
  Rng r,
  StripGeo g,
  Color col,
  double b,
  double hMin,
  double hMax,
) {
  final h = g.h * (hMin + r() * (hMax - hMin)),
      bend = (r() - 0.5) * h * 0.3,
      w = h * 0.62,
      c = w / 2;
  double at(double fr) => c + bend * math.pow(fr, 1.6);
  final prims = <StripPrim>[
    strokeD(
      'M${n(c)} ${n(b)}Q${n(c + bend * 0.2)} ${n(b - h * 0.5)} ${n(at(1))} ${n(b - h)}',
      col,
      math.max(1.1, h * 0.045),
      round: true,
    ),
  ];
  final count = 4 + (r() * 3).floor();
  for (var i = 0; i < count; i++) {
    final t = i / (count - 1),
        y = b - h + h * 0.06 + t * h * 0.66,
        cx = at((b - y) / h);
    final hw = (h * 0.06 + t * h * 0.22) * (0.7 + r() * 0.55),
        sk = (r() - 0.5) * hw * 0.6,
        th = h * (0.08 + t * 0.05);
    prims.add(
      poly([
        (cx + sk * 0.2, y - th),
        (cx + hw * 0.55 + sk, y - th * 0.3),
        (cx + hw + sk, y + r() * 1.2),
        (cx + hw * 0.3, y - th * 0.15),
        (cx - hw * 0.3, y - th * 0.1),
        (cx - hw + sk, y + r() * 1.2),
        (cx - hw * 0.55 + sk, y - th * 0.35),
      ], col),
    );
  }
  return StripShape(w, 'сосна', prims);
}

StripShape spire4(
  Rng r,
  StripGeo g,
  Color col,
  Color shade,
  double b,
  double hMin,
  double hMax,
) {
  final h = g.h * (hMin + r() * (hMax - hMin)),
      w = h * (0.4 + r() * 0.35),
      tx = w * (0.4 + r() * 0.2);
  double j() => (r() - 0.5) * w * 0.06;
  final left = <Pt>[
    (0, b),
    (w * 0.08 + j(), b - h * 0.28),
    (w * 0.18 + j(), b - h * 0.52),
    (w * 0.3 + j(), b - h * 0.8),
    (tx, b - h),
  ];
  final right = <Pt>[
    (tx + w * 0.08, b - h * 0.9),
    (w * 0.66 + j(), b - h * 0.62),
    (w * 0.78 + j(), b - h * 0.4),
    (w * 0.9 + j(), b - h * 0.18),
    (w, b),
  ];
  return StripShape(w, 'скала', [
    poly([...left, ...right], col),
    poly([(tx, b - h), ...right, (tx + w * 0.1, b)], shade),
  ]);
}

StripShape boulder4(
  Rng r,
  StripGeo g,
  Color col,
  double wMin,
  double wMax, [
  double? base,
]) {
  final b0 = base ?? g.h + 2;
  final w = wMin + r() * (wMax - wMin), h = w * (0.45 + r() * 0.4);
  const count = 9;
  final pts = <Pt>[(0, b0)];
  for (var i = 1; i < count; i++) {
    final a = math.pi * (1 - i / count), rr = 0.82 + r() * 0.3;
    pts.add((
      w / 2 + math.cos(a) * w / 2 * math.min(1, rr),
      b0 - math.sin(a) * h * rr,
    ));
  }
  pts.add((w, b0));
  return StripShape(w, 'валун', [poly(pts, col)]);
}

StripShape thorn4(Rng r, StripGeo g, double hMin, double hMax) {
  final h = hMin + r() * (hMax - hMin),
      w = h * (1 + r() * 0.6),
      c = w / 2,
      b = g.h + 1,
      count = 7 + (r() * 5).floor();
  final d = StringBuffer();
  for (var i = 0; i < count; i++) {
    final a = math.pi * (0.15 + 0.7 * i / (count - 1)) + (r() - 0.5) * 0.25,
        l = h * (0.6 + r() * 0.45);
    final ex = c - math.cos(a) * l * 0.9, ey = b - math.sin(a) * l;
    d.write('M${n(c)} ${n(b)}L${n(ex)} ${n(ey)}');
    for (var k = 0; k < 2; k++) {
      final t = 0.45 + k * 0.25,
          px = c + (ex - c) * t,
          py = b + (ey - b) * t,
          s = k == 1 ? 1 : -1;
      d.write('M${n(px)} ${n(py)}l${n(s * (2 + r() * 3))} ${n(-2 - r() * 3)}');
    }
  }
  return StripShape(w, 'колючка', [
    strokeD(d.toString(), StripColors.near, 1.3, round: true),
  ]);
}

StripShape crag4(
  Rng r,
  StripGeo g,
  double tMin,
  double tMax,
  bool pine, [
  bool thorny = false,
]) {
  final w = 60 + r() * 70,
      top = g.h * (tMin + r() * (tMax - tMin)) - 6,
      b = g.h + 2,
      hh = b - top;
  final pts = <Pt>[
    (0, b),
    (w * 0.06, b - hh * 0.42),
    (w * 0.14, b - hh * 0.6),
    (w * 0.2, b - hh * 0.86),
    (w * 0.3, top),
    (w * 0.46, top + 2 + r() * 4),
    (w * 0.6, top + r() * 2),
    (w * 0.68, top + hh * 0.2),
    (w * 0.78, b - hh * 0.5),
    (w * 0.9, b - hh * 0.3),
    (w, b),
  ];
  final prims = [poly(pts, StripColors.near)];
  if (pine && top > 6) {
    prims.addAll(
      translated(
        tierPine(r, g, StripColors.near, top + 3, 0.4, 0.6).prims,
        w * 0.36,
        0,
      ),
    );
  }
  if (thorny) {
    prims.addAll(
      translated(thorn4(r, g, 10, 18).prims, w * 0.4, top - g.h + 3),
    );
  }
  return StripShape(w, pine ? 'обрыв' : 'выход камня', prims);
}

StripShape headland4(Rng r, StripGeo g, PathTone t, double hy) {
  final w = g.h * (2 + r() * 1.6), h = g.h * (0.26 + r() * 0.2);
  final pts = <Pt>[
    (0, hy),
    (w * 0.08, hy - h * 0.5),
    (w * 0.2, hy - h * 0.8),
    (w * 0.4, hy - h),
    (w * 0.62, hy - h * 0.94),
    (w * 0.74, hy - h * 0.9),
    (w * 0.77, hy - h * 0.55),
    (w * 0.8, hy - h * 0.4),
    (w * 0.84, hy - h * 0.1),
    (w * 0.9, hy),
  ];
  final prims = [
    poly(pts, t.far),
    poly([
      (w * 0.74, hy - h * 0.9),
      (w * 0.77, hy - h * 0.55),
      (w * 0.8, hy - h * 0.4),
      (w * 0.84, hy - h * 0.1),
      (w * 0.9, hy),
      (w * 0.78, hy),
    ], hex('#5A6069')),
  ];
  for (var x = w * 0.12; x < w * 0.7; x += 4 + r() * 9) {
    final y = _yAt(pts, x), th = 3 + r() * 4;
    prims.add(
      poly([(x, y - th), (x + 1.6, y + 0.6), (x - 1.6, y + 0.6)], t.far),
    );
  }
  var type = 'мыс';
  if (r() < 0.5) {
    final lx = w * 0.56, ly = _yAt(pts, w * 0.56), th = g.h * 0.2;
    prims.addAll([
      fillD(
        'M${n(lx - 2.2)} ${n(ly + 0.5)}L${n(lx - 1.3)} ${n(ly - th)}h2.6L${n(lx + 2.2)} ${n(ly + 0.5)}Z',
        t.midfar,
      ),
      rect(lx - 2.2, ly - th - 3.2, 4.4, 3.2, t.midfar),
      poly([
        (lx - 2.6, ly - th - 3.2),
        (lx, ly - th - 5.6),
        (lx + 2.6, ly - th - 3.2),
      ], t.midfar),
      rect(lx - 1.2, ly - th - 2.4, 2.4, 1.6, hex('#E4E7EA')),
      poly([
        (lx + 1.4, ly - th - 2.2),
        (lx + 44, ly - th - 8),
        (lx + 44, ly - th + 3),
      ], hex('#D8DCE0', 0.1)),
      rect(lx - 7, ly - 4, 7, 4.4, t.midfar),
    ]);
    type = 'маяк';
  }
  return StripShape(w, type, prims);
}

StripShape wreck4(Rng r, StripGeo g) {
  final w = 50 + r() * 26,
      kb = g.gy + 1,
      h = g.h * (0.38 + r() * 0.14),
      count = 9 + (r() * 3).floor();
  double keel(double t) => kb - t * t * h * 0.16;
  final d = StringBuffer();
  for (var i = 0; i < count; i++) {
    final t = i / (count - 1), x = w * (0.04 + t * 0.9), y0 = keel(t);
    var hh = h * (0.3 + 0.7 * math.pow(t, 1.2)) * (0.9 + r() * 0.2);
    final broken = i > 0 && r() < 0.3;
    if (broken) hh *= 0.35 + r() * 0.3;
    final out = hh * 0.34;
    d.write(
      'M${n(x)} ${n(y0)}C${n(x - out)} ${n(y0 - hh * 0.35)} ${n(x - out * 0.6)} ${n(y0 - hh * 0.82)} ${n(x + hh * 0.1)} ${n(y0 - hh)}',
    );
    if (broken) d.write('l1.4 -1.2l.6 1.4');
  }
  d.write(
    'M${n(w * 0.94)} ${n(keel(1))}Q${n(w + 4)} ${n(kb - h * 0.6)} ${n(w + 1)} ${n(kb - h * 1.1)}',
  );
  final col = hex('#17191C');
  return StripShape(w + 6, 'остов корабля', [
    strokeD(
      'M0 ${n(kb)}Q${n(w * 0.6)} ${n(kb + 1)} ${n(w * 0.96)} ${n(keel(1))}',
      col,
      2.8,
      round: true,
    ),
    strokeD(d.toString(), col, 2, round: true, roundJoin: true),
  ]);
}

StripShape angular4(
  Rng r,
  StripGeo g,
  Color col,
  double wMin,
  double wMax, [
  double? base,
]) {
  final b0 = base ?? g.h + 2;
  final w = wMin + r() * (wMax - wMin),
      h = w * (0.5 + r() * 0.45),
      count = 5 + (r() * 3).floor();
  final pts = <Pt>[(0, b0)];
  for (var i = 1; i <= count; i++) {
    final t = i / (count + 1);
    pts.add((
      w * (t + (r() - 0.5) * 0.08),
      b0 - h * (0.45 + 0.55 * math.sin(t * math.pi)) * (0.78 + r() * 0.3),
    ));
  }
  pts.add((w, b0));
  final ti = 1 + (r() * count).floor(), tp = pts[ti], nx = pts[ti + 1];
  final facet = poly([
    tp,
    nx,
    (nx.$1 + (w - nx.$1) * 0.3, b0),
    (tp.$1 + w * 0.06, b0),
  ], hex('#15171A'));
  final c = pts[math.max(1, ti - 1)];
  return StripShape(w, 'валун', [
    poly(pts, col),
    facet,
    strokeD(
      'M${n(c.$1)} ${n(c.$2)}l${n(w * 0.06)} ${n(h * 0.18)}l${n(w * 0.05)} ${n(-h * 0.05)}M${n(tp.$1)} ${n(tp.$2)}l${n(-w * 0.04)} ${n(h * 0.3)}',
      hex('#1C1F23'),
      0.6,
    ),
  ]);
}

StripShape driftwood4(Rng r, StripGeo g) {
  final w = 40 + r() * 36,
      y0 = g.h + 2,
      y1 = g.h - 6 - r() * 8,
      dir = r() < 0.5;
  final x0 = dir ? 0.0 : w, x1 = dir ? w : 0.0, sg = dir ? 1 : -1;
  final br = StringBuffer();
  for (final (t, l, a) in [
    (0.55, 18 + r() * 12, 0.9),
    (0.8, 12 + r() * 10, 1.2),
  ]) {
    final bx = x0 + (x1 - x0) * t, by = y0 + (y1 - y0) * t;
    br.write('M${n(bx)} ${n(by)}L${n(bx + sg * l * 0.5)} ${n(by - l * a)}');
  }
  final near = StripColors.near;
  return StripShape(w, 'коряга', [
    strokeD(
      'M${n(x0)} ${n(y0)}L${n(x1)} ${n(y1)}',
      near,
      4.5 + r() * 2,
      round: true,
    ),
    strokeD(br.toString(), near, 2.6, round: true),
  ]);
}

StripShape butte4(Rng r, StripGeo g, PathTone t) {
  final b = g.gy - g.h * 0.15;
  if (r() < 0.35) {
    final w = 8 + r() * 8, h = g.h * (0.3 + r() * 0.3);
    return StripShape(w + 6, 'останец', [
      poly([
        (0, b),
        (w * 0.2, b - h * 0.5),
        (w * 0.25, b - h * 0.96),
        (w * 0.4, b - h),
        (w * 0.7, b - h * 0.98),
        (w * 0.8, b - h * 0.5),
        (w + 6, b),
      ], t.far),
    ]);
  }
  final w = g.h * (0.7 + r() * 1.1), h = g.h * (0.2 + r() * 0.24);
  return StripShape(w, 'столовая гора', [
    poly([
      (0, b),
      (w * 0.14, b - h * 0.45),
      (w * 0.2, b - h * 0.98),
      (w * 0.24, b - h),
      (w * 0.66, b - h),
      (w * 0.7, b - h * 0.94),
      (w * 0.76, b - h * 0.5),
      (w, b),
    ], t.far),
    poly([
      (w * 0.66, b - h),
      (w * 0.7, b - h * 0.94),
      (w * 0.76, b - h * 0.5),
      (w, b),
      (w * 0.7, b),
    ], hex('#63686F')),
  ]);
}

StripShape dune4(
  Rng r,
  StripGeo g,
  Color lit,
  Color shade,
  double b,
  double hMin,
  double hMax,
) {
  final w = g.h * (1.1 + r() * 1.5),
      h = g.h * (hMin + r() * (hMax - hMin)),
      cx = w * (0.35 + r() * 0.3),
      cy = b - h;
  final right =
      'C${n(cx + (w - cx) * 0.35)} ${n(cy + h * 0.05)} ${n(w * 0.86)} ${n(b)} ${n(w)} ${n(b)}';
  return StripShape(w, 'дюна', [
    fillD(
      'M0 ${n(b)}C${n(cx * 0.55)} ${n(b)} ${n(cx * 0.7)} ${n(cy)} ${n(cx)} ${n(cy)}${right}Z',
      lit,
    ),
    fillD(
      'M${n(cx)} ${n(cy)}${right}L${n(cx + w * 0.12)} ${n(b)}Q${n(cx + w * 0.03)} ${n(cy + h * 0.5)} ${n(cx)} ${n(cy)}Z',
      shade,
    ),
  ]);
}

StripShape deadTree4(
  Rng r,
  StripGeo g,
  Color col,
  double b,
  double hs, [
  double sw = 1.4,
]) {
  final h = g.h * hs * (0.8 + r() * 0.4),
      w = h * 0.7,
      c = w / 2,
      lean = (r() - 0.5) * h * 0.2,
      tw = math.max(1.4, h * 0.06);
  final d = StringBuffer();
  for (var i = 0; i < 5; i++) {
    final t = 0.35 + i * 0.13 + r() * 0.05,
        x = c + lean * t,
        y = b - h * t,
        dir = i.isOdd ? 1 : -1;
    final l = h * (0.38 - i * 0.05) * (0.8 + r() * 0.4),
        ex = x + dir * l * 0.75,
        ey = y - l * 0.6;
    d.write(
      'M${n(x)} ${n(y)}Q${n(x + dir * l * 0.4)} ${n(y - l * 0.1)} ${n(ex)} ${n(ey)}'
      'M${n(x + dir * l * 0.5)} ${n(y - l * 0.25)}l${n(dir * l * 0.1)} ${n(-l * 0.3)}M${n(ex)} ${n(ey)}l${n(dir * 2.0)} -3',
    );
  }
  return StripShape(w, 'мёртвое дерево', [
    poly([
      (c - tw, b),
      (c - tw * 0.4 + lean, b - h),
      (c + tw * 0.4 + lean, b - h),
      (c + tw, b),
    ], col),
    strokeD(d.toString(), col, sw, round: true, roundJoin: true),
  ]);
}

StripShape skeleton4(Rng r, StripGeo g, Color col) {
  const count = 8, step = 3.6;
  final b = g.gy + 0.6, tops = <Pt>[];
  final d = StringBuffer();
  for (var i = 0; i < count; i++) {
    final t = i / (count - 1),
        x = 4 + i * step,
        hh = 7 + math.sin(t * math.pi) * 5;
    tops.add((x + 1, b - hh));
    d.write(
      'M${n(x)} ${n(b)}Q${n(x - 3)} ${n(b - hh * 0.7)} ${n(x + 1)} ${n(b - hh)}',
    );
  }
  d.write('M${tops.map((q) => '${n(q.$1)} ${n(q.$2)}').join('L')}');
  const xs = 4 + count * step + 5;
  d.write(
    'M${n(xs - 1)} ${n(b - 4.4)}q-1 -5 2 -7.4M${n(xs + 2)} ${n(b - 4.4)}q2 -4 5.4 -5',
  );
  return StripShape(xs + 8, 'скелет', [
    strokeD(d.toString(), col, 1.4, round: true),
    ellipse(xs, b - 2.6, 3.6, 2.4, col),
  ]);
}

StripShape stump4(Rng r, StripGeo g, Color col, double b) {
  final h = g.h * (0.26 + r() * 0.1),
      tw = 3 + r() * 1.6,
      w = h * 1.1,
      c = w / 2,
      lean = (r() - 0.5) * 3;
  final trunk = poly([
    (c - tw * 1.3, b),
    (c - tw * 0.7, b - h * 0.4),
    (c - tw * 0.6 + lean, b - h * 0.72),
    (c + tw * 0.6 + lean, b - h * 0.72),
    (c + tw * 0.7, b - h * 0.4),
    (c + tw * 1.3, b),
  ], col);
  final d =
      'M${n(c - tw * 0.4 + lean)} ${n(b - h * 0.7)}L${n(c - h * 0.34)} ${n(b - h)}'
      'M${n(c + tw * 0.4 + lean)} ${n(b - h * 0.7)}L${n(c + h * 0.3)} ${n(b - h * 0.94)}';
  return StripShape(w, 'мёртвое дерево', [
    trunk,
    strokeD(d, col, tw * 0.8, round: true),
  ]);
}

StripShape bushLine(Rng r, StripGeo g, Color col, double b) {
  final w = g.h * (0.8 + r() * 1.8);
  final prims = [rect(0, b - 2, w, 2.4, col)];
  for (var x = 2.0; x < w - 2; x += 3 + r() * 5) {
    prims.add(circle(x, b - 2 - r() * 2, 2 + r() * 3.4, col));
  }
  return StripShape(w, 'кромка', prims);
}

StripShape posts4(Rng r, StripGeo g, Color col, double b) {
  final count = 3 + (r() * 4).floor(), sp = 5 + r() * 3, w = count * sp;
  final d = StringBuffer();
  for (var i = 0; i < count; i++) {
    final x = i * sp + 2, h = 5 + r() * 5, t = (r() - 0.5) * 2;
    d.write('M${n(x)} ${n(b + 1)}L${n(x + t)} ${n(b - h)}');
  }
  d.write(
    'M2 ${n(b - 3.6)}L${n(w - 2)} ${n(b - 2.6)}M${n(w * 0.4)} ${n(b - 6)}L${n(w - 1)} ${n(b - 5)}',
  );
  final s = [strokeD(d.toString(), col, 1.4, round: true)];
  return StripShape(w, 'изгородь', [...s, ...refl(s, b)]);
}

StripShape sunkBarn(Rng r, StripGeo g, Color col, double b) {
  final w = 34 + r() * 16, h = g.h * (0.18 + r() * 0.08), tilt = -(3 + r() * 5);
  final s = [
    poly([(0, b), (w * 0.42, b - h), (w * 0.5, b - h * 0.96), (w, b)], col),
    strokeD(
      'M${n(w * 0.42)} ${n(b - h)}l-3 -2.6M${n(w * 0.5)} ${n(b - h * 0.96)}l2.6 -2.2',
      col,
      1.1,
    ),
    strokeD(
      'M${n(w * 0.2)} ${n(b - h * 0.45)}L${n(w * 0.8)} ${n(b - h * 0.45)}M${n(w * 0.3)} ${n(b - h * 0.2)}L${n(w * 0.7)} ${n(b - h * 0.2)}',
      hex('#3A3E45'),
      0.6,
    ),
  ];
  final g1 = rotated(s, tilt, w / 2, b);
  return StripShape(w, 'крыша сарая', [...g1, ...refl(g1, b, 0.26)]);
}

StripShape stake4(Rng r, StripGeo g) {
  final count = r() < 0.5 ? 2 : 1, w = 30 + r() * 20, b = g.h + 2;
  final prims = <StripPrim>[];
  for (var i = 0; i < count; i++) {
    final bw = 7 + r() * 7,
        x = i == 1 ? w * 0.6 : w * 0.15,
        top = g.h * (0.04 + r() * 0.36) + i * g.h * 0.2,
        lean = (r() - 0.5) * 8;
    prims.add(
      poly([
        (x, b),
        (x + lean * 0.6, top + 5),
        (x + bw * 0.3 + lean, top),
        (x + bw * 0.5 + lean, top + 4),
        (x + bw * 0.75 + lean, top - 3),
        (x + bw + lean * 0.8, top + 6),
        (x + bw, b),
      ], StripColors.near),
    );
  }
  return StripShape(w, 'сломанный столб', prims);
}

StripShape cattail4(Rng r, StripGeo g) {
  final w = 10 + r() * 16, b = g.h + 1, count = 6 + (r() * 6).floor();
  final d = StringBuffer();
  final heads = <StripPrim>[];
  final near = StripColors.near;
  for (var i = 0; i < count; i++) {
    final x = w * (i + 0.5) / count + (r() - 0.5) * 2,
        h = 12 + r() * 20,
        l = (r() - 0.5) * 6;
    d.write(
      'M${n(x - 0.8)} ${n(b)}Q${n(x + l * 0.3)} ${n(b - h * 0.6)} ${n(x + l)} ${n(b - h)}'
      'Q${n(x + l * 0.3 + 0.6)} ${n(b - h * 0.6)} ${n(x + 0.8)} ${n(b)}Z',
    );
    if (r() < 0.35) {
      final hx = x + l * 0.8, hy = b - h * 0.9;
      heads.add(
        StripPrim(
          Path()..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(hx - 1, hy - 4, 2, 4.4),
              const Radius.circular(1),
            ),
          ),
          near,
        ),
      );
      heads.add(strokeD('M${n(hx)} ${n(hy - 4)}v-2.6', near, 0.7));
    }
  }
  return StripShape(w, 'камыш', [fillD(d.toString(), near), ...heads]);
}

StripShape chapel4(Rng r, StripGeo g, PathTone t, double b) {
  final nw = 30 + r() * 14,
      nh = 10 + r() * 4,
      th = g.h * (0.42 + r() * 0.12),
      tx = nw * (0.62 + r() * 0.2);
  const tw = 8.0;
  final warm = const Color.fromRGBO(185, 122, 82, 0.8);
  final prims = [
    fillD(
      'M0 ${n(b)}V${n(b - nh)}L${n(nw * 0.5)} ${n(b - nh - nw * 0.28)}L${n(nw)} ${n(b - nh)}V${n(b)}Z',
      t.far,
    ),
    rect(tx - tw / 2, b - th, tw, th, t.far),
    fillD(
      'M${n(tx - tw / 2 - 0.6)} ${n(b - th)}L${n(tx)} ${n(b - th - 9)}L${n(tx + tw / 2 + 0.6)} ${n(b - th)}Z',
      t.far,
    ),
    strokeD(
      'M${n(tx)} ${n(b - th - 9)}v-4M${n(tx - 1.6)} ${n(b - th - 11.6)}h3.2',
      t.far,
      0.9,
    ),
    _rrect(tx - 1, b - th + 3, 2, 3.4, 1, warm),
    for (final k in const [0.18, 0.34])
      _rrect(nw * k, b - nh + 3, 2, 4, 1, warm),
  ];
  return StripShape(nw + 8, 'часовня', prims);
}

StripPrim _rrect(double x, double y, double w, double h, double rad, Color c) =>
    StripPrim(
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          Radius.circular(rad),
        ),
      ),
      c,
    );

StripShape mausoleum4(Rng r, StripGeo g, Color col, double b) {
  final w = 16 + r() * 8, h = 9 + r() * 3;
  return StripShape(w + 2, 'склеп', [
    rect(1, b - h, w, h, col),
    fillD(
      'M0 ${n(b - h)}L${n(1 + w / 2)} ${n(b - h - 5)}L${n(w + 2)} ${n(b - h)}Z',
      col,
    ),
    fillD(
      'M${n(1 + w / 2 - 2.6)} ${n(b)}V${n(b - 4.6)}A2.6 2.6 0 0 1 ${n(1 + w / 2 + 2.6)} ${n(b - 4.6)}V${n(b)}Z',
      hex('#2E3237'),
    ),
  ]);
}

StripShape tomb4(Rng r, StripGeo g) {
  final w0 = 9 + r() * 10,
      h = w0 * (1.3 + r() * 0.8),
      tilt = (r() - 0.5) * 26,
      b = g.h + 3,
      k = r();
  final near = StripColors.near;
  List<StripPrim> s;
  if (k < 0.55) {
    s = [
      fillD(
        'M0 ${n(b)}V${n(b - h + w0 * 0.35)}Q0 ${n(b - h)} ${n(w0 * 0.5)} ${n(b - h)}Q${n(w0)} ${n(b - h)} ${n(w0)} ${n(b - h + w0 * 0.35)}V${n(b)}Z',
        near,
      ),
    ];
  } else if (k < 0.8) {
    s = [
      poly([
        (0, b),
        (0, b - h * 0.9),
        (w0 * 0.3, b - h),
        (w0 * 0.6, b - h * 0.92),
        (w0, b - h * 0.97),
        (w0, b),
      ], near),
    ];
  } else {
    final cx = w0 / 2, cy = b - h * 0.75;
    s = [
      fillD(
        'M${n(cx - 1.8)} ${n(b)}V${n(b - h)}h3.6V${n(b)}ZM${n(cx - w0 * 0.55)} ${n(cy - 1.8)}h${n(w0 * 1.1)}v3.6h${n(-w0 * 1.1)}Z',
        near,
      ),
      StripPrim(
        Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: w0 * 0.34)),
        near,
        strokeWidth: 1.6,
      ),
    ];
  }
  return StripShape(w0 + 4, 'надгробие', rotated(s, tilt, w0 / 2, b));
}

StripShape wrought4(Rng r, StripGeo g) {
  final w = 30 + r() * 50, b = g.h + 1, h = 16 + r() * 10;
  final d = StringBuffer(
    'M0 ${n(b - h * 0.3)}H${n(w)}M0 ${n(b - h * 0.8)}H${n(w)}',
  );
  final tips = StringBuffer();
  for (var x = 1.0; x < w; x += 3.6) {
    d.write('M${n(x)} ${n(b)}V${n(b - h)}');
    tips.write(
      'M${n(x - 1.2)} ${n(b - h + 1.2)}L${n(x)} ${n(b - h - 2.2)}L${n(x + 1.2)} ${n(b - h + 1.2)}Z',
    );
  }
  final near = StripColors.near;
  return StripShape(
    w,
    'ограда',
    rotated(
      [strokeD(d.toString(), near, 1.1), fillD(tips.toString(), near)],
      (r() - 0.5) * 6,
      0,
      b,
    ),
  );
}

StripShape hangTree(Rng r, StripGeo g) {
  final w = 90 + r() * 50, b = g.h + 2, bx = 14 + r() * 10, tw = 10 + r() * 6;
  final d = StringBuffer();
  for (var i = 0; i < 4; i++) {
    final y = g.h * (0.05 + i * 0.12 + r() * 0.05),
        l = w * (0.5 - i * 0.08) * (0.8 + r() * 0.3),
        ex = bx + l,
        ey = y - 4 - r() * 8;
    d.write(
      'M${n(bx)} ${n(y + 3)}Q${n(bx + l * 0.5)} ${n(y - 2)} ${n(ex)} ${n(ey)}',
    );
    for (var k = 0; k < 3; k++) {
      final t = 0.35 + k * 0.22,
          px = bx + l * t,
          py = y + 3 + (ey - y - 3) * t - 1;
      d.write(
        'M${n(px)} ${n(py)}l${n(3 + r() * 4)} ${n((r() < 0.5 ? -1 : 1) * (2 + r() * 4))}',
      );
    }
  }
  final near = StripColors.near;
  return StripShape(w, 'голое дерево', [
    poly([
      (bx - tw * 0.9, b),
      (bx - tw * 0.4, b * 0.5),
      (bx - tw * 0.3, -6),
      (bx + tw * 0.3, -6),
      (bx + tw * 0.4, b * 0.4),
      (bx + tw * 0.9, b),
    ], near),
    strokeD(d.toString(), near, 1.6, round: true),
  ]);
}
