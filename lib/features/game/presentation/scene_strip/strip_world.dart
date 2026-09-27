import 'dart:math' as math;
import 'dart:ui';

import 'strip_kit.dart';
import 'strip_shapes.dart';

/// The paths the strip knows how to draw: the forest (14a) and the five of
/// round 4 (16a–16e).
enum StripBiome {
  forest,
  mountains,
  coast,
  desert,
  floodlands,
  graveyard;

  /// A `Biome.id` from the content. Anything the strip has no path for —
  /// the tavern, a biome added later — walks through the forest.
  static StripBiome fromId(String id) => switch (id) {
    'mountains' => mountains,
    'coast' => coast,
    'desert' => desert,
    'floodlands' => floodlands,
    'graveyard' => graveyard,
    _ => forest,
  };
}

/// The layers, back to front. Items stream on the named ones; the rest are
/// tone (sky, fog, ground band) or the walking party.
enum StripLayer { far, midfar, mid, ground, near }

/// dp per second the party walks: two dash periods per 1100 ms stride, so
/// the feet do not slide.
const double kRoadSpeed = 18 / 1.1;

/// One stream of items on a layer, drawn from its own generator so the same
/// seed grows the same forest however far it has been filled.
final class StripStream {
  final StripLayer layer;
  final double ratio;
  final Rng r;
  final StripShape Function() make;
  final double Function(Rng r) gap;
  final bool tag;
  final List<StripItem> items = [];
  double edge;

  /// Set when the biome changes: the stream stops placing items, and goes
  /// once its last one has left the strip.
  bool done = false;

  /// Set on the new far and second-plane streams of a biome change: they
  /// are laid out across the strip at once and fade in with the tone.
  bool fadingIn = false;

  /// How far past the left edge an item is kept before it is dropped. A
  /// stream driving off for good lets its items go as soon as they are out
  /// of sight.
  double leaveMargin = 80;

  StripStream({
    required this.layer,
    required this.ratio,
    required this.r,
    required this.make,
    required this.gap,
    this.tag = false,
  }) : edge = -80 - r() * 60;

  /// Places items until the stream reaches past [right], and drops the ones
  /// that have gone off the left — both measured at scroll offset [off].
  void fill(double off, double right) {
    while (!done && edge - off < right) {
      final shape = make(), x = edge;
      final g = gap(r);
      edge = x + shape.w + g;
      items.add(StripItem(x, shape));
    }
    while (items.isNotEmpty &&
        items.first.x + items.first.shape.w - off < -leaveMargin) {
      items.removeAt(0).dispose();
    }
  }

  /// Drops every item that has not yet come onto a strip [width] wide at
  /// scroll offset [off] — for a stream the party will never walk past.
  void dropUnseen(double off, double width) {
    while (items.isNotEmpty && items.last.x - off > width) {
      items.removeLast().dispose();
    }
  }

  /// The far and second planes: in fog, they read as the backdrop.
  bool get backdrop => layer == StripLayer.far || layer == StripLayer.midfar;
}

/// A placed item. Its drawing is recorded once, when it appears; after that
/// the strip only moves it.
final class StripItem {
  final double x;
  final StripShape shape;
  Picture? _picture;

  StripItem(this.x, this.shape);

  Picture get picture => _picture ??= _record(shape.prims);

  void dispose() => _picture?.dispose();
}

Picture _record(List<StripPrim> prims) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  for (final p in prims) {
    p.paint(canvas);
  }
  return recorder.endRecording();
}

typedef _Spec = ({
  StripLayer layer,
  double ratio,
  Rng r,
  StripShape Function() make,
  double Function(Rng r) gap,
  bool tag,
});

double Function(Rng) _range(double a, double b) =>
    (r) => a + r() * (b - a);

double Function(Rng) _gapR(
  StripGeo g,
  double p,
  double a0,
  double a1,
  double b0,
  double b1,
) =>
    (r) => (r() < p ? a0 + r() * (a1 - a0) : b0 + r() * (b1 - b0)) * g.k;

