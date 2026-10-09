import 'dart:math' as math;
import 'dart:ui';

import 'strip_fields.dart';
import 'strip_kit.dart';
import 'strip_shapes.dart';

/// The paths the strip knows how to draw: the forest (14a), the five of
/// round 4 (16a–16e), and the fields of the prologue (18).
enum StripBiome {
  forest,
  mountains,
  coast,
  desert,
  floodlands,
  graveyard,

  /// The open country the party walks out into from the house. Not a biome
  /// of the content: it is the prologue's, whatever biome the world says.
  fields;

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

/// How much brisker than 17b the party walks: the road, every layer with
/// it, and the steps.
const double kBasePace = 1.3;

/// Seconds a stride takes: 17b's 1100 ms, quickened by [kBasePace].
const double kStride = 1.1 / kBasePace;

/// dp per second the party walks: two dash periods per stride, so the feet
/// do not slide.
const double kRoadSpeed = 18 / kStride;

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

  /// Makes the next item knowing where it will stand — for the fences of
  /// the fields, which keep their wells a screen apart. Used instead of
  /// [make] when set.
  final StripShape Function(double x)? makeAt;

  /// Leaves out an item at x, w wide — for the first fill of the prologue,
  /// which keeps the yard and the first screen clear. The stream moves on
  /// past it all the same, as the prototype's does.
  bool Function(double x, double w)? skip;

  /// The house of the prologue: one item placed by hand, nothing more ever
  /// made — see [StripWorld.yard].
  final bool yard;

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
    this.makeAt,
    this.yard = false,
  }) : edge = -80 - r() * 60;

  /// Places items until the stream reaches past [right], and drops the ones
  /// that have gone off the left — both measured at scroll offset [off].
  void fill(double off, double right) {
    while (!done && edge - off < right) {
      final x = edge, shape = makeAt?.call(x) ?? make();
      final g = gap(r);
      edge = x + shape.w + g;
      if (skip?.call(x, shape.w) ?? false) continue;
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
  StripShape Function(double x)? makeAt,
});

/// What the fields need from the world they grow in: how dense they are
/// now, and how far apart the wells must stand.
final class FieldsSetting {
  /// The multiplier on the gaps (`FDENS`), read as each item is placed, so
  /// the fields can thin out as the party walks.
  final double Function() density;

  /// No two wells on the screen at once: a well comes only this far past
  /// the last one — the screen's width and a little more.
  final double wellGap;

  /// Where the last well stood: the yard's, at the start.
  final double firstWell;

  const FieldsSetting({
    required this.density,
    required this.wellGap,
    this.firstWell = -1e9,
  });
}

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
List<StripStream> buildStreams(
  StripGeo g,
  int seed,
  StripBiome biome, {
  FieldsSetting? fields,
}) {
  var count = 0;
  Rng next() => stripRng(seed * 7919 + (++count) * 104729);
  final r1 = next(),
      r2 = next(),
      r3 = next(),
      r4 = next(),
      r5 = next(),
      r6 = next(),
      r7 = next();
  final specs = _layers(g, biome, [r1, r2, r3, r4, r5, r6, r7], fields);
  return [
    for (final s in specs)
      StripStream(
        layer: s.layer,
        ratio: s.ratio,
        r: s.r,
        make: s.make,
        gap: s.gap,
        tag: s.tag,
        makeAt: s.makeAt,
      ),
  ];
}

