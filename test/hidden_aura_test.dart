import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

const _stone = InventoryItem(
  id: 'item_odd_stone',
  name: 'Необычный камень',
  description: 'd',
  rarity: Rarity.common,
  usageType: ItemUsageType.manual,
  isConsumable: false,
);

const _hangover = GameEffect(
  id: kHangoverEffectId,
  name: 'Похмелье',
  description: 'd',
  polarity: EffectPolarity.negative,
  duration: 6,
  remainingTurns: 6,
);

GameCard _find() => GameCard(
  id: 'stone_find',
  title: 'Камень',
  description: 'd',
  type: CardType.item,
  rarity: Rarity.common,
  weight: 1,
  tags: const [CardTag.find],
  choices: const [
    CardChoice(
      label: 'Взять',
      actions: [GiveItemAction(itemId: 'item_odd_stone')],
    ),
    CardChoice(label: 'Пройти мимо'),
  ],
);

GameController _controller({
  required int seed,
  List<GameCard>? cards,
  List<String> players = const ['A'],
}) => GameController(
  playerNames: players,
  cards: cards ?? [_find()],
  itemCatalog: const ItemCatalog({'item_odd_stone': _stone}),
  effectCatalog: const EffectCatalog({kHangoverEffectId: _hangover}),
  adventureCatalog: const AdventureCatalog({}),
  biomeCatalog: const BiomeCatalog({}),
  originCatalog: const OriginCatalog({}),
  seed: seed,
  journeySteps: null,
  skipPrologue: true,
  ages: [for (final _ in players) kDefaultAge],
);

/// The first seed whose first find carries an aura of the kind [want].
int _seedWith(bool Function(ItemAura a) want) {
  for (var seed = 0; seed < 5000; seed++) {
    final c = _controller(seed: seed)..takeStep();
    final aura = c.state.pendingAura;
    if (aura != null && want(aura)) return seed;
  }
  throw StateError('no seed');
}