/// Every stream of [biome], seeded by [seed] — `buildLayers` in the
/// prototype, for the forest of round 2 and the paths of round 4.
List<StripStream> buildStreams(StripGeo g, int seed, StripBiome biome) {
  var count = 0;
  Rng next() => stripRng(seed * 7919 + (++count) * 104729);
  final r1 = next(),
      r2 = next(),
      r3 = next(),
      r4 = next(),
      r5 = next(),
      r6 = next(),
      r7 = next();
  final specs = _layers(g, biome, [r1, r2, r3, r4, r5, r6, r7]);
  return [
    for (final s in specs)
      StripStream(
        layer: s.layer,
        ratio: s.ratio,
        r: s.r,
        make: s.make,
        gap: s.gap,
        tag: s.tag,
      ),
  ];
}

List<_Spec> _layers(StripGeo g, StripBiome biome, List<Rng> rs) {
  final [r1, r2, r3, r4, r5, r6, r7] = rs;
  final gy = g.gy, k = g.k, hy = gy - g.h * 0.3, nearC = StripColors.near;
  final t = pathTone(biome);
  _Spec s(
    StripLayer layer,
    double ratio,
    Rng r,
    StripShape Function() make,
    double Function(Rng) gap, {
    bool tag = false,
  }) => (layer: layer, ratio: ratio, r: r, make: make, gap: gap, tag: tag);
  const far = StripLayer.far,
      midfar = StripLayer.midfar,
      mid = StripLayer.mid,
      ground = StripLayer.ground,
      near = StripLayer.near;

  switch (biome) {
    case StripBiome.forest:
      return [
        s(
          far,
          0.15,
          r1,
          () => fir(r1, g, StripColors.far, 0.32, 0.52, gy - g.h * 0.14),
          _range(-9 * k, 4 * k),
        ),
        s(
          midfar,
          0.35,
          r2,
          () => pick(r2, [
            (3, () => midfarTrunk(r2, g)),
            (
              1,
              () => fir(r2, g, StripColors.midfar, 0.5, 0.75, gy - g.h * 0.05),
            ),
          ]),
          (r) => (r() < 0.3 ? (18 + r() * 30) : (3 + r() * 12)) * k,
        ),
        s(
          mid,
          0.6,
          r3,
          () => midTrunk2(r3, g),
          (r) => (r() < 0.26 ? (12 + r() * 26) : (0.5 + r() * 7)) * k,
        ),
        s(
          mid,
          0.6,
          r4,
          () => canopy2(r4, g),
          (r) => (r() < 0.3 ? (4 + r() * 18) : -(4 + r() * 20)) * k,
        ),
        s(ground, 1, r5, () => tuft(r5, g), _range(8, 46)),
        s(near, 1.7, r6, () => nearTrunk(r6, g), _range(150, 400), tag: true),
        s(
          near,
          1.7,
          r7,
          () => pick(r7, [(3, () => fern(r7, g)), (2, () => bump(r7, g))]),
          _range(20 * k, 120 * k),
        ),
      ];
    case StripBiome.mountains:
      return [
        s(far, 0.15, r1, () => peak4(r1, g, t!), (r) => -(14 + r() * 30) * k),
        s(
          midfar,
          0.35,
          r2,
          () => pick(r2, [
            (
              3,
              () => spire4(
                r2,
                g,
                t!.midfar,
                hex('#43484F'),
                gy - g.h * 0.06,
                0.3,
                0.62,
              ),
            ),
            (
              1.4,
              () => tierPine(r2, g, t!.midfar, gy - g.h * 0.06, 0.28, 0.42),
            ),
          ]),
          _gapR(g, 0.35, 20, 60, -8, 8),
        ),
        s(
          mid,
          0.6,
          r3,
          () => pick(r3, [
            (2, () => tierPine(r3, g, t!.mid, gy + 1, 0.46, 0.7)),
            (
              1.5,
              () => spire4(r3, g, t!.mid, hex('#222529'), gy + 1, 0.22, 0.42),
            ),
          ]),
          _gapR(g, 0.4, 30, 80, 2, 16),
        ),
        s(ground, 1, r5, () => tuft(r5, g), _range(8, 60)),
        s(
          near,
          1.7,
          r6,
          () => pick(r6, [
            (1, () => crag4(r6, g, 0.02, 0.3, true)),
            (1.4, () => angular4(r6, g, nearC, 36, 64)),
          ]),
          _range(150, 380),
          tag: true,
        ),
        s(
          near,
          1.7,
          r7,
          () => pick(r7, [
            (3, () => angular4(r7, g, nearC, 10, 24)),
            (1, () => grass(r7, g, g.h + 1, nearC, 6, 12)),
          ]),
          _range(24, 120),
        ),
      ];
    case StripBiome.coast:
      return [
        s(
          far,
          0.15,
          r1,
          () => headland4(r1, g, t!, hy),
          _range(30 * k, 160 * k),
        ),
        s(
          midfar,
          0.35,
          r2,
          () => spire4(
            r2,
            g,
            t!.midfar,
            hex('#40454C'),
            hy + (gy - hy) * 0.55,
            0.1,
            0.28,
          ),
          _range(16 * k, 110 * k),
        ),
        s(
          mid,
          0.6,
          r3,
          () => pick(r3, [
            (3, () => boulder4(r3, g, t!.mid, 14, 30, gy + 1)),
            (0.8, () => wreck4(r3, g)),
          ]),
          _gapR(g, 0.3, 50, 120, 10, 40),
        ),
        s(
          ground,
          1,
          r5,
          () => grass(r5, g, gy + 0.5, StripColors.ground, 3, 7),
          _range(6, 40),
        ),
        s(
          near,
          1.7,
          r6,
          () => boulder4(r6, g, nearC, 34, 70),
          _range(140, 360),
          tag: true,
        ),
        s(
          near,
          1.7,
          r7,
          () => pick(r7, [
            (1, () => driftwood4(r7, g)),
            (2, () => grass(r7, g, g.h + 1, nearC, 10, 26, 'трава дюн')),
            (1, () => boulder4(r7, g, nearC, 8, 16)),
          ]),
          _range(24, 110),
        ),
      ];
    case StripBiome.desert:
      return [
        s(far, 0.15, r1, () => butte4(r1, g, t!), _range(-4 * k, 50 * k)),
        s(
          midfar,
          0.35,
          r2,
          () => pick(r2, [
            (4, () => dune4(r2, g, t!.midfar, t.midfarS!, gy - 2, 0.1, 0.2)),
            (1, () => butte4(r2, g, t!.withFar(t.midfar))),
          ]),
          (r) => -(26 + r() * 30) * k,
        ),
        s(
          mid,
          0.6,
          r3,
          () => pick(r3, [
            (3, () => dune4(r3, g, t!.mid, t.midS!, gy + 1, 0.06, 0.12)),
            (0.6, () => skeleton4(r3, g, hex('#5C6168'))),
          ]),
          _gapR(g, 0.35, 40, 110, -14, 6),
        ),
        s(
          mid,
          0.6,
          r4,
          () => stump4(r4, g, t!.mid, gy + 1),
          (r) => 430 + r() * 700,
        ),
        s(ground, 1, r5, () => tuft(r5, g), _range(30, 120)),
        s(
          near,
          1.7,
          r6,
          () => pick(r6, [
            (1, () => crag4(r6, g, 0.12, 0.45, false, true)),
            (1, () => boulder4(r6, g, nearC, 34, 66)),
          ]),
          _range(140, 360),
          tag: true,
        ),
        s(
          near,
          1.7,
          r7,
          () => pick(r7, [
            (2, () => thorn4(r7, g, 14, 28)),
            (1, () => boulder4(r7, g, nearC, 8, 18)),
          ]),
          _range(30, 150),
        ),
      ];
    case StripBiome.floodlands:
      StripShape drown(Rng r, Color col, double b, double hs, double sw) {
        final tree = deadTree4(r, g, col, b, hs, sw);
        return StripShape(tree.w, 'дерево в воде', [
          ...tree.prims,
          ...refl(tree.prims, b),
        ]);
      }
      return [
        s(
          far,
          0.15,
          r1,
          () => pick(r1, [
            (3, () => bushLine(r1, g, t!.far, hy + 0.4)),
            (1, () => deadTree4(r1, g, t!.far, hy + 0.4, 0.34, 1)),
          ]),
          _range(4 * k, 50 * k),
        ),
        s(
          midfar,
          0.35,
          r2,
          () => drown(r2, t!.midfar, hy + (gy - hy) * 0.45, 0.45, 1),
          _range(14 * k, 80 * k),
        ),
        s(
          mid,
          0.6,
          r3,
          () => pick(r3, [
            (2, () => drown(r3, t!.mid, gy - 2.4, 0.66, 1.2)),
            (2, () => posts4(r3, g, t!.mid, gy - 2.4)),
            (0.6, () => sunkBarn(r3, g, t!.mid, gy - 2.4)),
          ]),
          _gapR(g, 0.3, 50, 110, 8, 34),
        ),
        s(
          ground,
          1,
          r5,
          () => boulder4(r5, g, hex('#111315'), 4, 9, gy + 0.4),
          _range(14, 70),
        ),
        s(near, 1.7, r6, () => stake4(r6, g), _range(140, 360), tag: true),
        s(
          near,
          1.7,
          r7,
          () => pick(r7, [
            (3, () => cattail4(r7, g)),
            (1, () => sunkLog(r7, g)),
            (2, () => ripple(r7, g, gy + 5, g.h - 1)),
          ]),
          _range(16, 90),
        ),
      ];
    case StripBiome.graveyard:
      return [
        s(
          far,
          0.15,
          r1,
          () => pick(r1, [
            (1, () => chapel4(r1, g, t!, gy - g.h * 0.14)),
            (2.4, () => deadTree4(r1, g, t!.far, gy - g.h * 0.14, 0.5, 1)),
            (1.6, () => tombstone(r1, g, t!.far, gy - g.h * 0.14)),
          ]),
          _range(6 * k, 50 * k),
        ),
        s(
          midfar,
          0.35,
          r2,
          () => pick(r2, [
            (2, () => deadTree4(r2, g, t!.midfar, gy - 4, 0.6, 1.1)),
            (1, () => mausoleum4(r2, g, t!.midfar, gy - 4)),
            (2, () => tombstone(r2, g, t!.midfar, gy - 4)),
          ]),
          _range(6 * k, 50 * k),
        ),
        s(
          mid,
          0.6,
          r3,
          () => pick(r3, [
            (6, () => tombstone(r3, g, t!.mid, gy + 1)),
            (0.6, () => deadTree4(r3, g, t!.mid, gy + 1, 0.7, 1.2)),
          ]),
          _gapR(g, 0.25, 24, 60, 1, 8),
        ),
        s(ground, 1, r5, () => tuft(r5, g), _range(8, 46)),
        s(near, 1.7, r6, () => hangTree(r6, g), _range(220, 520), tag: true),
        s(
          near,
          1.7,
          r7,
          () => pick(r7, [
            (2, () => tomb4(r7, g)),
            (2, () => wrought4(r7, g)),
            (1, () => grass(r7, g, g.h + 1, nearC, 8, 16)),
          ]),
          _range(8, 70),
        ),
      ];
  }
}

