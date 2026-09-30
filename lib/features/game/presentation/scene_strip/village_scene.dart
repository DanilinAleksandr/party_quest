import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'stop_scenes.dart';
import 'strip_kit.dart';
import 'strip_world.dart';
import 'svg_path.dart';
import 'village_svg.dart';

/// The village of [biome] on the scene strip (15g–15k), from the handoff's
/// own markup in [kVillageSvg].
///
/// The prototype builds its scenes as SVG, and the villages are the richest
/// of them — dozens of shape makers for log houses, houses on stilts, clay
/// cubes, palms and a camel. Rather than port every maker, the game keeps
/// the markup they produce and reads it here: pieces are the prototype's
/// `data-in` groups, lit up in its order; what moves is what the prototype
/// animates — smoke from chimneys, the fire's glow and flame, the people by
/// the fire on the flooded village's mound.
///
/// Only what the villages use is understood: rect, circle, ellipse,
/// polygon and path, translated groups, solid and rgba colours, the
/// prototype's four gradients, and five motions.
StopScene buildVillage(StripBiome biome) {
  final svg = kVillageSvg[_villageOf(biome)]!;
  return StopScene('ДЕРЕВНЯ', _Reader(svg).read());
}

/// No village stands in a graveyard; the forest's is the fallback for any
/// biome without one of its own.
String _villageOf(StripBiome biome) => switch (biome) {
  StripBiome.forest || StripBiome.graveyard => 'forest',
  StripBiome.mountains => 'mountains',
  StripBiome.coast => 'coast',
  StripBiome.desert => 'desert',
  StripBiome.floodlands => 'floodlands',
};

const _warm = Color.fromRGBO(185, 122, 82, 1);

typedef _Op = void Function(Canvas canvas);

/// One drawn thing: how to draw it, and where it is.
final class _Mark {
  final _Op op;
  final Rect bounds;

  _Mark(this.op, this.bounds);
}

/// What is being gathered: a piece of the scene, or a moving part of one.
final class _Batch {
  final int? order;
  final StopMotion? motion;
  final double period;
  final double delay;
  final marks = <_Mark>[];
  final anims = <StopAnim>[];

  _Batch({this.order, this.motion, this.period = 1, this.delay = 0});

  ui.Picture record() {
    final r = ui.PictureRecorder();
    final c = Canvas(r);
    for (final m in marks) {
      m.op(c);
    }
    return r.endRecording();
  }

  Rect get bounds =>
      marks.map((m) => m.bounds).reduce((a, b) => a.expandToInclude(b));
}

final class _Group {
  final Offset shift;
  final _Batch? opened;

  _Group(this.shift, this.opened);
}

final class _Reader {
  final String svg;

  _Reader(this.svg);

  static final _tag = RegExp(r'<(/?)(\w+)((?:[^>"]|"[^"]*")*?)(/?)>');
  static final _attr = RegExp(r'([\w-]+)="([^"]*)"');

  final _pieces = <StopPiece>[];
  _Batch? _piece;
  _Batch? _anim;
  final _groups = <_Group>[];

  Offset get _shift => _groups.fold(Offset.zero, (sum, g) => sum + g.shift);

  List<StopPiece> read() {
    for (final m in _tag.allMatches(svg)) {
      final closing = m.group(1) == '/';
      final name = m.group(2)!;
      final attrs = {
        for (final a in _attr.allMatches(m.group(3)!)) a.group(1)!: a.group(2)!,
      };
      final selfClosing = m.group(4) == '/';
      if (name == 'g') {
        if (closing) {
          _closeGroup();
        } else {
          _openGroup(attrs);
          if (selfClosing) _closeGroup();
        }
        continue;
      }
      if (closing) continue;
      _shape(name, attrs);
    }
    _endLoosePiece();
    return _pieces;
  }

  void _openGroup(Map<String, String> attrs) {
    final shift = _translate(attrs['transform']);
    _Batch? opened;
    final order = int.tryParse(attrs['data-in'] ?? '');
    final animation = _animation(attrs['style']);
    if (order != null && _groups.isEmpty) {
      _endLoosePiece();
      opened = _piece = _Batch(order: order);
    } else if (animation != null && _anim == null) {
      opened = _anim = _Batch(
        motion: animation.motion,
        period: animation.period,
        delay: animation.delay,
      );
    }
    _groups.add(_Group(shift, opened));
  }

  void _closeGroup() {
    final group = _groups.removeLast();
    final opened = group.opened;
    if (opened == null) return;
    if (identical(opened, _anim)) {
      _anim = null;
      _endAnim(opened);
    } else if (identical(opened, _piece)) {
      _pieces.add(_stopPiece(opened));
      _piece = null;
    }
  }

