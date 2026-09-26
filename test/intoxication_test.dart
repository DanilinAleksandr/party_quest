import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

GameCard _card(
  String id, {
  List<GameAction> actions = const [],
  List<CardChoice> choices = const [],
  List<CardTag> tags = const [],
  List<GameCondition> conditions = const [],
}) => GameCard(
  id: id,
  title: id,
  description: 'd',
  type: CardType.event,
  rarity: Rarity.common,
  weight: 1,
  tags: tags,
  conditions: conditions,
  actions: actions,
  choices: choices,
);

const _hangover = GameEffect(
  id: kHangoverEffectId,
  name: 'Похмелье',
  description: 'd',
  polarity: EffectPolarity.negative,
  duration: 6,
  remainingTurns: 6,
);

const _potion = InventoryItem(
  id: 'item_healing_potion',
  name: 'Зелье лекаря',
  description: 'd',
  rarity: Rarity.uncommon,
  usageType: ItemUsageType.manual,
  isConsumable: true,
  useActions: [SoberAction()],
);

GameController _controller(
  List<GameCard> cards, {
  List<String> players = const ['A', 'B'],
}) => GameController(
  playerNames: players,
  cards: cards,
  itemCatalog: const ItemCatalog({'item_healing_potion': _potion}),
  effectCatalog: const EffectCatalog({kHangoverEffectId: _hangover}),
  adventureCatalog: const AdventureCatalog({}),
  biomeCatalog: const BiomeCatalog({}),
  originCatalog: const OriginCatalog({}),
  seed: 2,
  journeySteps: null,
  skipPrologue: true,
);

/// Draws and resolves one card; the fixture decks below hold exactly the
/// card the test wants next.
void _play(GameController c, {int? choice}) {
  c.takeStep();
  c.resolveCard(choiceIndex: choice);
}