/// The round 4 tone of a path; the forest keeps its own, older palette and
/// has none.
PathTone? pathTone(StripBiome biome) => switch (biome) {
  StripBiome.forest => null,
  StripBiome.mountains => PathTone(
    skyHor: '#7C828C',
    far: '#70767F',
    snow: '#AEB4BD',
  ),
  StripBiome.coast => PathTone(),
  StripBiome.desert => PathTone(
    skyHor: '#83888F',
    far: '#72777F',
    midfar: '#60656C',
    midfarS: '#484C53',
    mid: '#3B3E44',
    midS: '#26292D',
    fogA: 0.6,
  ),
  StripBiome.floodlands => PathTone(far: '#646A73'),
  StripBiome.graveyard => PathTone(skyHor: '#72787F'),
};

/// The four tone slots of a biome — sky, the two fogs and the ground band —
/// with every sky and fog colour already brought under the anchors.
final class StripTone {
  final List<Color> skyColors;
  final List<double> skyStops;
  final Color fog1, fog2;
  final double fog1A, fog2A;
  final double fog1Top, fog1Bottom, fog2Top, fog2Bottom;
  final StripBiome biome;

  StripTone._(
    this.biome, {
    required this.skyColors,
    required this.skyStops,
    required this.fog1,
    required this.fog1A,
    required this.fog1Top,
    required this.fog1Bottom,
    required this.fog2,
    required this.fog2A,
    required this.fog2Top,
    required this.fog2Bottom,
  });