  /// Elements outside any lit-up group — the sky's fog, the water, the
  /// ground — are part of the scene from the first frame, in their place in
  /// the drawing order.
  void _endLoosePiece() {
    final loose = _piece;
    if (loose != null && loose.order == null) {
      _pieces.add(_stopPiece(loose));
      _piece = null;
    }
  }

  StopPiece _stopPiece(_Batch b) => StopPiece(b.order, b.record(), b.anims);

  void _endAnim(_Batch a) {
    if (a.marks.isEmpty) return;
    final host = _piece ?? (_piece = _Batch());
    host.anims.add(
      StopAnim(a.record(), a.bounds, a.motion!, a.period, delay: a.delay),
    );
  }

  void _shape(String name, Map<String, String> attrs) {
    var path = _path(name, attrs);
    if (path == null) return;
    // An element's own transform — the flame is placed and sized so.
    final own = _matrix(attrs['transform']);
    if (own != null) path = path.transform(own);
    final at = path.shift(_shift);
    final ops = _paints(attrs, at);
    if (ops.isEmpty) return;
    final mark = _Mark((c) {
      for (final op in ops) {
        op(c);
      }
    }, at.getBounds());

    final animation = _animation(attrs['style']);
    if (animation != null && _anim == null) {
      // A single element that moves on its own: a puff of smoke, a glow.
      _endAnim(
        _Batch(
            motion: animation.motion,
            period: animation.period,
            delay: animation.delay,
          )
          ..marks.add(
            animation.motion == StopMotion.smoke
                ? _Mark((c) {
                    // The puff's own opacity is the animation's to set.
                    for (final op in _paints(attrs, at, ignoreOpacity: true)) {
                      op(c);
                    }
                  }, at.getBounds())
                : mark,
          ),
      );
      return;
    }
    if (_anim != null) {
      _anim!.marks.add(mark);
    } else {
      (_piece ??= _Batch()).marks.add(mark);
    }
  }

  static Path? _path(String name, Map<String, String> a) {
    double n(String k, [double d = 0]) => double.tryParse(a[k] ?? '') ?? d;
    switch (name) {
      case 'rect':
        return Path()
          ..addRect(Rect.fromLTWH(n('x'), n('y'), n('width'), n('height')));
      case 'circle':
        return Path()..addOval(
          Rect.fromCircle(center: Offset(n('cx'), n('cy')), radius: n('r')),
        );
      case 'ellipse':
        return Path()..addOval(
          Rect.fromCenter(
            center: Offset(n('cx'), n('cy')),
            width: 2 * n('rx'),
            height: 2 * n('ry'),
          ),
        );
      case 'polygon':
        final nums = (a['points'] ?? '')
            .split(RegExp(r'[\s,]+'))
            .where((s) => s.isNotEmpty)
            .map(double.parse)
            .toList();
        if (nums.length < 4) return null;
        final p = Path()..moveTo(nums[0], nums[1]);
        for (var i = 2; i + 1 < nums.length; i += 2) {
          p.lineTo(nums[i], nums[i + 1]);
        }
        return p..close();
      case 'path':
        final d = a['d'];
        return d == null ? null : parseSvgPath(d);
      default:
        return null;
    }
  }

  /// How an element is painted: its fill (black unless it says otherwise,
  /// as SVG has it), then its stroke, at its opacity.
  static List<_Op> _paints(
    Map<String, String> a,
    Path path, {
    bool ignoreOpacity = false,
  }) {
    final opacity = ignoreOpacity
        ? 1.0
        : (double.tryParse(a['opacity'] ?? '') ?? 1).clamp(0.0, 1.0);
    final ops = <_Op>[];
    final fill = a['fill'] ?? '#000000';
    if (fill != 'none') {
      final shaded = _gradient(fill, path.getBounds());
      if (shaded != null) {
        ops.add((c) => shaded(c, path, opacity));
      } else {
        final colour = _colour(fill);
        if (colour != null) {
          final paint = Paint()
            ..isAntiAlias = true
            ..color = colour.withValues(alpha: colour.a * opacity);
          ops.add((c) => c.drawPath(path, paint));
        }
      }
    }
    final stroke = a['stroke'];
    if (stroke != null && stroke != 'none') {
      final colour = _colour(stroke);
      if (colour != null) {
        final paint = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = double.tryParse(a['stroke-width'] ?? '') ?? 1
          ..strokeCap = switch (a['stroke-linecap']) {
            'round' => StrokeCap.round,
            'square' => StrokeCap.square,
            _ => StrokeCap.butt,
          }
          ..strokeJoin = a['stroke-linejoin'] == 'round'
              ? StrokeJoin.round
              : StrokeJoin.miter
          ..color = colour.withValues(alpha: colour.a * opacity);
        ops.add((c) => c.drawPath(path, paint));
      }
    }
    return ops;
  }

