import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'svg_path.dart';

/// The pieces every shape on the scene strip is built from — ported from the
/// Claude Design handoff (`forest-strip.js`), whose numbers are the spec.

/// The prototype's generator, so a seed grows the same kind of forest: a
/// 32-bit LCG returning [0, 1).
typedef Rng = double Function();

Rng stripRng(int seed) {
  var s = seed & 0xFFFFFFFF;
  if (s == 0) s = 1;
  return () {
    s = (s * 1664525 + 1013904223) & 0xFFFFFFFF;
    return s / 4294967296;
  };
}

Color hex(String h, [double opacity = 1]) {
  final v = int.parse(h.substring(1), radix: 16);
  return Color(0xFF000000 | v).withValues(alpha: opacity);
}

/// The strip's palette (`C` in the prototype).
abstract final class StripColors {
  static final skyTop = hex('#262A30');
  static final skyHor = hex('#3F444C');
  static final far = hex('#353940');
  static final midfar = hex('#2A2E34');
  static final mid = hex('#1D2024');
  static final ground = hex('#131518');
  static final near = hex('#0A0B0D');
  static final bg = hex('#14161A');
  static const figure = Color.fromARGB(255, 156, 163, 175);
}

/// The anchors every biome and every stop answers to — one near tone, one
/// ground tone under the feet, and a ceiling on the brightest sky or fog,
/// so the strip never glares on the dark screen (`ForestStrip.ANCHORS`).
abstract final class StripAnchors {
  static final near = StripColors.near;
  static final ground = hex('#131518');
  static final skyMax = hex('#6E747D');

  static double luminance(Color c) =>
      0.2126 * (c.r * 255) + 0.7152 * (c.g * 255) + 0.0722 * (c.b * 255);

  /// A sky or fog tone brighter than the ceiling is brought down to it.
  static Color cap(Color c) => luminance(c) > luminance(skyMax) ? skyMax : c;
}

/// One drawn primitive: a path, filled or stroked in one colour.
final class StripPrim {
  final Path path;
  final Color color;
  final double? strokeWidth;
  final StrokeCap cap;
  final StrokeJoin join;

  const StripPrim(
    this.path,
    this.color, {
    this.strokeWidth,
    this.cap = StrokeCap.butt,
    this.join = StrokeJoin.miter,
  });

  StripPrim transformed(Float64List matrix, [double opacity = 1]) => StripPrim(
    path.transform(matrix),
    color.withValues(alpha: color.a * opacity),
    strokeWidth: strokeWidth,
    cap: cap,
    join: join,
  );

  void paint(Canvas canvas) {
    final p = Paint()
      ..color = color
      ..isAntiAlias = true;
    if (strokeWidth != null) {
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth!
        ..strokeCap = cap
        ..strokeJoin = join;
    }
    canvas.drawPath(path, p);
  }
}

/// One item on a stream: how wide it is, what the prototype called it, and
/// what to draw, from x = 0.
final class StripShape {
  final double w;
  final String type;
  final List<StripPrim> prims;

  const StripShape(this.w, this.type, this.prims);

  StripShape withType(String t) => StripShape(w, t, prims);
}

typedef Pt = (double, double);

StripPrim poly(List<Pt> pts, Color color) {
  final path = Path()..moveTo(pts.first.$1, pts.first.$2);
  for (final p in pts.skip(1)) {
    path.lineTo(p.$1, p.$2);
  }
  return StripPrim(path..close(), color);
}

StripPrim fillD(String d, Color color) => StripPrim(parseSvgPath(d), color);

StripPrim strokeD(
  String d,
  Color color,
  double width, {
  bool round = false,
  bool roundJoin = false,
}) => StripPrim(
  parseSvgPath(d),
  color,
  strokeWidth: width,
  cap: round ? StrokeCap.round : StrokeCap.butt,
  join: roundJoin ? StrokeJoin.round : StrokeJoin.miter,
);

StripPrim circle(double cx, double cy, double r, Color color) => StripPrim(
  Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
  color,
);

StripPrim ellipse(double cx, double cy, double rx, double ry, Color color) =>
    StripPrim(
      Path()..addOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      ),
      color,
    );

StripPrim rect(double x, double y, double w, double h, Color color) =>
    StripPrim(Path()..addRect(Rect.fromLTWH(x, y, w, h)), color);

List<StripPrim> _apply(List<StripPrim> prims, Float64List m, [double o = 1]) =>
    [for (final p in prims) p.transformed(m, o)];

/// `rotate(deg cx cy)` on a group.
List<StripPrim> rotated(
  List<StripPrim> prims,
  double deg,
  double cx,
  double cy,
) {
  final a = radians(deg), c = math.cos(a), s = math.sin(a);
  // translate(cx,cy) · rotate(a) · translate(-cx,-cy), column-major.
  final m = Float64List.fromList([
    c, s, 0, 0, //
    -s, c, 0, 0,
    0, 0, 1, 0,
    cx - c * cx + s * cy, cy - s * cx - c * cy, 0, 1,
  ]);
  return _apply(prims, m);
}

List<StripPrim> translated(List<StripPrim> prims, double dx, double dy) {
  final m = Float64List.fromList([
    1, 0, 0, 0, //
    0, 1, 0, 0,
    0, 0, 1, 0,
    dx, dy, 0, 1,
  ]);
  return _apply(prims, m);
}

/// `translate(0 2b) scale(1 -1)` at [opacity] — a reflection in water whose
/// surface is at y = [b].
List<StripPrim> mirrored(List<StripPrim> prims, double b, double opacity) {
  final m = Float64List.fromList([
    1, 0, 0, 0, //
    0, -1, 0, 0,
    0, 0, 1, 0,
    0, 2 * b, 0, 1,
  ]);
  return _apply(prims, m, opacity);
}

/// Strip geometry for a height: ground line and scale (`geo` in the
/// prototype).
final class StripGeo {
  final double h;
  final double gy;
  final double k;

  StripGeo(this.h)
    : gy = (h * (h <= 56 ? 0.82 : 0.8)).roundToDouble(),
      k = h / 96;
}

/// One decimal, as the prototype rounds every coordinate it writes.
double f(double n) => (n * 10).round() / 10;

T pick<T>(Rng r, List<(double, T Function())> list) {
  var t = r() * list.fold<double>(0, (a, b) => a + b.$1);
  for (final (wt, fn) in list) {
    if ((t -= wt) <= 0) return fn();
  }
  return list.first.$2();
}