  factory StripTone.of(StripBiome biome, StripGeo g) {
    final t = pathTone(biome);
    final cap = StripAnchors.cap;
    if (t == null) {
      return StripTone._(
        biome,
        skyColors: [
          StripColors.skyTop,
          cap(StripColors.skyHor),
          cap(StripColors.skyHor),
        ],
        skyStops: [0, (g.gy - g.h * 0.18) / g.h, 1],
        fog1: cap(hex('#565C66')),
        fog1A: 0.5,
        fog1Top: g.gy - g.h * 0.4,
        fog1Bottom: g.gy - g.h * 0.02,
        fog2: cap(hex('#4A5059')),
        fog2A: 0.42,
        fog2Top: g.gy - g.h * 0.3,
        fog2Bottom: g.gy + 2,
      );
    }
    return StripTone._(
      biome,
      skyColors: [cap(t.skyTop), cap(t.skyHor), cap(t.skyLow), cap(t.skyLow)],
      skyStops: [0, t.hor, g.gy / g.h, 1],
      fog1: cap(t.fog),
      fog1A: t.fogA,
      fog1Top: g.gy - g.h * 0.62,
      fog1Bottom: g.gy - g.h * 0.06,
      fog2: cap(t.fog2),
      fog2A: t.fog2A,
      fog2Top: g.gy - g.h * 0.34,
      fog2Bottom: g.gy + 2,
    );
  }