Player _only(GameController c) => c.state.players.first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('levels', () {
    test('fall at 1, 3 and 5 drinks', () {
      for (final (drinks, level) in [
        (0.0, IntoxicationLevel.sober),
        (0.9, IntoxicationLevel.sober),
        (1.0, IntoxicationLevel.tipsy),
        (2.9, IntoxicationLevel.tipsy),
        (3.0, IntoxicationLevel.drunk),
        (4.9, IntoxicationLevel.drunk),
        (5.0, IntoxicationLevel.wasted),
        (9.0, IntoxicationLevel.wasted),
      ]) {
        expect(IntoxicationLevel.of(drinks), level, reason: '$drinks');
      }
    });

    test('shift the stats a check reads, never the base ones, never luck', () {
      const base = Player(id: 'p', name: 'A');
      const drunk = Player(id: 'p', name: 'A', intoxication: 3);
      expect(drunk.effectiveStat(StatType.charisma), 1);
      expect(drunk.effectiveStat(StatType.strength), 1);
      expect(drunk.effectiveStat(StatType.attentiveness), -1);
      expect(drunk.effectiveStat(StatType.cunning), -1);
      expect(drunk.stats.valueOf(StatType.charisma), 0);
      for (final level in IntoxicationLevel.values) {
        expect(kIntoxicationShifts[level]!.containsKey(StatType.luck), isFalse);
      }
      expect(base.intoxicationShifts, isEmpty);
    });

    test('a stat check sees the drink', () {
      const check = CurrentPlayerStatAtLeastCondition(
        stat: StatType.strength,
        value: 1,
      );
      GameContext at(double drinks) => GameContext(
        state: GameState(
          players: [Player(id: 'p', name: 'A', intoxication: drinks)],
          currentPlayerIndex: 0,
          status: GameStatus.inProgress,
        ),
        random: RandomProvider(seed: 1),
        cardCatalog: const CardCatalog([]),
        itemCatalog: const ItemCatalog({}),
        effectCatalog: const EffectCatalog({}),
        adventureCatalog: const AdventureCatalog({}),
        biomeCatalog: const BiomeCatalog({}),
        originCatalog: const OriginCatalog({}),
        eventBus: GameEventBus(),
        mode: GameMode.classic,
      );
      expect(check.isSatisfied(at(0)), isFalse);
      expect(check.isSatisfied(at(3)), isTrue);
    });
  });

  /// A deck that plays [first] on step 1, then [then] ever after.
  List<GameCard> onceThen(List<GameAction> first, [List<GameCard>? then]) => [
    _card(
      'first',
      conditions: const [MaximumStepCondition(steps: 1)],
      actions: first,
    ),
    ...?then,
    if (then == null)
      _card('road', conditions: const [MinimumStepCondition(steps: 2)]),
  ];

  group('wearing off', () {
    test('a tenth per card played, from the card after the drink', () {
      final c = _controller(
        onceThen(const [DrinkAction(target: ActionTarget.allPlayers)]),
      );
      _play(c);
      // Not on the card the drink was taken on: one drink is exactly
      // «навеселе», and it would otherwise be gone before anyone saw it.
      expect(_only(c).intoxication, 1.0);
      expect(_only(c).intoxicationLevel, IntoxicationLevel.tipsy);
      _play(c);
      expect(_only(c).intoxication, closeTo(0.9, 1e-9));
    });

    test('three times as fast at a halt', () {
      final c = _controller([
        _card('road'),
        _card(
          'arrive',
          actions: const [
            DrinkAction(amount: 2, target: ActionTarget.allPlayers),
            SetWorldFlagAction(flag: 'in_rest'),
          ],
        ),
        _card('fire', tags: const [CardTag.rest]),
      ]);
      // The arrival is only drawn on a due step, so walk up to one.
      for (var i = 0; i < kRestInterval; i++) {
        _play(c);
      }
      expect(c.state.worldState.flag('in_rest'), isTrue);
      expect(_only(c).intoxication, 2.0);
      _play(c);
      expect(_only(c).intoxication, closeTo(2 - 0.3, 1e-9));
    });
  });

  group('the hangover', () {
    test('comes only to someone who got as far as drunk', () {
      final tipsy = _controller(
        onceThen(const [
          DrinkAction(amount: 2, target: ActionTarget.allPlayers),
        ]),
      );
      for (var i = 0; i < 25; i++) {
        _play(tipsy);
        for (final p in tipsy.state.players) {
          expect(p.isHungover, isFalse, reason: 'card $i');
        }
      }
      expect(_only(tipsy).intoxication, 0);

      final drunk = _controller(
        onceThen(const [
          DrinkAction(amount: 3, target: ActionTarget.allPlayers),
        ]),
      );
      _play(drunk);
      expect(_only(drunk).intoxicationLevel, IntoxicationLevel.drunk);
      expect(_only(drunk).isHungover, isFalse);
      // One card on, 2.9 is back below drunk — and there it is.
      _play(drunk);
      expect(_only(drunk).intoxicationLevel, IntoxicationLevel.tipsy);
      expect(_only(drunk).isHungover, isTrue);
    });

    test('is lifted by the next drink, which still adds to the scale', () {
      final c = _controller(
        onceThen(
          const [DrinkAction(amount: 3, target: ActionTarget.allPlayers)],
          [
            _card(
              'road',
              conditions: const [
                MinimumStepCondition(steps: 2),
                MaximumStepCondition(steps: 2),
              ],
            ),
            _card(
              'again',
              conditions: const [MinimumStepCondition(steps: 3)],
              actions: const [DrinkAction(target: ActionTarget.allPlayers)],
            ),
          ],
        ),
      );
      _play(c);
      _play(c);
      expect(_only(c).isHungover, isTrue);
      final before = _only(c).intoxication;
      _play(c);
      expect(_only(c).isHungover, isFalse);
      expect(_only(c).intoxication, closeTo(before + 1, 1e-9));
    });

    test('shifts the stats while it lasts', () {
      const hungover = Player(id: 'p', name: 'A', activeEffects: [_hangover]);
      expect(hungover.effectiveStat(StatType.attentiveness), -1);
      expect(hungover.effectiveStat(StatType.charisma), -1);
      expect(hungover.effectiveStat(StatType.endurance), -1);
      expect(hungover.conditionWord, 'похмелье');
    });
  });

  group('«Для храбрости»', () {
    final bar = _card(
      'bar',
      choices: const [
        CardChoice(label: 'Уйти'),
        CardChoice(
          label: 'Спеть',
          conditions: [
            IntoxicationAtLeastCondition(level: IntoxicationLevel.tipsy),
          ],
        ),
      ],
    );

    test('narrows the choices again from the card as drawn', () {
      final c = _controller([bar]);
      c.takeStep();
      expect(c.state.pendingCard!.choices.map((x) => x.label), ['Уйти']);

      expect(c.canDrinkForCourage, isTrue);
      c.drinkForCourage();
      expect(c.state.pendingCard!.choices.map((x) => x.label), [
        'Уйти',
        'Спеть',
      ]);
      expect(c.state.currentPlayer.intoxicationLevel, IntoxicationLevel.tipsy);
    });

    test('is one per card, and back on the next', () {
      final c = _controller([bar]);
      c.takeStep();
      c.drinkForCourage();
      expect(c.canDrinkForCourage, isFalse);
      c.resolveCard(choiceIndex: 0);
      c.takeStep();
      expect(c.canDrinkForCourage, isTrue);
    });

    test('is not offered to someone already wasted', () {
      final c = _controller(
        [
          _card(
            'shots',
            actions: const [
              DrinkAction(amount: 6, target: ActionTarget.allPlayers),
            ],
          ),
          bar,
        ],
        players: const ['A'],
      );
      // Solo, so nobody passes out; the deck alternates by weight, so keep
      // playing until the bar comes up with the player wasted.
      for (var i = 0; i < 40; i++) {
        c.takeStep();
        final card = c.state.pendingCard!;
        if (card.id == 'bar' &&
            c.state.currentPlayer.intoxicationLevel ==
                IntoxicationLevel.wasted) {
          expect(c.canDrinkForCourage, isFalse);
          return;
        }
        c.resolveCard(choiceIndex: card.hasChoices ? 0 : null);
      }
      fail('never met the bar while wasted');
    });

    test('is not offered on a card without choices', () {
      final c = _controller([_card('road')]);
      c.takeStep();
      expect(c.canDrinkForCourage, isFalse);
    });
  });

  group('the healer\'s draught', () {
    test('sobers by two, lifts the hangover, and is spent', () {
      final c = _controller(
        [
          _card(
            'drinks',
            actions: const [
              DrinkAction(amount: 3.1, target: ActionTarget.allPlayers),
              GiveItemAction(
                itemId: 'item_healing_potion',
                target: ActionTarget.allPlayers,
              ),
            ],
          ),
        ],
        players: const ['A'],
      );
      _play(c);
      expect(_only(c).isHungover, isFalse);
      c.takeStep();
      final before = _only(c).intoxication;
      expect(c.usableItems.map((i) => i.id), ['item_healing_potion']);
      c.useItem('item_healing_potion');
      expect(_only(c).intoxication, closeTo(before - 2, 1e-9));
      expect(_only(c).inventory, isEmpty, reason: 'the draught is spent');
      expect(c.usableItems, isEmpty, reason: 'one personal action a card');
    });
  });

  group('passing out', () {
    test(
      'at seven: out for three cards, left out of the draw, then hungover',
      () {
        final c = _controller(
          [
            _card('shots', actions: const [DrinkAction(amount: 7)]),
            _card('road'),
          ],
          players: const ['A', 'B', 'C'],
        );

        // Play until somebody has been knocked out.
        Player? out;
        for (var i = 0; i < 30 && out == null; i++) {
          _play(c);
          out = c.state.players.where((p) => p.isPassedOut).firstOrNull;
        }
        expect(out, isNotNull);
        expect(out!.conditionWord, 'спит');

        // While out, never the one a card is about.
        for (var i = 0; i < 2; i++) {
          c.takeStep();
          expect(c.state.currentPlayer.id, isNot(out.id));
          c.resolveCard();
        }
        c.takeStep();
        c.resolveCard();
        final woke = c.state.players.firstWhere((p) => p.id == out!.id);
        expect(woke.isPassedOut, isFalse);
        expect(woke.isHungover, isTrue);
      },
    );

    test('never happens to a party of one', () {
      final c = _controller(
        [
          _card('shots', actions: const [DrinkAction(amount: 10)]),
        ],
        players: const ['A'],
      );
      _play(c);
      expect(_only(c).isPassedOut, isFalse);
      expect(_only(c).intoxication, lessThan(kPassOutAt));
    });

    test('the random pick skips a sleeper', () {
      const resolver = ParticipantResolver();
      for (var seed = 0; seed < 20; seed++) {
        final context = GameContext(
          state: const GameState(
            players: [
              Player(id: 'a', name: 'A', passedOutCards: 2),
              Player(id: 'b', name: 'B'),
            ],
            currentPlayerIndex: 0,
            status: GameStatus.inProgress,
          ),
          random: RandomProvider(seed: seed),
          cardCatalog: const CardCatalog([]),
          itemCatalog: const ItemCatalog({}),
          effectCatalog: const EffectCatalog({}),
          adventureCatalog: const AdventureCatalog({}),
          biomeCatalog: const BiomeCatalog({}),
          originCatalog: const OriginCatalog({}),
          eventBus: GameEventBus(),
          mode: GameMode.classic,
        );
        final picked =
            resolver.resolve(const RandomPlayerParticipant(), context)
                as ResolvedParticipant;
        expect(picked.context.currentPlayer.id, 'b');
      }
    });
  });

  test('a wasted player\'s chronicle entry gets its aside', () {
    final c = _controller(
      [
        _card(
          'feat',
          actions: const [
            DrinkAction(amount: 5),
            AddChronicleEntryAction(text: '{player} сделал это.'),
          ],
        ),
      ],
      players: const ['A'],
    );
    _play(c);
    final entry = c.state.chronicle.single;
    expect(entry.text, 'A сделал это.');
    expect(entry.aside, kWastedChronicleAside);
  });

  test('the new actions and conditions survive JSON', () {
    for (final action in const <GameAction>[
      DrinkAction(),
      DrinkAction(amount: 2, target: ActionTarget.allPlayers),
      SoberAction(),
    ]) {
      expect(GameAction.fromJson(action.toJson()).toJson(), action.toJson());
    }
    for (final condition in const <GameCondition>[
      IntoxicationAtLeastCondition(level: IntoxicationLevel.drunk),
      IntoxicationBelowCondition(level: IntoxicationLevel.tipsy),
      CurrentPlayerHungoverCondition(),
    ]) {
      expect(
        GameCondition.fromJson(condition.toJson()).toJson(),
        condition.toJson(),
      );
    }
  });

  test(
    'the shipped pack drinks, and has answers only the drunk give',
    () async {
      final cards = await const CardRepository().loadCards();
      bool drinks(List<GameAction> actions) => actions.any(
        (a) =>
            a is DrinkAction ||
            (a is ChanceCheckAction &&
                (drinks(a.winnerActions) || drinks(a.loserActions))) ||
            (a is StartDuelAction &&
                (drinks(a.winnerActions) || drinks(a.loserActions))),
      );
      final drinking = cards.where(
        (c) => drinks(c.actions) || c.choices.any((ch) => drinks(ch.actions)),
      );
      expect(drinking.length, greaterThanOrEqualTo(25));

      final forTheDrunk = [
        for (final card in cards)
          for (final choice in card.choices)
            if (choice.conditions.any((x) => x is IntoxicationAtLeastCondition))
              choice.label,
      ];
      expect(forTheDrunk, hasLength(4));
    },
  );
}
