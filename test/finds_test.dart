import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/features/game/presentation/widgets/chance_check_dialog.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

/// Every find, and the items that count as having it.
const _finds = {
  'item_name_kerchief': {'item_name_kerchief'},
  'item_sealed_letter': {'item_sealed_letter'},
  'map': {'item_map_half_left', 'item_map_half_right'},
  'item_lantern': {'item_lantern'},
  'item_salt': {'item_salt'},
  'item_holed_die': {'item_holed_die'},
  'item_order_badge': {'item_order_badge'},
};

String? _heldItem(GameCondition c) => switch (c) {
  CurrentPlayerHasItemCondition k => k.itemId,
  AnyPlayerHasItemCondition k => k.itemId,
  _ => null,
};

String _words(CardChoice c) => [
  c.label,
  c.outcome ?? '',
  for (final a in c.actions.whereType<ChanceCheckAction>()) ...[
    a.winnerOutcome ?? '',
    a.loserOutcome ?? '',
  ],
].join(' ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'each find is a find, and opens a way in at least three places',
    () async {
      final cards = await const CardRepository().loadCards();
      for (final MapEntry(key: find, value: items) in _finds.entries) {
        // Laid out as a find, somewhere.
        final found = cards.where(
          (c) =>
              c.hasTag(CardTag.find) &&
              c.choices.any(
                (ch) => ch.actions.any(
                  (a) => a is GiveItemAction && items.contains(a.itemId),
                ),
              ),
        );
        expect(found, isNotEmpty, reason: find);
        for (final card in found) {
          expect(card.choices.any((c) => c.inspect), isTrue, reason: card.id);
        }
        // A way in that holding it opens: a choice, or the card itself.
        final places = {
          for (final card in cards)
            if (card.conditions.any((k) => items.contains(_heldItem(k))) ||
                card.choices.any(
                  (ch) =>
                      ch.conditions.any((k) => items.contains(_heldItem(k))),
                ))
              card.id,
        };
        // The die answers a lost throw in the throw's own dialog too.
        final extra = find == 'item_holed_die' ? 1 : 0;
        expect(places.length + extra, greaterThanOrEqualTo(3), reason: find);
      }
    },
  );

  test('the name on the kerchief is the name of the one awaited', () async {
    final cards = await const CardRepository().loadCards();
    const waiting = {
      'stepan': ('Степан', 'home_supper_waits'),
      'ignat': ('Игнат', 'home_shoes_by_door'),
      'gavrila': ('Гаврила', 'village_old_woman_names'),
      'foma': ('Фома', 'home_wife_sharpens_knife'),
    };
    for (final MapEntry(key: key, value: (name, waiter)) in waiting.entries) {
      final find = cards.singleWhere((c) => c.id == 'find_kerchief_$key');
      expect(find.description, contains('«$name»'), reason: key);
      final asked = cards.singleWhere((c) => c.id == waiter);
      expect(asked.choices.map(_words).join(' '), contains(name), reason: key);
      final back = cards.singleWhere((c) => c.id == 'kerchief_returned_$key');
      expect(back.description, contains(name), reason: key);
      // Giving it back takes it, and says what came of it.
      final give = back.choices.first;
      expect(give.actions.whereType<TakeItemAction>(), isNotEmpty);
      expect(give.outcome, isNotNull);
    }
  });

  test('the badge shown to the order\'s own spoils the alliance', () async {
    final cards = await const CardRepository().loadCards();
    final exposures = [
      for (final card in cards)
        for (final ch in card.choices)
          if (ch.conditions.any((k) => _heldItem(k) == 'item_order_badge') &&
              ch.conditions.any(
                (k) => k is WorldFlagSetCondition && k.flag == 'paladin_ally',
              ))
            ch,
    ];
    expect(exposures, isNotEmpty);
    for (final ch in exposures) {
      expect(
        ch.actions.whereType<SetWorldFlagAction>().any(
          (a) => a.flag == 'paladin_ally' && !a.value,
        ),
        isTrue,
        reason: ch.label,
      );
    }
  });

  group('the holed die', () {
    GameController controller() => GameController(
      playerNames: const ['A', 'B'],
      cards: const [
        GameCard(
          id: 'risk',
          title: 'risk',
          description: 'd',
          type: CardType.event,
          rarity: Rarity.common,
          weight: 1,
          choices: [
            CardChoice(label: 'Рискнуть', actions: [ChanceCheckAction()]),
            CardChoice(label: 'Уйти'),
          ],
        ),
      ],
      itemCatalog: const ItemCatalog({kHoledDieId: _die}),
      effectCatalog: const EffectCatalog({}),
      adventureCatalog: const AdventureCatalog({}),
      biomeCatalog: const BiomeCatalog({}),
      originCatalog: const OriginCatalog({}),
      seed: 4,
      journeySteps: null,
      skipPrologue: true,
    );

    test('throws once more and cracks', () {
      final c = controller()..takeStep();
      expect(c.canRerollWithDie, isFalse);
      c.debugGive(c.state.currentPlayer.id, _die);
      expect(c.canRerollWithDie, isTrue);
      c.rerollWithDie(odds: 0.5);
      expect(c.canRerollWithDie, isFalse);
      expect(
        c.state.currentPlayer.inventory.where((i) => i.id == kHoledDieId),
        isEmpty,
      );
    });

    Future<void> show(WidgetTester tester, {required bool passed}) async {
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showChanceCheckDialog(
                context: context,
                passed: passed,
                spinner: false,
                canReroll: true,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    }

    testWidgets('is offered on a lost throw', (tester) async {
      await show(tester, passed: false);
      expect(find.byKey(const Key('reroll_with_die')), findsOne);
    });

    testWidgets('and not on a won one', (tester) async {
      await show(tester, passed: true);
      expect(find.byKey(const Key('reroll_with_die')), findsNothing);
    });
  });
}

const _die = InventoryItem(
  id: kHoledDieId,
  name: 'Кость с дыркой',
  description: 'd',
  rarity: Rarity.rare,
  usageType: ItemUsageType.manual,
  isConsumable: true,
);
