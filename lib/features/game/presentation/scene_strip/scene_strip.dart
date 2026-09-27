import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/steel_palette.dart';
import 'stop_scenes.dart';
import 'strip_kit.dart';
import 'strip_world.dart';

/// Where the party has stopped, if anywhere.
enum StripStop { none, rest, tavern }

/// The live scene strip over the game: the party walking through the
/// current biome, ported from the Claude Design handoff (14a, 16a–16e, 17,
/// 17b). Replaces the stick figures of #28.
///
/// One ticker drives it, and only while [moving]: a dialog on top, a match
/// not yet begun or over, and the whole strip stands on the frame it was
/// on. Items are recorded to pictures once, as they appear; a frame only
/// moves them.
///
/// At a [stop] the road gives way to the stop's own scene (14b–14d, 15f),
/// entered through a darkening; the world behind stands where it was.
class SceneStrip extends StatefulWidget {
  /// `WorldState.currentBiomeId`.
  final String biomeId;
  final bool moving;
  final StripStop stop;

  /// Fixed for tests; left null, every match grows its own forest.
  final int? seed;

  /// Told when a biome change starts playing out and when it is over — the
  /// walk holds the next card until then.
  final ValueChanged<bool>? onChanging;

  static const double height = 56;

  const SceneStrip({
    super.key,
    required this.biomeId,
    required this.moving,
    this.stop = StripStop.none,
    this.seed,
    this.onChanging,
  });

  @override
  State<SceneStrip> createState() => SceneStripState();
}