  /// Every colour this tone paints the sky and fog with — what the anchors
  /// are checked against.
  List<Color> get skyAndFog => [...skyColors, fog1, fog2];
}

/// The strip's world: its streams, its clock, and the biome it is walking
/// through, including a biome change in progress.
///
/// A change is 17b with the backdrop and the pace adjusted for play, where
/// the strip only moves between cards:
/// - the far and second planes are fog, and read as the backdrop: the old
///   ones fade out with the sky over [kToneFade] while the new ones, laid
///   across the whole strip at once, fade in;
/// - the middle plane, the ground and the near plane drive off as in 17b,
///   but only what the table can already see — anything still waiting past
///   the right edge is dropped on the spot;
/// - and while they drive off the party hurries: the road runs at [kHurry]
///   times its pace, the steps quicken, and it eases back once the last of
///   the old biome is gone. See [changing].
final class StripWorld {
  final StripGeo geo;
  double width;

  /// Seconds the strip has been moving, and how far the road has gone —
  /// separate, since the road runs faster during a change.
  double time = 0;
  double distance = 0;

  /// Where the party is in its stride, in strides; quickens with the road.
  double stride = 0;
  StripBiome biome;
  int _currentSeed;
  final List<StripStream> streams = [];

  /// The biome being left and when the change began; its tone fades out
  /// over [kToneFade] while the new one fades in.
  StripBiome? fromBiome;
  double changedAt = 0;

  static const double kToneFade = 2.5;
  static const double kHurry = 4;
  static const double kHurryIn = 0.6;
  static const double kHurryOut = 1.2;

