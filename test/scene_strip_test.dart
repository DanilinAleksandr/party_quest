import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/features/game/presentation/scene_strip/scene_strip.dart';
import 'package:drinking_quest/features/game/presentation/scene_strip/stop_scenes.dart';
import 'package:drinking_quest/features/game/presentation/scene_strip/strip_fields.dart';
import 'package:drinking_quest/features/game/presentation/scene_strip/strip_kit.dart';
import 'package:drinking_quest/features/game/presentation/scene_strip/strip_world.dart';
import 'package:drinking_quest/features/game/presentation/scene_strip/village_scene.dart';

StripWorld _world(StripBiome biome, {int seed = 17}) =>
    StripWorld(geo: StripGeo(56), width: 412, biome: biome, seed: seed);

Set<String> _types(
  StripWorld w,
  StripLayer layer, {
  bool Function(StripStream)? where,
}) => {
  for (final s in w.streams)
    if (s.layer == layer && (where == null || where(s)))
      for (final i in s.items) i.shape.type,
};

/// What the far plane of each path is allowed to hold.
const _farOf = {
  StripBiome.forest: {'ель'},
  StripBiome.mountains: {'пик'},
  StripBiome.coast: {'мыс', 'маяк'},
  StripBiome.desert: {'столовая гора', 'останец'},
  StripBiome.floodlands: {'кромка', 'мёртвое дерево'},
  StripBiome.graveyard: {'часовня', 'мёртвое дерево', 'надгробие', 'крест'},
  StripBiome.fields: {'поля'},
};