  static Color? _colour(String v) {
    if (v.startsWith('#')) return hex(v);
    final m = RegExp(r'rgba?\(([^)]*)\)').firstMatch(v);
    if (m == null) return null;
    final p = m
        .group(1)!
        .split(',')
        .map((s) => double.parse(s.trim()))
        .toList();
    return Color.fromRGBO(
      p[0].round(),
      p[1].round(),
      p[2].round(),
      p.length > 3 ? p[3] : 1,
    );
  }

  /// The prototype's gradients, over the element's own bounds as SVG has
  /// them by default.
  static void Function(Canvas, Path, double)? _gradient(String fill, Rect r) {
    final m = RegExp(r'url\(#v(\w+)\)').firstMatch(fill);
    if (m == null) return null;
    ui.Shader vertical(List<Color> colours, [List<double>? stops]) =>
        ui.Gradient.linear(r.topCenter, r.bottomCenter, colours, stops);
    switch (m.group(1)) {
      case 'fog':
        const fog = Color(0xFF565C66);
        return (c, p, o) => c.drawPath(
          p,
          Paint()
            ..shader = vertical(
              [
                fog.withValues(alpha: 0),
                fog.withValues(alpha: 0.46 * o),
                fog.withValues(alpha: 0),
              ],
              const [0, 0.55, 1],
            ),
        );
      case 'wat':
        return (c, p, o) => c.drawPath(
          p,
          Paint()
            ..shader = vertical([
              const Color(0xFF2E3239).withValues(alpha: o),
              const Color(0xFF191B1F).withValues(alpha: o),
            ]),
        );
      case 'ws':
        return (c, p, o) => c.drawPath(
          p,
          Paint()
            ..shader = vertical([
              _warm.withValues(alpha: 0.5 * o),
              _warm.withValues(alpha: 0),
            ]),
        );
      case 'w':
        // The warm glow: a radial gradient stretched over the ellipse.
        return (c, p, o) {
          c.save();
          c.translate(r.center.dx, r.center.dy);
          c.scale(r.width / 2, r.height / 2);
          c.drawCircle(
            Offset.zero,
            1,
            Paint()
              ..shader = ui.Gradient.radial(Offset.zero, 1, [
                _warm.withValues(alpha: 0.38 * o),
                _warm.withValues(alpha: 0),
              ]),
          );
          c.restore();
        };
      default:
        return null;
    }
  }

  /// `translate(x y)` and `scale(s)` on one element, in that order.
  static Float64List? _matrix(String? transform) {
    if (transform == null) return null;
    var tx = 0.0, ty = 0.0, sx = 1.0, sy = 1.0;
    final t = RegExp(
      r'translate\(\s*([-\d.]+)[\s,]+([-\d.]+)\s*\)',
    ).firstMatch(transform);
    if (t != null) {
      tx = double.parse(t.group(1)!);
      ty = double.parse(t.group(2)!);
    }
    final k = RegExp(
      r'scale\(\s*([-\d.]+)(?:[\s,]+([-\d.]+))?\s*\)',
    ).firstMatch(transform);
    if (k != null) {
      sx = double.parse(k.group(1)!);
      sy = double.parse(k.group(2) ?? k.group(1)!);
    }
    return Float64List.fromList([
      sx, 0, 0, 0, 0, sy, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1, //
    ]);
  }

  static Offset _translate(String? transform) {
    if (transform == null) return Offset.zero;
    final m = RegExp(
      r'translate\(\s*([-\d.]+)[\s,]+([-\d.]+)\s*\)',
    ).firstMatch(transform);
    if (m == null) return Offset.zero;
    return Offset(double.parse(m.group(1)!), double.parse(m.group(2)!));
  }

  /// `animation: name duration timing [delay] infinite [alternate]`.
  static ({StopMotion motion, double period, double delay})? _animation(
    String? style,
  ) {
    if (style == null) return null;
    final m = RegExp(r'animation:\s*([^;]+)').firstMatch(style);
    if (m == null) return null;
    final parts = m.group(1)!.trim().split(RegExp(r'\s+'));
    final motion = switch (parts.first) {
      'smoke' => StopMotion.smoke,
      'glow' => StopMotion.glow,
      'flick' => StopMotion.flick,
      'sway' => StopMotion.sway,
      'laugh' => StopMotion.laugh,
      'reachL' => StopMotion.reachLeft,
      'reachR' => StopMotion.reachRight,
      _ => null,
    };
    if (motion == null) return null;
    final times = [
      for (final p in parts.skip(1))
        if (RegExp(r'^-?[\d.]+s$').hasMatch(p))
          double.parse(p.substring(0, p.length - 1)),
    ];
    return (
      motion: motion,
      period: times.isEmpty ? 1 : times.first,
      delay: times.length > 1 ? times[1] : 0,
    );
  }
}