Player _holding(ItemAura aura, {int luck = 0, double drunk = 0}) => Player(
  id: 'p',
  name: 'A',
  stats: PlayerStats({StatType.luck: luck}),
  intoxication: drunk,
  inventory: [_stone.withAura(aura)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a find is cursed about 12% of the time and blessed about 3%', () {
    var curses = 0, blessings = 0;
    const n = 20000;
    for (var seed = 0; seed < n; seed++) {
      final a = rollAura(RandomProvider(seed: seed));
      if (a == null) continue;
      a.curse ? curses++ : blessings++;
    }
    expect(curses / n, closeTo(kCurseChance, 0.01));
    expect(blessings / n, closeTo(kBlessingChance, 0.006));
  });

  test('the aura is rolled as the card is drawn, and goes with the thing', () {
    final seed = _seedWith((a) => a.curse);
    final c = _controller(seed: seed)..takeStep();
    final rolled = c.state.pendingAura!;
    // Seen before anyone takes anything: what a close look will read.
    expect(c.state.players.single.inventory, isEmpty);
    c.resolveCard(choiceIndex: 0);
    final taken = c.state.players.single.inventory.single.aura!;
    expect(taken.kind, rolled.kind);
    expect(c.state.pendingAura, isNull);
  });

  test('a find left lying takes its aura nowhere', () {
    final c = _controller(seed: _seedWith((a) => a.curse))..takeStep();
    c.resolveCard(choiceIndex: 1);
    expect(c.state.players.single.inventory, isEmpty);
    expect(c.state.pendingAura, isNull);
  });

  test('a card that is no find rolls no aura', () {
    final plain = GameCard(
      id: 'plain',
      title: 't',
      description: 'd',
      type: CardType.item,
      rarity: Rarity.common,
      weight: 1,
      actions: const [GiveItemAction(itemId: 'item_odd_stone')],
    );
    for (var seed = 0; seed < 200; seed++) {
      final c = _controller(seed: seed, cards: [plain])..takeStep();
      expect(c.state.pendingAura, isNull);
      c.resolveCard();
      expect(c.state.players.single.inventory.single.aura, isNull);
    }
  });

  test('the screen sees the base stats; a check sees the aura', () {
    const weak = ItemAura(
      kind: AuraKind.quietWeakness,
      stat: StatType.charisma,
    );
    final p = _holding(weak);
    expect(p.stats.valueOf(StatType.charisma), 0);
    expect(p.effectiveStat(StatType.charisma), -2);
    // The shifts the profile spells out are the drink's and the hangover's
    // only: nothing about the aura.
    expect(p.intoxicationShifts, isEmpty);
    expect(
      _holding(weak.copyWith(heavy: true)).effectiveStat(StatType.charisma),
      -3,
    );
    expect(
      _holding(
        const ItemAura(kind: AuraKind.quietStrength, stat: StatType.charisma),
      ).effectiveStat(StatType.charisma),
      2,
    );
  });

  test('the luck drain stops at its limit', () {
    for (final (heavy, every, cap) in [(false, 3, 5), (true, 2, 10)]) {
      var a = ItemAura(kind: AuraKind.luckDrain, heavy: heavy);
      for (var i = 1; i <= 100; i++) {
        a = a.tick();
        if (i == every) expect(a.accrued, -1);
      }
      expect(a.accrued, -cap);
    }
    var gift = const ItemAura(kind: AuraKind.quietLuck);
    for (var i = 0; i < 100; i++) {
      gift = gift.tick();
    }
    expect(gift.accrued, 5);
  });

  test('in play: the drain counts the holder\'s own turns', () {
    final road = GameCard(
      id: 'road',
      title: 't',
      description: 'd',
      type: CardType.event,
      rarity: Rarity.common,
      weight: 1,
    );
    final c = _controller(seed: 1, cards: [road]);
    c.debugGiveCursedItem(c.state.players.single.id, AuraKind.luckDrain);
    for (var i = 0; i < 9; i++) {
      c.takeStep();
      c.resolveCard();
    }
    final p = c.state.players.single;
    expect(p.stats.valueOf(StatType.luck), 0);
    expect(p.effectiveStat(StatType.luck), -3);
  });

  test('a lost thing takes its aura with it, drained luck and all', () {
    final p = _holding(
      const ItemAura(kind: AuraKind.luckDrain, turns: 9, accrued: -3),
    );
    expect(p.effectiveStat(StatType.luck), -3);
    final without = p.copyWith(inventory: const []);
    expect(without.effectiveStat(StatType.luck), 0);
  });

  test('the drink: a heavy head and a light one', () {
    expect(_holding(const ItemAura(kind: AuraKind.heavyHead)).drinkFactor, 1.5);
    expect(
      _holding(
        const ItemAura(kind: AuraKind.heavyHead, heavy: true),
      ).drinkFactor,
      2,
    );
    expect(_holding(const ItemAura(kind: AuraKind.lightHead)).drinkFactor, 0.5);
    expect(
      _holding(const ItemAura(kind: AuraKind.longHangover)).soberDivisor,
      2,
    );
    expect(
      _holding(
        const ItemAura(kind: AuraKind.longHangover, heavy: true),
      ).soberDivisor,
      3,
    );
  });

  test('a curse taken with luck down is the heavy one', () {
    final seed = _seedWith((a) => a.curse);
    final c = _controller(seed: seed)..takeStep();
    // Luck −1 for the taker, as the thing is taken.
    c.debugSetLuck(-1);
    c.resolveCard(choiceIndex: 0);
    expect(c.state.players.single.inventory.single.aura!.heavy, isTrue);

    final light = _controller(seed: seed)..takeStep();
    light.resolveCard(choiceIndex: 0);
    expect(light.state.players.single.inventory.single.aura!.heavy, isFalse);
  });

  test('no hangover with the blessing, and a hangover without it', () {
    GameController drinker(List<InventoryItem> bag) {
      final c = _controller(
        seed: 3,
        cards: [
          GameCard(
            id: 'first',
            title: 't',
            description: 'd',
            type: CardType.event,
            rarity: Rarity.common,
            weight: 1,
            conditions: const [MaximumStepCondition(steps: 1)],
            actions: const [
              DrinkAction(amount: 3, target: ActionTarget.allPlayers),
            ],
          ),
          GameCard(
            id: 'road',
            title: 't',
            description: 'd',
            type: CardType.event,
            rarity: Rarity.common,
            weight: 1,
            conditions: const [MinimumStepCondition(steps: 2)],
          ),
        ],
      );
      for (final item in bag) {
        c.debugGive(c.state.players.single.id, item);
      }
      return c;
    }

    for (final (bag, hungover) in [
      (<InventoryItem>[], true),
      ([_stone.withAura(const ItemAura(kind: AuraKind.noHangover))], false),
    ]) {
      final c = drinker(bag);
      c
        ..takeStep()
        ..resolveCard()
        ..takeStep()
        ..resolveCard();
      expect(c.state.players.single.isHungover, hungover, reason: '$bag');
    }
  });
}