  double _pace = 1;
  double? _slowingSince;
  double _slowingFrom = 1;

  StripWorld({
    required this.geo,
    required this.width,
    required this.biome,
    required int seed,
  }) : _currentSeed = seed {
    streams.addAll(buildStreams(geo, _currentSeed, biome));
    for (final s in streams) {
      s.fill(0, width + 80);
    }
  }

  double offsetOf(StripStream s) => distance * s.ratio;

  /// How many times its usual pace the road is running.
  double get pace => _pace;

  /// Whether a biome change is still playing out: the backdrop still
  /// fading, the old foreground not yet gone, or the party not yet back to
  /// its pace. The walk waits for it — a card drawn in the middle would land
  /// on a half-changed road.
  bool get changing =>
      fromBiome != null || _oldForegroundLeft || _pace > 1 + 1e-6;

  bool get _oldForegroundLeft => streams.any((s) => s.done && !s.backdrop);

  /// Moves the world on by [dt] seconds.
  void advance(double dt) {
    time += dt;
    _pace = _paceNow();
    distance += dt * kRoadSpeed * _pace;
    stride += dt / 1.1 * _pace;
    for (var i = streams.length - 1; i >= 0; i--) {
      final s = streams[i];
      s.fill(offsetOf(s), width + 80);
      if (s.done && s.items.isEmpty) streams.removeAt(i);
    }
    if (fromBiome != null && time - changedAt >= kToneFade) {
      fromBiome = null;
      // The old backdrop has faded out completely; let it go.
      for (var i = streams.length - 1; i >= 0; i--) {
        final s = streams[i];
        if (s.done && s.backdrop) {
          for (final item in s.items) {
            item.dispose();
          }
          streams.removeAt(i);
        } else {
          s.fadingIn = false;
        }
      }
    }
  }

  double _paceNow() {
    if (_oldForegroundLeft) {
      _slowingSince = null;
      final up = ((time - changedAt) / kHurryIn).clamp(0.0, 1.0);
      return 1 + (kHurry - 1) * _ease(up);
    }
    if (_pace <= 1 && _slowingSince == null) return 1;
    // The old foreground is gone: ease back from wherever the pace got to.
    if (_slowingSince == null) {
      _slowingSince = time;
      _slowingFrom = _pace;
    }
    final down = ((time - _slowingSince!) / kHurryOut).clamp(0.0, 1.0);
    if (down >= 1) {
      _slowingSince = null;
      return 1;
    }
    return 1 + (_slowingFrom - 1) * (1 - _ease(down));
  }

  static double _ease(double t) =>
      t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;

  /// A new biome. See the class comment for how the change plays out. A new
  /// seed each time, so no forest repeats.
  void setBiome(StripBiome next) {
    if (next == biome) return;
    fromBiome = biome;
    changedAt = time;
    biome = next;
    for (final s in streams) {
      if (s.done) continue;
      s.done = true;
      if (!s.backdrop) {
        s.dropUnseen(offsetOf(s), width);
        s.leaveMargin = 0;
      }
    }
    _currentSeed = _currentSeed * 31 + 7;
    final fresh = buildStreams(geo, _currentSeed, next);
    for (final s in fresh) {
      if (s.backdrop) {
        // Laid across the strip now, as the stream's first fill would be.
        s.edge = offsetOf(s) - 80 - s.r() * 60;
        s.fadingIn = true;
        s.fill(offsetOf(s), width + 80);
      } else {
        s.edge = offsetOf(s) + width + 8 + s.r() * 40;
      }
    }
    streams.addAll(fresh);
  }

  /// How far the tone change has got, 0..1, eased in and out.
  double get toneProgress {
    if (fromBiome == null) return 1;
    return _ease(((time - changedAt) / kToneFade).clamp(0.0, 1.0));
  }

  void dispose() {
    for (final s in streams) {
      for (final i in s.items) {
        i.dispose();
      }
    }
  }
}