List<_Spec> _layers(
  StripGeo g,
  StripBiome biome,
  List<Rng> rs, [
  FieldsSetting? fields,
]) {
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
    StripShape Function(double x)? makeAt,
  }) => (
    layer: layer,
    ratio: ratio,
    r: r,
    make: make,
    gap: gap,
    tag: tag,
    makeAt: makeAt,
  );
  const far = StripLayer.far,
      midfar = StripLayer.midfar,
      mid = StripLayer.mid,
      ground = StripLayer.ground,
      near = StripLayer.near;

  switch (biome) {
    case StripBiome.fields:
      // The prologue's open country (`fieldsLayers`). Gaps are divided by
      // the density as each item is placed, so the fields thin out.
      final setting =
          fields ??
          FieldsSetting(density: () => kFields, wellGap: double.infinity);
      double dn() => setting.density();
      double Function(Rng) dense(double a, double b) =>
          (r) => (a + r() * (b - a)) / dn();
      final tone = pathTone(biome)!;
      var fences = 0;
      var lastWell = setting.firstWell;
      StripShape fence(double x) {
        if (++fences % 4 == 2 && x - lastWell >= setting.wellGap) {
          lastWell = x;
          return well(g);
        }
        return pick(r4, [
          (2, () => pletyen(r4, g)),
          (2, () => zherdi(r4, g)),
          (1.4, () => palisade(r4, g)),
          (0.8, () => stone(r4, g)),
        ]);
      }

      return [
        s(
          far,
          0.15,
          r1,
          () => farFields(r1, g, tone, gy - g.h * 0.16),
          (r) => -(12 + r() * 30) * k,
        ),
        s(
          midfar,
          0.35,
          r2,
          () => pick(r2, [
            (3, () => treeGroup(r2, g, tone.midfar, gy - 3, 0.24, 0.36, 3)),
            (1.2, () => crownTree(r2, g, tone.midfar, gy - 3, 0.26, 0.38)),
            (1, () => bushLine(r2, g, tone.midfar, gy - 3)),
            (0.8, () => stog(r2, g, tone.midfar, gy - 3)),
          ]),
          dense(50 * k, 200 * k),
        ),
        s(
          mid,
          0.6,
          r3,
          () => pick(r3, [
            (3, () => crownTree(r3, g, tone.mid, gy + 1, 0.62, 0.9)),
            (
              1.2 * dn(),
              () => treeGroup(r3, g, tone.mid, gy + 1, 0.52, 0.8, 3),
            ),
            (1, () => kopna(r3, g, tone.mid, gy + 1)),
            (0.5, () => scarecrow(r3, g, tone.mid, gy + 1)),
          ]),
          dense(70, 240),
        ),
        s(ground, 1, r5, () => tuft(r5, g), _range(10, 50)),
        s(
          ground,
          1,
          r4,
          () => fence(double.negativeInfinity),
          dense(60, 200),
          makeAt: fence,
        ),
        s(
          near,
          1.7,
          r6,
          () => pick(r6, [
            (1, () => zherdiNear(r6, g)),
            (1.2, () => bushNear(r6, g)),
          ]),
          dense(260, 620),
          tag: true,
        ),
        s(
          near,
          1.7,
          r7,
          () => grass(r7, g, g.h + 1, nearC, 6, 14),
          dense(24, 100),
        ),
      ];
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
  StripBiome.fields => fieldsTone,
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

/// One walker in the party: where they walk, how bright they are, and how
/// far out of step with the others, so the party does not march.
typedef StripFigure = ({double x, double alpha, double phase});

/// The walking party for [count] players: the lead at 226 in the
/// prototype's 412-wide frame, the rest 13⅓ dp apart behind, the back one
/// dimmest. At four it is the prototype's `GROUP`.
List<StripFigure> stripGroup(int count) {
  final n = count.clamp(1, 8);
  const phases = [0.0, 0.3, 0.55, 0.8];
  return [
    for (var i = 0; i < n; i++)
      (
        x: 226 - (n - 1 - i) * 40 / 3,
        alpha: n == 1 ? 1.0 : 0.55 + 0.45 * i / (n - 1),
        phase: phases[i % 4] + (i ~/ 4) * 0.13,
      ),
  ];
}

/// The party walking out of the house (18a/18b, `prologue()`): the door
/// opens, they come out one by one with the lead first, and when the lead
/// reaches the middle the world starts moving, picking up to the road's
/// pace over [Prologue.ramp]. [ready] once everyone stands in place and the
/// world is at full pace — when the first card may come.
///
/// Every figure's step follows its speed over the ground, its own and the
/// world's together, so the feet do not slide.
final class StripPrologue {
  final List<StripFigure> group;

  /// Seconds since the party set off; nothing moves before [start].
  double time = 0;
  double? _walkFrom;

  /// Where each figure is (in the 412-wide frame) and how far into its
  /// stride.
  final List<double> x;
  final List<double> leg;

  bool ready = false;
  double? readyAt;

  StripPrologue(this.group)
    : x = [for (final _ in group) Prologue.doorX + 5],
      leg = [for (final f in group) f.phase];

  int get _lead => group.length - 1;

  /// When figure [i] steps out: the lead first, the back one last.
  double exitAt(int i) => Prologue.firstExit + (_lead - i) * Prologue.exitEvery;

  /// How visible figure [i] is: out of sight until it steps out, then
  /// coming out of the doorway's shadow over its first 5 dp.
  double opacity(int i) => time < exitAt(i)
      ? 0
      : (0.15 + (x[i] - Prologue.doorX - 5) / 5).clamp(0.0, 1.0).toDouble();

  /// The world's pace now.
  double get worldSpeed {
    final from = _walkFrom;
    if (from == null) return 0;
    final t = ((time - from) / Prologue.ramp).clamp(0.0, 1.0);
    return kRoadSpeed * t * t * (3 - 2 * t);
  }

  /// Moves the party on by [dt]; returns how fast the world moves.
  double tick(double dt) {
    time += dt;
    if (_walkFrom == null && x[_lead] >= Prologue.center) _walkFrom = time;
    final vw = worldSpeed;
    for (var i = 0; i < group.length; i++) {
      if (time < exitAt(i)) continue;
      final rem = group[i].x - x[i];
      final vs = rem <= 0
          ? 0.0
          : math.min(math.max(rem * 4, 6), math.max(0, Prologue.walk - vw));
      if (vs * dt >= rem) {
        x[i] = math.max(x[i], group[i].x);
      } else {
        x[i] += vs * dt;
      }
      leg[i] += dt * (vs + vw) / kRoadSpeed / kStride;
    }
    if (!ready &&
        vw >= kRoadSpeed * 0.999 &&
        [
          for (var i = 0; i < group.length; i++) group[i].x - x[i] < 0.01,
        ].every((d) => d)) {
      ready = true;
      readyAt = time;
    }
    return vw;
  }
}

/// The strip's world: its streams, its clock, and the biome it is walking
/// through, including a biome change in progress.
///
/// A change is 17b with the backdrop adjusted for play, where the strip only
/// moves between cards:
/// - the far and second planes are fog, and read as the backdrop: the old
///   ones fade out with the sky over [kToneFade] while the new ones, laid
///   across the whole strip at once, fade in;
/// - the middle plane, the ground and the near plane drive off as in 17b,
///   at the usual pace, but only what the table can already see — anything
///   still waiting past the right edge is dropped on the spot.
///
/// The walk does not wait for it: a card that comes while the old road is
/// still driving off simply stops the strip, and the rest drives off after.
final class StripWorld {
  final StripGeo geo;
  double width;

  /// Seconds the strip has been moving, and how far the road has gone.
  double time = 0;
  double distance = 0;

  /// Where the party is in its stride, in strides.
  double stride = 0;
  StripBiome biome;
  int _currentSeed;
  final List<StripStream> streams = [];

  /// The walking party.
  final List<StripFigure> group;

  /// Set when the match starts at the house: the party walks out of it, and
  /// the world waits for them. Kept after they are out — their steps carry
  /// on from where the walk-out left them.
  final StripPrologue? prologue;

  /// Where the walking party is centred on a strip wider or narrower than
  /// the prototype's 412: the house and the figures move together.
  double get dx => width / 2 - 206;

  /// The biome being left and when the change began; its tone fades out
  /// over [kToneFade] while the new one fades in.
  StripBiome? fromBiome;
  double changedAt = 0;

  static const double kToneFade = 2.5;

  StripWorld({
    required this.geo,
    required this.width,
    required this.biome,
    required int seed,
    int figures = 4,
    bool fromHome = false,
  }) : _currentSeed = seed,
       group = stripGroup(figures),
       prologue = fromHome ? StripPrologue(stripGroup(figures)) : null {
    final yardLeft = dx + Prologue.yardFrom, yardRight = dx + Prologue.yardTo;
    streams.addAll(
      buildStreams(
        geo,
        _currentSeed,
        biome,
        fields: FieldsSetting(
          density: () => fieldsDensity,
          wellGap: width + 40,
          firstWell: fromHome ? dx + Prologue.wellX : -1e9,
        ),
      ),
    );
    for (final s in streams) {
      // The first fill of the walk-out keeps the yard clear for the house,
      // and the near plane off the first screen (`prologue()`).
      if (fromHome && s.layer == StripLayer.near) {
        s.skip = (x, w) => x < width;
      } else if (fromHome && s.layer == StripLayer.ground) {
        s.skip = (x, w) => x < yardRight && x + w > yardLeft;
      }
      s.fill(0, width + 80);
      s.skip = null;
    }
    if (fromHome) {
      final yard = StripStream(
        layer: StripLayer.ground,
        ratio: 1,
        r: stripRng(seed),
        make: () => throw StateError('the house is built once'),
        gap: (_) => 0,
        yard: true,
      )..done = true;
      yard.items.add(StripItem(dx, house(geo)));
      streams.add(yard);
    }
  }

  /// How far the road has gone at which the fields have thinned from the
  /// yard's density to the open country's — about three cards' walking.
  static const double kThinOver = 360;

  /// The fields' density now: [kFieldsDense] by the house, easing to
  /// [kFields] over [kThinOver] dp of road. Only the fields read it.
  double get fieldsDensity {
    final t = (distance / kThinOver).clamp(0.0, 1.0);
    return kFieldsDense + (kFields - kFieldsDense) * t * t * (3 - 2 * t);
  }

  /// The house, while it is still on the strip.
  StripStream? get yard {
    for (final s in streams) {
      if (s.yard) return s;
    }
    return null;
  }

  double offsetOf(StripStream s) => distance * s.ratio;

  /// Moves the world on by [dt] seconds.
  void advance(double dt) {
    time += dt;
    final speed = prologue?.tick(dt) ?? kRoadSpeed;
    distance += dt * speed;
    stride += dt * speed / kRoadSpeed / kStride;
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
