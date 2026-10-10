import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/features/game/presentation/widgets/chance_check_dialog.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

Player _p(
  Map<StatType, int> stats, {
  double drunk = 0,
  List<InventoryItem> bag = const [],
}) => Player(
  id: 'p${stats.hashCode}',
  name: 'A',
  stats: PlayerStats(stats),
  intoxication: drunk,
  inventory: bag,
);

void main() {
  test('the odds never leave 25–75 %, however things stack', () {
    for (var s = -12; s <= 12; s++) {
      for (var l = -12; l <= 12; l++) {
        final p = _p({StatType.strength: s, StatType.luck: l});
        final odds = checkOdds(p, StatType.strength);
        expect(
          odds,
          inInclusiveRange(kOddsFloor, kOddsCeiling),
          reason: '$s $l',
        );
        final q = _p({StatType.strength: -s, StatType.luck: -l});
        expect(duelOdds(p, q, StatType.strength), inInclusiveRange(0.25, 0.75));
      }
    }
  });

  test('a stat moves the odds within 35–65 %, by 10 % a point', () {
    for (final (value, odds) in [
      (-3, 0.35),
      (-2, 0.35),
      (-1, 0.40),
      (0, 0.50),
      (1, 0.60),
      (2, 0.65),
      (5, 0.65),
    ]) {
      expect(
        checkOdds(_p({StatType.strength: value}), StatType.strength),
        closeTo(odds, 1e-9),
        reason: '$value',
      );
    }
    // A scene's own number is measured against.
    expect(
      checkOdds(_p({StatType.strength: 2}), StatType.strength, against: 2),
      closeTo(0.5, 1e-9),
    );
  });

  test('charisma counts from its median, +1; the rest from 0', () {
    for (final (value, odds) in [(0, 0.40), (1, 0.50), (2, 0.60), (3, 0.65)]) {
      expect(
        checkOdds(_p({StatType.charisma: value}), StatType.charisma),
        closeTo(odds, 1e-9),
        reason: '$value',
      );
    }
    for (final stat in StatType.values.where((s) => s != StatType.charisma)) {
      expect(statBaseline(stat), 0, reason: '$stat');
    }
    // A duel goes by the difference: equal charisma is an even bout.
    final a = _p({StatType.charisma: 1});
    expect(duelOdds(a, _p({StatType.charisma: 1}), StatType.charisma), 0.5);
  });

  test('without a stat, only luck moves it — ± 10 % at most', () {
    expect(checkOdds(_p({StatType.strength: 5}), null), 0.5);
    expect(checkOdds(_p({StatType.luck: 2}), null), closeTo(0.56, 1e-9));
    expect(checkOdds(_p({StatType.luck: 9}), null), closeTo(0.60, 1e-9));
    expect(checkOdds(_p({StatType.luck: -9}), null), closeTo(0.40, 1e-9));
  });

  test('a duel is symmetric: A against B is 100 % less B against A', () {
    for (var a = -4; a <= 4; a++) {
      for (var b = -4; b <= 4; b++) {
        for (var la = -3; la <= 3; la++) {
          final x = _p({StatType.charisma: a, StatType.luck: la});
          final y = _p({StatType.charisma: b, StatType.luck: -la + 1});
          for (final stat in [StatType.charisma, null]) {
            expect(
              duelOdds(x, y, stat) + duelOdds(y, x, stat),
              closeTo(1, 1e-9),
            );
          }
        }
      }
    }
  });

  test('the drink and an unseen aura move the odds', () {
    final sober = _p({});
    // Drunk: charisma up, attentiveness down — through the same layer.
    final drunk = _p({}, drunk: 3);
    expect(
      checkOdds(drunk, StatType.charisma),
      greaterThan(checkOdds(sober, StatType.charisma)),
    );
    expect(
      checkOdds(drunk, StatType.attentiveness),
      lessThan(checkOdds(sober, StatType.attentiveness)),
    );
    // «Для храбрости»: one drink makes the middle player (charisma +1)
    // tipsy, +1 more — from 50 % to 60 %.
    expect(checkOdds(_p({StatType.charisma: 1}), StatType.charisma), 0.5);
    final courage = _p({StatType.charisma: 1}, drunk: 1);
    expect(checkOdds(courage, StatType.charisma), closeTo(0.60, 1e-9));
    // A cursed thing's weakness, and a luck drain, both unseen.
    final weak = _p(
      {},
      bag: [
        const InventoryItem(
          id: 'x',
          name: 'x',
          description: 'd',
          rarity: Rarity.common,
          usageType: ItemUsageType.manual,
          isConsumable: false,
        ).withAura(
          const ItemAura(kind: AuraKind.quietWeakness, stat: StatType.strength),
        ),
      ],
    );
    expect(weak.stats.valueOf(StatType.strength), 0);
    expect(checkOdds(weak, StatType.strength), closeTo(0.35, 1e-9));
    final drained = _p(
      {},
      bag: [
        const InventoryItem(
          id: 'x',
          name: 'x',
          description: 'd',
          rarity: Rarity.common,
          usageType: ItemUsageType.manual,
          isConsumable: false,
        ).withAura(const ItemAura(kind: AuraKind.luckDrain, accrued: -5)),
      ],
    );
    expect(checkOdds(drained, null), closeTo(0.40, 1e-9));
  });

  test('a throw comes off about as often as its odds say', () {
    final random = RandomProvider(seed: 9);
    for (final odds in [0.3, 0.5, 0.7]) {
      var won = 0;
      for (var i = 0; i < 20000; i++) {
        if (random.nextDouble() < odds) won++;
      }
      expect(won / 20000, closeTo(odds, 0.01));
    }
  });

  testWidgets('the throw names what it measures, never a number', (
    tester,
  ) async {
    Future<void> roll({StatType? stat, String? a, String? b}) async {
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showChanceCheckDialog(
                context: context,
                passed: true,
                stat: stat,
                challenger: a,
                opponent: b,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
    }

    await roll(stat: StatType.strength);
    expect(find.text('Сила'), findsOneWidget);
    await roll();
    expect(find.text('Удача'), findsOneWidget);
    await roll(stat: StatType.strength, a: 'Саня', b: 'Миша');
    expect(find.text('Сила: Саня — Миша'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });
}