void main() {
  group('the stream follows the biome', () {
    test('every content biome id walks its own path', () {
      expect(StripBiome.fromId('forest'), StripBiome.forest);
      expect(StripBiome.fromId('mountains'), StripBiome.mountains);
      expect(StripBiome.fromId('coast'), StripBiome.coast);
      expect(StripBiome.fromId('desert'), StripBiome.desert);
      expect(StripBiome.fromId('floodlands'), StripBiome.floodlands);
      expect(StripBiome.fromId('graveyard'), StripBiome.graveyard);
      // No path of its own: through the forest rather than nothing.
      expect(StripBiome.fromId('tavern'), StripBiome.forest);
      expect(StripBiome.fromId('something_new'), StripBiome.forest);
    });

    for (final biome in StripBiome.values) {
      test('${biome.name}: the far plane holds only its own things', () {
        final w = _world(biome);
        for (var i = 0; i < 400; i++) {
          w.advance(0.05);
        }
        final far = _types(w, StripLayer.far);
        expect(far, isNotEmpty);
        expect(_farOf[biome]!.containsAll(far), isTrue, reason: '$far');
        w.dispose();
      });
    }

    test('the same seed grows the same forest', () {
      List<String> first(StripWorld w) => [
        for (final s in w.streams)
          for (final i in s.items) '${i.shape.type}@${i.x.toStringAsFixed(2)}',
      ];
      expect(
        first(_world(StripBiome.forest)),
        first(_world(StripBiome.forest)),
      );
    });
  });

  group('a biome change on the road (17b)', () {
    test('the old streams stop placing, drive off, and are gone', () {
      final w = _world(StripBiome.forest);
      w.advance(1);
      final old = List.of(w.streams);
      final placed = {for (final s in old) s: s.items.length};

      w.setBiome(StripBiome.mountains);
      expect(old.every((s) => s.done), isTrue);

      w.advance(0.05);
      // Nothing new on a finished stream; what was there keeps going.
      for (final s in old) {
        expect(s.items.length, lessThanOrEqualTo(placed[s]!));
      }

      // At the far plane's pace — 0.15 of the road — the last of it takes
      // minutes, as in the prototype, but it all leaves.
      for (var i = 0; i < 12000 && w.streams.any(old.contains); i++) {
        w.advance(0.05);
      }
      expect(w.streams.where(old.contains), isEmpty);
    });

    test(
      'the new foreground comes in from the right, the new backdrop is there at once',
      () {
        final w = _world(StripBiome.forest);
        w.advance(1);
        final old = List.of(w.streams);
        w.setBiome(StripBiome.coast);
        final fresh = w.streams.where((s) => !old.contains(s)).toList();
        for (final s in fresh) {
          if (s.backdrop) {
            // Laid across the strip, and fading in with the sky.
            expect(s.fadingIn, isTrue);
            expect(s.items.any((i) => i.x - w.offsetOf(s) < 412), isTrue);
          } else {
            for (final item in s.items) {
              expect(item.x - w.offsetOf(s), greaterThan(412));
            }
          }
        }
        for (var i = 0; i < 1200; i++) {
          w.advance(0.05);
        }
        expect(
          _farOf[StripBiome.coast]!.containsAll(
            _types(w, StripLayer.far, where: fresh.contains),
          ),
          isTrue,
        );
      },
    );

    test('the old backdrop fades out with the sky and is gone', () {
      final w = _world(StripBiome.forest);
      w.advance(1);
      final oldBackdrop = w.streams.where((s) => s.backdrop).toList();
      w.setBiome(StripBiome.mountains);
      w.advance(1.2);
      expect(w.streams.where(oldBackdrop.contains), isNotEmpty);
      w.advance(1.4);
      expect(w.streams.where(oldBackdrop.contains), isEmpty);
    });

    test('only what is already on screen drives off', () {
      final w = _world(StripBiome.forest);
      w.advance(1);
      final old = w.streams.where((s) => !s.backdrop).toList();
      w.setBiome(StripBiome.desert);
      for (final s in old) {
        for (final item in s.items) {
          expect(item.x - w.offsetOf(s), lessThanOrEqualTo(412));
        }
      }
    });

    test('the party walks 30% brisker than 17b, feet still on the road', () {
      final w = _world(StripBiome.forest);
      final d = w.distance, s = w.stride;
      w.advance(1);
      expect(w.distance - d, closeTo(18 / 1.1 * 1.3, 1e-9));
      // Two dash periods, 18 dp, a stride, as before.
      expect((w.distance - d) / (w.stride - s), closeTo(18, 1e-9));
    });

    test('a change keeps the pace; the old road drives off at it', () {
      final w = _world(StripBiome.forest);
      w.advance(1);
      final old = w.streams.where((s) => !s.backdrop).toList();
      w.setBiome(StripBiome.coast);
      for (var i = 0; i < 5 * 60; i++) {
        final d = w.distance, s = w.stride;
        w.advance(1 / 60);
        expect(w.distance - d, closeTo(kRoadSpeed / 60, 1e-9));
        expect(w.stride - s, closeTo(1 / kStride / 60, 1e-9));
      }
      // The middle plane, at 0.6 of the road, is still on its way off.
      expect(w.streams.where(old.contains), isNotEmpty);
    });

    test('the sky and fog cross over in 2.5 s', () {
      final w = _world(StripBiome.forest);
      w.setBiome(StripBiome.desert);
      expect(w.fromBiome, StripBiome.forest);
      w.advance(1.25);
      expect(w.toneProgress, closeTo(0.5, 0.01));
      // The time is walking time, at the usual pace.
      expect(w.distance, closeTo(1.25 * kRoadSpeed, 1e-9));
      w.advance(1.3);
      expect(w.fromBiome, isNull);
      expect(w.toneProgress, 1);
    });

    test('every entry into a biome is a new seed — no forest repeats', () {
      final w = _world(StripBiome.forest);
      final before = [
        for (final s in w.streams)
          for (final i in s.items) i.shape.w,
      ];
      w.setBiome(StripBiome.mountains);
      w.setBiome(StripBiome.forest);
      final forest = w.streams.where((s) => !s.done).toList();
      w.advance(0.05);
      final after = [
        for (final s in forest)
          for (final i in s.items) i.shape.w,
      ];
      expect(after.take(5), isNot(before.take(5)));
    });
  });

  group('the anchors (17)', () {
    for (final biome in StripBiome.values) {
      test('${biome.name}: no sky or fog brighter than the ceiling', () {
        final tone = StripTone.of(biome, StripGeo(56));
        for (final c in tone.skyAndFog) {
          expect(
            StripAnchors.luminance(c),
            lessThanOrEqualTo(
              StripAnchors.luminance(StripAnchors.skyMax) + 1e-9,
            ),
          );
        }
      });

      test('${biome.name}: the near plane is the one near tone', () {
        final w = _world(biome);
        for (var i = 0; i < 400; i++) {
          w.advance(0.05);
        }
        // Each thing's body is the near tone; its facets and cracks are a
        // shade off it by design, and the flood's glints on the water are
        // not a thing at all.
        final bodies = {
          for (final s in w.streams)
            if (s.layer == StripLayer.near)
              for (final i in s.items)
                if (i.shape.type != 'рябь')
                  i.shape.prims.first.color.toARGB32(),
        };
        expect(bodies, {StripAnchors.near.toARGB32()});
      });
    }
  });

  group('freezing', () {
    Future<SceneStripState> pump(
      WidgetTester tester, {
      required bool moving,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SceneStrip(biomeId: 'forest', moving: moving, seed: 5),
          ),
        ),
      );
      await tester.pump();
      return tester.state<SceneStripState>(find.byType(SceneStrip));
    }

    testWidgets('stands still while it may not move', (tester) async {
      final state = await pump(tester, moving: false);
      await tester.pump(const Duration(seconds: 2));
      expect(state.world!.time, 0);
    });

    testWidgets('walks, and stops on the frame it was on', (tester) async {
      var state = await pump(tester, moving: true);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final walked = state.world!.time;
      expect(walked, greaterThan(0.5));

      state = await pump(tester, moving: false);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(state.world!.time, walked);
    });
  });

  group('stops', () {
    Future<SceneStripState> pumpStop(
      WidgetTester tester, {
      required StripStop stop,
      bool moving = true,
      String biome = 'forest',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SceneStrip(
              biomeId: biome,
              moving: moving,
              stop: stop,
              seed: 5,
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.state<SceneStripState>(find.byType(SceneStrip));
    }

    testWidgets('the halt keeps the variant it drew until the party leaves', (
      tester,
    ) async {
      final state = await pumpStop(tester, stop: StripStop.rest);
      final kind = state.stopKind;
      expect(kind, isIn([StopKind.camp1, StopKind.camp2, StopKind.camp3]));

      // Dialogs come and go, the fire burns on: the same camp throughout.
      for (final moving in [false, true, false, true]) {
        await pumpStop(tester, stop: StripStop.rest, moving: moving);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(state.stopKind, kind);
      }

      await pumpStop(tester, stop: StripStop.none);
      expect(state.stopKind, isNull);
    });

    testWidgets('the tavern is the tavern, whatever the biome', (tester) async {
      final state = await pumpStop(
        tester,
        stop: StripStop.tavern,
        biome: 'desert',
      );
      expect(state.stopKind, StopKind.tavern);
    });

    testWidgets('the road stands still behind a stop', (tester) async {
      final state = await pumpStop(tester, stop: StripStop.rest);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(state.world!.time, 0);
    });

    test('the entry: dark first, then the pieces from the right order', () {
      expect(veilAt(0), 0);
      expect(veilAt(0.54), closeTo(1, 1e-9));
      expect(veilAt(0.9), closeTo(1, 1e-9));
      expect(veilAt(1.8), 0);
      // Nothing is lit before 900 ms, and each piece waits its turn.
      expect(pieceAt(0, 0.9), 0);
      expect(pieceAt(0, 1.55), closeTo(1, 1e-9));
      expect(pieceAt(3, 1.55), 0);
      expect(pieceAt(3, 1.8 + 0.65), closeTo(1, 1e-9));
      // The room itself is there from the first frame.
      expect(pieceAt(null, 0), 1);
    });

    test('every scene builds', () {
      for (final kind in [StopKind.camp1, StopKind.camp2, StopKind.camp3]) {
        for (final environment in [true, false]) {
          final scene = buildCamp(kind, environment: environment);
          expect(scene.label, 'ПРИВАЛ');
          expect(scene.pieces, isNotEmpty);
          scene.dispose();
        }
      }
      final tavern = buildTavern();
      expect(tavern.label, 'ТАВЕРНА');
      tavern.dispose();
    });

    test('each biome with villages has its own, as drawn in the handoff', () {
      for (final biome in [
        StripBiome.forest,
        StripBiome.mountains,
        StripBiome.coast,
        StripBiome.desert,
        StripBiome.floodlands,
      ]) {
        final scene = buildVillage(biome);
        expect(scene.label, 'ДЕРЕВНЯ', reason: '$biome');
        // Lit up piece by piece in the prototype's order, with the sky's fog
        // and the ground there from the first frame.
        final orders = scene.pieces.map((p) => p.order).whereType<int>();
        expect(orders.length, greaterThanOrEqualTo(6), reason: '$biome');
        expect(scene.pieces.any((p) => p.order == null), isTrue);
        // And the chimneys smoke — all but the oasis, whose clay houses
        // have none.
        final motions = {
          for (final p in scene.pieces)
            for (final a in p.anims) a.motion,
        };
        if (biome != StripBiome.desert) {
          expect(motions, contains(StopMotion.smoke), reason: '$biome');
        }
        scene.dispose();
      }
      // The flooded village's mound has its fire and its people.
      final flood = buildVillage(StripBiome.floodlands);
      final moving = {
        for (final p in flood.pieces)
          for (final a in p.anims) a.motion,
      };
      expect(
        moving,
        containsAll([
          StopMotion.glow,
          StopMotion.flick,
          StopMotion.laugh,
          StopMotion.reachLeft,
        ]),
      );
      flood.dispose();
    });
  });

  group('the prologue (18)', () {
    StripWorld home({int figures = 4, double width = 412, int seed = 17}) =>
        StripWorld(
          geo: StripGeo(56),
          width: width,
          biome: StripBiome.fields,
          seed: seed,
          figures: figures,
          fromHome: true,
        );

    test('the party is out and walking in about six seconds, any size', () {
      for (final figures in [2, 4, 6, 8]) {
        final w = home(figures: figures);
        while (!w.prologue!.ready) {
          w.advance(1 / 60);
          expect(w.prologue!.time, lessThan(7), reason: '$figures');
        }
        expect(w.prologue!.readyAt, greaterThan(5.5), reason: '$figures');
        // Everyone in their place, and the world at the road's pace.
        for (final (i, f) in w.group.indexed) {
          expect(w.prologue!.x[i], closeTo(f.x, 0.01));
        }
        expect(w.prologue!.worldSpeed, closeTo(kRoadSpeed, 0.01));
        w.dispose();
      }
    });

    test('the world stands still until the lead reaches the middle', () {
      final w = home();
      for (var t = 0.0; t < 5; t += 1 / 60) {
        w.advance(1 / 60);
        if (w.prologue!.x.last < Prologue.center) {
          expect(w.distance, 0);
        }
      }
      w.dispose();
    });

    test('the house is there at the start, and never again', () {
      final w = home();
      expect(w.yard, isNotNull);
      expect(_types(w, StripLayer.ground), contains('дом'));
      var gone = false;
      for (var i = 0; i < 6000; i++) {
        w.advance(1 / 30);
        if (w.yard == null) gone = true;
        if (gone) {
          expect(w.yard, isNull);
          expect(_types(w, StripLayer.ground), isNot(contains('дом')));
        }
      }
      expect(gone, isTrue);
      w.dispose();
    });

    test('never two wells on the screen at once', () {
      for (final width in [412.0, 900.0]) {
        for (final seed in [1, 2, 3, 17, 40]) {
          final w = home(width: width, seed: seed);
          var wells = 0;
          for (var i = 0; i < 8000; i++) {
            w.advance(1 / 30);
            final onScreen = [
              for (final st in w.streams)
                if (st.layer == StripLayer.ground)
                  for (final item in st.items)
                    if (item.shape.type == 'колодец' ||
                        item.shape.type == 'дом')
                      if (item.x - w.offsetOf(st) < width &&
                          item.x - w.offsetOf(st) + item.shape.w > 0)
                        item,
            ];
            expect(onScreen.length, lessThanOrEqualTo(1), reason: '$seed');
            wells += onScreen.where((x) => x.shape.type == 'колодец').length;
          }
          // They do come, with the fences.
          expect(wells, greaterThan(0), reason: '$seed');
          w.dispose();
        }
      }
    });

    test('dense by the house, thinning to the open fields', () {
      final w = home();
      expect(w.fieldsDensity, kFieldsDense);
      while (w.distance < StripWorld.kThinOver) {
        w.advance(1 / 30);
      }
      expect(w.fieldsDensity, closeTo(kFields, 1e-9));
      w.dispose();
    });

    for (final id in const [
      'forest',
      'mountains',
      'coast',
      'desert',
      'floodlands',
      'graveyard',
    ]) {
      testWidgets('out of the prologue into $id through the change', (
        tester,
      ) async {
        Widget strip(bool prologue) => MaterialApp(
          home: SceneStrip(
            biomeId: id,
            moving: false,
            inPrologue: prologue,
            seed: 5,
          ),
        );
        await tester.pumpWidget(strip(true));
        final state = tester.state<SceneStripState>(find.byType(SceneStrip));
        expect(state.world!.biome, StripBiome.fields);
        await tester.pumpWidget(strip(false));
        expect(state.world!.biome, StripBiome.fromId(id));
        expect(state.world!.fromBiome, StripBiome.fields);
        expect(state.world!.toneProgress, lessThan(1));
      });
    }
  });
}
