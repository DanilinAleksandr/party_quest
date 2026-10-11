import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/features/game/presentation/widgets/chance_check_dialog.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

GameCard _card(GameAction action) => GameCard(
  id: 'bout',
  title: 'Армрестлинг',
  description: 'd',
  type: CardType.duel,
  rarity: Rarity.common,
  weight: 1,
  choices: [
    CardChoice(label: 'Принять вызов', actions: [action]),
    const CardChoice(label: 'Пройти мимо'),
  ],
);

GameController _controller(GameCard card, {int seed = 5}) => GameController(
  playerNames: const ['Саня', 'Миша', 'Лёха'],
  cards: [card],
  itemCatalog: const ItemCatalog({}),
  effectCatalog: const EffectCatalog({}),
  adventureCatalog: const AdventureCatalog({}),
  biomeCatalog: const BiomeCatalog({}),
  originCatalog: const OriginCatalog({}),
  seed: seed,
  journeySteps: null,
  skipPrologue: true,
);

const _bout = StartDuelAction(
  stat: StatType.strength,
  visual: GambleVisual.armWrestle,
);

Future<void> _show(
  WidgetTester tester, {
  required bool passed,
  ArmWrestleScenario scenario = ArmWrestleScenario.quick,
  String challenger = 'Саня',
  String opponent = 'Миша',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showArmWrestleDialog(
              context: context,
              passed: passed,
              scenario: scenario,
              challenger: challenger,
              opponent: opponent,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the script', () {
    test('ends on the side that won, in every scenario, for both', () {
      for (final s in ArmWrestleScenario.values) {
        for (final near in [true, false]) {
          // At the slam the loser's hand is on the table, and it stays
          // there to the end: the angle is the full pin, the winner's way.
          for (final t in [s.hit, s.hit + 0.2, s.end]) {
            final th = s.theta(near, t);
            expect(th.sign, near ? 1 : -1, reason: '${s.name} $near $t');
            expect(
              th.abs(),
              closeTo(ArmWrestleScenario.pin, 0.05),
              reason: '${s.name} $near $t',
            );
          }
          // And never before it: no hand touches the table early.
          for (var t = 0.0; t < s.hit - 0.01; t += 0.01) {
            expect(s.u(t), lessThan(0.999), reason: '${s.name} $t');
            expect(s.u(t), greaterThanOrEqualTo(-0.97));
          }
        }
      }
    });

    test('the timings are the design\'s', () {
      const hits = {
        ArmWrestleScenario.quick: 1.3,
        ArmWrestleScenario.long: 4.05,
        ArmWrestleScenario.comeback: 3.95,
        ArmWrestleScenario.almost: 2.95,
        ArmWrestleScenario.swing: 3.35,
      };
      for (final MapEntry(key: s, value: hit) in hits.entries) {
        expect(s.hit, hit);
        expect(s.end, closeTo(hit + 0.7, 1e-9));
        final beats = s.beats;
        expect(beats.first, (0.0, ArmBeat.start));
        expect(beats.last, (hit, ArmBeat.slam));
      }
      // The long one trembles hard enough to buzz; the quick one never.
      expect(
        ArmWrestleScenario.long.beats.where((b) => b.$2 == ArmBeat.tremble),
        isNotEmpty,
      );
      expect(
        ArmWrestleScenario.quick.beats.where((b) => b.$2 == ArmBeat.tremble),
        isEmpty,
      );
    });

    test('a mismatch is quick more often than an even bout', () {
      int quick(double gap) => [
        for (var i = 0; i < 1000; i++) ArmWrestleScenario.pick(gap, i / 1000),
      ].where((s) => s == ArmWrestleScenario.quick).length;
      expect(quick(0), closeTo(100, 5));
      expect(quick(0.5), closeTo(300, 5));
      expect(quick(1), closeTo(600, 5));
      expect(armWrestleGap(0.5), 0);
      expect(armWrestleGap(0.25), 1);
      expect(armWrestleGap(0.75), 1);
      expect(armWrestleGap(0.625), 0.5);
    });

    test('the same seed throws the same bouts', () {
      List<ArmWrestleScenario> bouts(int seed) {
        final c = _controller(_card(_bout), seed: seed);
        return [for (var i = 0; i < 20; i++) c.armWrestleScenario(0.6)];
      }

      expect(bouts(11), bouts(11));
      expect(bouts(11), isNot(bouts(12)));
    });
  });

  group('the bout', () {
    test(
      'is marked in the content: both arm-wrestling cards, nothing else',
      () async {
        final cards = await const CardRepository().loadCards();
        final marked = <String>[];
        void walk(String id, Iterable<GameAction> actions) {
          for (final a in actions) {
            final v = switch (a) {
              StartDuelAction d => d.visual,
              ChanceCheckAction c => c.visual,
              _ => GambleVisual.coin,
            };
            if (v == GambleVisual.armWrestle) marked.add(id);
          }
        }

        for (final c in cards) {
          walk(c.id, c.actions);
          for (final ch in c.choices) {
            walk(c.id, ch.actions);
          }
        }
        expect(marked.toSet(), {'duel_arm_wrestle', 'rest_arm_wrestle'});
      },
    );

    test('carries its look to the screen; other throws stay coins', () {
      final c = _controller(_card(_bout))..takeStep();
      final g = c.gambleFor(choiceIndex: 0)!;
      expect(g.visual, GambleVisual.armWrestle);
      expect(g.challenger, c.state.currentPlayer.name);
      expect(g.opponent, isNotNull);

      final coin = _controller(
        _card(const StartDuelAction(stat: StatType.strength)),
      )..takeStep();
      expect(coin.gambleFor(choiceIndex: 0)!.visual, GambleVisual.coin);

      // An NPC across the table is named from the card.
      final npc = _controller(
        _card(
          const ChanceCheckAction(
            stat: StatType.strength,
            visual: GambleVisual.armWrestle,
            opponent: 'Кузнец',
          ),
        ),
      )..takeStep();
      final n = npc.gambleFor(choiceIndex: 0)!;
      expect(n.visual, GambleVisual.armWrestle);
      expect(n.opponent, 'Кузнец');
      expect(n.challenger, npc.state.currentPlayer.name);
    });

    test('never stands on its edge', () {
      final c = _controller(_card(_bout))..takeStep();
      for (var i = 0; i < 3000; i++) {
        expect(c.roll(odds: 0.5, edgeable: false), isNot(CoinThrow.edge));
      }
    });

    test('round-trips through JSON', () {
      final d = GameAction.fromJson(_bout.toJson()) as StartDuelAction;
      expect(d.visual, GambleVisual.armWrestle);
      final c =
          GameAction.fromJson(
                const ChanceCheckAction(
                  visual: GambleVisual.armWrestle,
                  opponent: 'Кузнец',
                ).toJson(),
              )
              as ChanceCheckAction;
      expect(c.visual, GambleVisual.armWrestle);
      expect(c.opponent, 'Кузнец');
      expect(
        (GameAction.fromJson(const StartDuelAction().toJson())
                as StartDuelAction)
            .visual,
        GambleVisual.coin,
      );
    });
  });

  group('the dialog', () {
    for (final s in ArmWrestleScenario.values) {
      for (final passed in [true, false]) {
        testWidgets('${s.name}, ${passed ? 'near' : 'far'} wins: '
            'the verdict names the loser', (tester) async {
          await _show(tester, passed: passed, scenario: s);
          expect(find.text('Армрестлинг'), findsWidgets);
          // No side to call, no coin.
          expect(find.text('Король'), findsNothing);
          expect(find.text('Шут'), findsNothing);
          expect(find.textContaining('Платит'), findsNothing);
          expect(find.text('Дальше'), findsNothing);

          await tester.pump(Duration(milliseconds: (s.hit * 1000).ceil()));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Платит: ${passed ? 'Миша' : 'Саня'}'), findsOne);
          expect(find.text('Саня и Миша'), findsOne);
          expect(find.text('Дальше'), findsNothing);

          await tester.pump(const Duration(milliseconds: 800));
          expect(find.text('Дальше'), findsOne);
          await tester.tap(find.text('Дальше'));
          await tester.pumpAndSettle();
          expect(find.text('Армрестлинг'), findsNothing);
        });
      }
    }

    testWidgets('says what counts, the names by their arms', (tester) async {
      await _show(tester, passed: true);
      expect(find.text('Сила: Саня — Миша'), findsOne);
      final near = tester.getCenter(find.byKey(const Key('bout_near')));
      final far = tester.getCenter(find.byKey(const Key('bout_far')));
      expect(far.dy, lessThan(near.dy));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('long names push the button down instead of running over', (
      tester,
    ) async {
      const a = 'Александр Великолепный Победитель Всех Столов';
      const b = 'Мария-Антуанетта Непобедимая Королева Привала';
      await _show(tester, passed: false, challenger: a, opponent: b);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final verdict = tester.getRect(find.text('Платит: $a'));
      final button = tester.getRect(find.text('Дальше'));
      final near = tester.getRect(find.byKey(const Key('bout_near')));
      expect(verdict.top, greaterThan(near.bottom));
      expect(button.top, greaterThan(verdict.bottom));
    });
  });
}
