import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/core/widgets/item_chip.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

const _figurine = InventoryItem(
  id: 'item_wooden_figurine',
  name: 'Деревянная фигурка',
  description: 'd',
  rarity: Rarity.common,
  usageType: ItemUsageType.manual,
  isConsumable: false,
);

const _take = [GiveItemAction(itemId: 'item_wooden_figurine')];

final _find = GameCard(
  id: 'figurine',
  title: 'Деревянная фигурка',
  description: 'd',
  type: CardType.item,
  rarity: Rarity.common,
  weight: 1,
  tags: const [CardTag.find],
  choices: const [
    CardChoice(label: 'Рассмотреть поближе', inspect: true),
    CardChoice(
      label: 'Взять с собой',
      conditions: [AuraNoticedCondition(noticed: AuraNotice.none)],
      actions: _take,
    ),
    CardChoice(
      label: 'Взять — пусть холодит',
      conditions: [AuraNoticedCondition(noticed: AuraNotice.curse)],
      actions: _take,
    ),
    CardChoice(
      label: 'Оставить: себе дороже',
      conditions: [AuraNoticedCondition(noticed: AuraNotice.curse)],
    ),
    CardChoice(
      label: 'Взять — раз греет',
      conditions: [AuraNoticedCondition(noticed: AuraNotice.blessing)],
      actions: _take,
    ),
    CardChoice(label: 'Оставить на месте'),
  ],
);

GameController _controller(int seed, {List<String> players = const ['A']}) =>
    GameController(
      playerNames: players,
      cards: [_find],
      itemCatalog: const ItemCatalog({'item_wooden_figurine': _figurine}),
      effectCatalog: const EffectCatalog({}),
      adventureCatalog: const AdventureCatalog({}),
      biomeCatalog: const BiomeCatalog({}),
      originCatalog: const OriginCatalog({}),
      seed: seed,
      journeySteps: null,
      skipPrologue: true,
    );

Iterable<String> _labels(GameController c) =>
    c.state.pendingCard!.choices.map((x) => x.label);

/// Seeds whose first draw carries an aura [want] accepts.
Iterable<int> _seeds(bool Function(ItemAura? a) want) sync* {
  for (var seed = 0; seed < 20000; seed++) {
    final c = _controller(seed)..takeStep();
    if (want(c.state.pendingAura)) yield seed;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a closer look tells, and returns to the card without itself', () {
    final c = _controller(_seeds((a) => a == null).first)..takeStep();
    expect(_labels(c), contains('Рассмотреть поближе'));
    final told = c.inspect(0);
    expect(told, kNothingSeen);
    expect(c.state.pendingCard, isNotNull);
    expect(_labels(c), isNot(contains('Рассмотреть поближе')));
    expect(_labels(c), containsAll(['Взять с собой', 'Оставить на месте']));
  });

  test('the craft eye sees the work, not the aura', () {
    final c = _controller(_seeds((a) => a?.curse ?? false).first)..takeStep();
    c.debugSetOrigin(c.state.currentPlayer.id, 'origin_craftsman');
    expect(c.inspect(0), kCraftLines['item_wooden_figurine']);
    expect(c.state.noticedAura, AuraNotice.none);
  });

  test('the chosen of the gods always sees a blessing', () {
    for (final seed in _seeds((a) => !(a?.curse ?? true)).take(10)) {
      final c = _controller(seed)..takeStep();
      c.debugSetOrigin(c.state.currentPlayer.id, kBlessingSight);
      expect(c.inspect(0), kBlessingSeen, reason: '$seed');
      expect(_labels(c), contains('Взять — раз греет'));
      expect(_labels(c), isNot(contains('Взять с собой')));
    }
  });

  test('a curse sensed opens the knowing choices, and is taken knowing', () {
    final c = _controller(_seeds((a) => a?.curse ?? false).first)..takeStep();
    c.debugSetOrigin(c.state.currentPlayer.id, 'origin_witch_heir');
    expect(c.inspect(0), kCurseSeen);
    expect(
      _labels(c),
      containsAll(['Взять — пусть холодит', 'Оставить: себе дороже']),
    );
    final take = _labels(c).toList().indexOf('Взять — пусть холодит');
    c.resolveCard(choiceIndex: take);
    final aura = c.state.players.single.inventory.single.aura!;
    expect(aura.curse, isTrue);
    expect(aura.known, isTrue);
  });

  test('a companion who could see notices about one time in three', () {
    var looks = 0, noticed = 0;
    for (final seed in _seeds((a) => a?.curse ?? false).take(300)) {
      final c = _controller(seed, players: const ['A', 'B'])..takeStep();
      final looker = c.state.currentPlayer.id;
      final other = c.state.players.firstWhere((p) => p.id != looker);
      c.debugSetOrigin(other.id, 'origin_witch_heir');
      looks++;
      final told = c.inspect(0);
      if (c.state.noticedAura == AuraNotice.curse) {
        noticed++;
        expect(told, contains(other.name));
        expect(told, contains('фигурку'));
      }
    }
    expect(noticed / looks, closeTo(1 / 3, 0.08));
  });

  testWidgets(
    'a noticed aura shows as a word on the item; an unnoticed one, no',
    (tester) async {
      Future<void> chip(ItemAura? aura) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ItemChip(item: _figurine.withAura(aura))),
        ),
      );
      await chip(const ItemAura(kind: AuraKind.luckDrain));
      expect(find.text('холодит'), findsNothing);
      await chip(const ItemAura(kind: AuraKind.luckDrain, known: true));
      expect(find.text('холодит'), findsOneWidget);
      await chip(const ItemAura(kind: AuraKind.quietLuck, known: true));
      expect(find.text('греет'), findsOneWidget);
    },
  );

  test(
    'every find lying on the road can be looked at, taken or left',
    () async {
      final cards = await const CardRepository().loadCards();
      final finds = cards.where((c) => c.hasTag(CardTag.find)).toList();
      expect(finds.length, greaterThanOrEqualTo(22));
      for (final card in finds) {
        expect(card.hasChoices, isTrue, reason: card.id);
        expect(
          card.choices.where((c) => c.inspect),
          hasLength(1),
          reason: card.id,
        );
        expect(
          card.choices.map((c) => c.label),
          containsAll(['Взять — пусть холодит', 'Оставить: себе дороже']),
          reason: card.id,
        );
      }
    },
  );

  test('the toast warms the table for a while, not for good', () async {
    final cards = await const CardRepository().loadCards();
    final toasts = cards.where((c) => c.id.startsWith('global_toast_all'));
    expect(toasts, hasLength(5));
    for (final toast in toasts) {
      expect(toast.actions.whereType<ModifyStatAction>(), isEmpty);
      final shift = toast.actions.whereType<ApplyEffectAction>().single;
      expect(shift.effectId, 'effect_fireside_charm');
      expect(shift.target, ActionTarget.allPlayers);
    }
  });
}