class SceneStripState extends State<SceneStrip>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _repaint = ValueNotifier<int>(0);
  StripWorld? _world;
  Duration _last = Duration.zero;
  late final int _seed = widget.seed ?? math.Random().nextInt(1 << 30);
  late final _random = math.Random(_seed);
  final _tones = <(StripBiome, int, double), ui.Picture>{};

  StopScene? _stop;
  StopKind? _stopKind;
  double _stopTime = 0;

  /// Which halt was drawn for this stop — held until the party leaves.
  @visibleForTesting
  StopKind? get stopKind => _stopKind;

  /// The world being drawn — for tests, which check that it stands still.
  @visibleForTesting
  StripWorld? get world => _world;

  @override
  void didUpdateWidget(covariant SceneStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.biomeId != widget.biomeId) {
      _world?.setBiome(StripBiome.fromId(widget.biomeId));
      _reportChanging();
      _repaint.value++;
    }
    if (oldWidget.stop != widget.stop) _enterStop();
    _syncTicker();
  }

  /// Arriving at a stop builds its scene once; a halt draws one of its three
  /// variants at random and keeps it until the party gets up.
  void _enterStop() {
    _stop?.dispose();
    _stop = null;
    _stopKind = null;
    _stopTime = 0;
    final world = _world;
    if (world == null) return;
    switch (widget.stop) {
      case StripStop.none:
        break;
      case StripStop.tavern:
        _stopKind = StopKind.tavern;
        _stop = buildTavern();
      case StripStop.rest:
        _stopKind = const [
          StopKind.camp1,
          StopKind.camp2,
          StopKind.camp3,
        ][_random.nextInt(3)];
        // The forest is the halt as drawn; anywhere else the camp stands in
        // front of that biome's own far and middle planes, stopped.
        _stop = buildCamp(
          _stopKind!,
          environment: world.biome == StripBiome.forest,
        );
    }
    _repaint.value++;
  }

  bool _wasChanging = false;

  void _reportChanging() {
    final now = _world?.changing ?? false;
    if (now == _wasChanging) return;
    _wasChanging = now;
    widget.onChanging?.call(now);
  }

  void _syncTicker() {
    if (widget.moving && _world != null && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!widget.moving && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    // A long gap — a stall, the first frame back — is not walked through in
    // one leap: the prototype caps a frame at 50 ms, and so does this.
    final dt = math.min(0.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    if (_stop != null) {
      _stopTime += dt;
    } else {
      _world!.advance(dt);
      _reportChanging();
    }
    _repaint.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _world?.dispose();
    _stop?.dispose();
    for (final p in _tones.values) {
      p.dispose();
    }
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SceneStrip.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final world = _world ??= StripWorld(
            geo: StripGeo(SceneStrip.height),
            width: width,
            biome: StripBiome.fromId(widget.biomeId),
            seed: _seed,
          );
          world.width = width;
          if (_stop == null && widget.stop != StripStop.none) _enterStop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncTicker();
          });
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(width, SceneStrip.height),
                painter: SceneStripPainter(
                  world,
                  _repaint,
                  tones: _tones,
                  stop: () => _stop,
                  stopTime: () => _stopTime,
                  labelStyle: _labelStyle(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The stop's label: Nunito 600, 8 dp, spaced, at 72 % of the text tone.
TextStyle _labelStyle(BuildContext context) =>
    (Theme.of(context).textTheme.bodySmall ?? const TextStyle()).copyWith(
      fontSize: 8,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.4,
      height: 1,
      color: const Color.fromRGBO(216, 220, 224, 0.72),
    );

/// Paints a [StripWorld]: the tone slots and item layers in the prototype's
/// order, the walking party between the ground and the near plane — or,
/// at a stop, the stop's scene over the world as it stood.
class SceneStripPainter extends CustomPainter {
  final StripWorld world;
  final Map<(StripBiome, int, double), ui.Picture> _tones;
  final StopScene? Function() _stop;
  final double Function() _stopTime;
  final TextStyle labelStyle;

  SceneStripPainter(
    this.world,
    Listenable repaint, {
    Map<(StripBiome, int, double), ui.Picture>? tones,
    StopScene? Function()? stop,
    double Function()? stopTime,
    TextStyle? labelStyle,
  }) : _tones = tones ?? {},
       _stop = stop ?? (() => null),
       _stopTime = stopTime ?? (() => 0),
       labelStyle = labelStyle ?? const TextStyle(fontSize: 8),
       super(repaint: repaint);

  static const _sky = 0, _fog1 = 1, _fog2 = 2, _ground = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final stop = _stop();
    if (stop != null) {
      _paintStop(canvas, size, stop);
      canvas.restore();
      return;
    }

    _slot(canvas, _sky, w);
    _layer(canvas, StripLayer.far);
    _slot(canvas, _fog1, w);
    _layer(canvas, StripLayer.midfar);
    _slot(canvas, _fog2, w);
    _layer(canvas, StripLayer.mid);
    _slot(canvas, _ground, w);
    _layer(canvas, StripLayer.ground);
    _figures(canvas, w);
    _layer(canvas, StripLayer.near);
    _edges(canvas, size);

    canvas.restore();
  }

  void _paintStop(Canvas canvas, Size size, StopScene stop) {
    final w = size.width, t = _stopTime();
    final ownSky = stop.label == 'ТАВЕРНА' || world.biome == StripBiome.forest;
    if (ownSky) {
      paintStopSky(canvas, size);
    } else {
      // The biome the party stopped in, as it stood when they sat down.
      _slot(canvas, _sky, w);
      _layer(canvas, StripLayer.far);
      _slot(canvas, _fog1, w);
      _layer(canvas, StripLayer.midfar);
      _slot(canvas, _fog2, w);
      _layer(canvas, StripLayer.mid);
      _slot(canvas, _ground, w);
    }
    paintStop(canvas, stop, t, dx: w - kStopWidth);
    paintStopShade(canvas, size, stop.label, labelStyle, t);
    _edges(canvas, size);
  }

  void _layer(Canvas canvas, StripLayer layer) {
    final p = world.toneProgress;
    for (final s in world.streams) {
      if (s.layer != layer) continue;
      // The backdrop of a biome change crossfades with the sky: the old far
      // planes out, the new ones in.
      final opacity = world.fromBiome == null
          ? 1.0
          : s.backdrop && s.done
          ? 1 - p
          : s.fadingIn
          ? p
          : 1.0;
      if (opacity <= 0) continue;
      if (opacity < 1) {
        canvas.saveLayer(
          Rect.fromLTWH(0, 0, world.width, world.geo.h),
          Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
        );
      }
      final off = world.offsetOf(s);
      for (final item in s.items) {
        canvas.save();
        canvas.translate(item.x - off, 0);
        canvas.drawPicture(item.picture);
        canvas.restore();
      }
      if (opacity < 1) canvas.restore();
    }
  }

  /// A tone slot, crossfading from the biome being left while a change is
  /// under way (17b). The near plane and the ground band do not change.
  void _slot(Canvas canvas, int slot, double w) {
    final from = world.fromBiome;
    final p = world.toneProgress;
    if (from == null || p >= 1) {
      canvas.drawPicture(_tone(world.biome, slot, w));
      return;
    }
    _faded(canvas, _tone(from, slot, w), 1 - p, w);
    _faded(canvas, _tone(world.biome, slot, w), p, w);
  }

  void _faded(Canvas canvas, ui.Picture picture, double opacity, double w) {
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, w, world.geo.h),
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
    );
    canvas.drawPicture(picture);
    canvas.restore();
  }

  ui.Picture _tone(StripBiome biome, int slot, double w) =>
      _tones[(biome, slot, w)] ??= _recordTone(biome, slot, w);

  ui.Picture _recordTone(StripBiome biome, int slot, double w) {
    final g = world.geo;
    final tone = StripTone.of(biome, g);
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    switch (slot) {
      case _sky:
        c.drawRect(
          Rect.fromLTWH(0, 0, w, g.h),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset.zero,
              Offset(0, g.h),
              tone.skyColors,
              tone.skyStops,
            ),
        );
        _back(c, biome, w);
      case _fog1:
        _fog(c, w, tone.fog1Top, tone.fog1Bottom, tone.fog1, tone.fog1A);
      case _fog2:
        _fog(c, w, tone.fog2Top, tone.fog2Bottom, tone.fog2, tone.fog2A);
      case _ground:
        if (biome == StripBiome.floodlands) {
          c.drawRect(
            Rect.fromLTWH(0, g.gy - 0.6, w, 3.8),
            Paint()..color = StripAnchors.ground,
          );
          c.drawRect(
            Rect.fromLTWH(0, g.gy + 3.2, w, 1.6),
            Paint()..color = StripAnchors.ground.withValues(alpha: 0.3),
          );
        } else {
          c.drawRect(
            Rect.fromLTWH(0, g.gy, w, g.h - g.gy),
            Paint()..color = StripAnchors.ground,
          );
        }
    }
    return recorder.endRecording();
  }

  void _fog(Canvas c, double w, double y0, double y1, Color color, double a) {
    c.drawRect(
      Rect.fromLTWH(0, y0, w, y1 - y0),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y0),
          Offset(0, y1),
          [
            color.withValues(alpha: 0),
            color.withValues(alpha: a),
            color.withValues(alpha: 0),
          ],
          const [0, 0.55, 1],
        ),
    );
  }

  /// What stands behind the far plane: the sea, the desert sun, the flood.
  void _back(Canvas c, StripBiome biome, double w) {
    final g = world.geo, hy = g.gy - g.h * 0.3;
    switch (biome) {
      case StripBiome.coast:
        c.drawRect(
          Rect.fromLTWH(0, hy, w, g.gy - hy + 1),
          Paint()..color = hex('#5C626B'),
        );
        _line(c, 0, w, hy, hex('#8C929B'), 0.7);
        _shimmer(c, 0, w, hy + 1, g.gy, 3, hex('#A4AAB3', 0.5));
      case StripBiome.desert:
        final sun = StripAnchors.skyMax;
        c.drawCircle(
          Offset(w * 0.8, g.h * 0.3),
          13,
          Paint()..color = sun.withValues(alpha: 0.35),
        );
        c.drawCircle(Offset(w * 0.8, g.h * 0.3), 6.5, Paint()..color = sun);
        _shimmer(
          c,
          w * 0.7,
          w * 0.9,
          g.h * 0.3,
          g.h * 0.42,
          9,
          hex('#8C929B', 0.4),
        );
      case StripBiome.floodlands:
        final mx = w * 0.72, my = g.h * 0.2;
        c.drawRect(
          Rect.fromLTWH(0, hy, w, g.h - hy),
          Paint()
            ..shader = ui.Gradient.linear(Offset(0, hy), Offset(0, g.h), [
              hex('#686E77'),
              hex('#3A3E45'),
            ]),
        );
        _line(c, 0, w, hy, hex('#8C929B'), 0.6);
        c.drawCircle(Offset(mx, my), 4.4, Paint()..color = StripAnchors.skyMax);
        c.drawRect(
          Rect.fromLTWH(mx - 2.4, hy + 0.6, 4.8, g.h - hy),
          Paint()..color = StripAnchors.skyMax.withValues(alpha: 0.22),
        );
        _shimmer(c, 0, w, hy + 1, g.h, 7, hex('#A4AAB3', 0.4));
      case StripBiome.forest:
      case StripBiome.mountains:
      case StripBiome.graveyard:
        break;
    }
  }

  void _line(
    Canvas c,
    double x0,
    double x1,
    double y,
    Color color,
    double width,
  ) => c.drawLine(
    Offset(x0, y),
    Offset(x1, y),
    Paint()
      ..color = color
      ..strokeWidth = width,
  );

  /// Glints on water: short dashes at random, from a fixed seed so they hold
  /// still under the moving world.
  void _shimmer(
    Canvas c,
    double x0,
    double x1,
    double y0,
    double y1,
    int seed,
    Color color,
  ) {
    final r = stripRng(seed);
    final path = ui.Path();
    for (var y = y0 + 1; y < y1; y += 2.2 + r() * 1.6) {
      var x = x0 + r() * 30;
      while (x < x1) {
        final l = 3 + r() * 16;
        path
          ..moveTo(x, y)
          ..lineTo(x + l, y);
        x += l + 8 + r() * 40;
      }
    }
    c.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  /// The walking party: four figures, the same proportions and 1100 ms
  /// stride as before, a step apart in phase so they do not march.
  static const _group = [
    (186.0, 0.55, 0.0),
    (199.0, 0.7, 0.3),
    (212.0, 0.85, 0.55),
    (226.0, 1.0, 0.8),
  ];

  void _figures(Canvas canvas, double w) {
    final dx = w / 2 - 206, foot = world.geo.gy - 1;
    for (final (x0, alpha, phase) in _group) {
      final colour = StripColors.figure.withValues(alpha: alpha);
      final t = world.stride + phase;
      final a = math.sin(t * 2 * math.pi) * 0.42;
      const leg = 8.0;
      final x = x0 + dx;
      final hip = Offset(x, foot - leg * math.cos(a));
      final sh = Offset(hip.dx + 0.6, hip.dy - 8);
      final path = ui.Path()
        ..moveTo(hip.dx, hip.dy)
        ..lineTo(sh.dx, sh.dy);
      for (final s in const [1, -1]) {
        final b = a * s;
        path
          ..moveTo(hip.dx, hip.dy)
          ..relativeLineTo(math.sin(b) * leg, math.cos(b) * leg);
        final arm = -b * 0.8;
        path
          ..moveTo(sh.dx, sh.dy + 1)
          ..relativeLineTo(math.sin(arm) * 6, math.cos(arm) * 6);
      }
      final stroke = Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.35
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, stroke);
      final head = Offset(sh.dx + 0.5, sh.dy - 3.6);
      canvas.drawCircle(head, 2.3, Paint()..color = StripColors.mid);
      canvas.drawCircle(head, 2.3, stroke);
    }
  }

  /// The ends fade into the screen, so the strip reads as a window.
  void _edges(Canvas canvas, Size size) {
    const fade = 24.0;
    final bg = SteelPalette.background;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, fade, size.height),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(fade, 0), [
          bg,
          bg.withValues(alpha: 0),
        ]),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width - fade, 0, fade, size.height),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width - fade, 0),
          Offset(size.width, 0),
          [bg.withValues(alpha: 0), bg],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant SceneStripPainter old) => old.world != world;
}
