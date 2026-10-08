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
  int? age,
  int seed = 2,
}) => GameController(
  playerNames: players,
  cards: cards,
  itemCatalog: const ItemCatalog({'item_healing_potion': _potion}),
  effectCatalog: const EffectCatalog({kHangoverEffectId: _hangover}),
  adventureCatalog: const AdventureCatalog({}),
  biomeCatalog: const BiomeCatalog({}),
  originCatalog: const OriginCatalog({}),
  seed: seed,
  journeySteps: null,
  skipPrologue: true,
  // Mature unless a test says otherwise, so one drink is one.
  ages: [for (final _ in players) age ?? kDefaultAge],
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
    test('fall at the first drink, then at 3 and 5', () {
      for (final (drinks, level) in [
        (0.0, IntoxicationLevel.sober),
        (0.1, IntoxicationLevel.sober),
        (0.15, IntoxicationLevel.tipsy),
        (0.75, IntoxicationLevel.tipsy),
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
    test('a little per own turn, from the turn after the drink', () {
      final c = _controller(
        onceThen(const [DrinkAction(target: ActionTarget.allPlayers)]),
        players: const ['A'],
      );
      _play(c);
      // Not on the card the drink was taken on.
      expect(_only(c).intoxication, 1.0);
      expect(_only(c).intoxicationLevel, IntoxicationLevel.tipsy);
      _play(c);
      expect(_only(c).intoxication, closeTo(1 - kSoberingPerTurn, 1e-9));
    });

    test("only on the drinker's own turns", () {
      final c = _controller(
        onceThen(const [DrinkAction(target: ActionTarget.allPlayers)]),
        players: const ['A', 'B', 'C', 'D'],
      );
      _play(c);
      for (var i = 0; i < 30; i++) {
        final before = {for (final p in c.state.players) p.id: p.intoxication};
        c.takeStep();
        final turnOf = c.state.currentPlayer.id;
        c.resolveCard();
        for (final p in c.state.players) {
          if (p.id == turnOf) continue;
          expect(p.intoxication, before[p.id], reason: 'card $i, ${p.name}');
        }
      }
    });

    test('twice as fast at a halt', () {
      final c = _controller(
        players: const ['A'],
        [
          _card('road'),
          _card(
            'arrive',
            actions: const [
              DrinkAction(amount: 2, target: ActionTarget.allPlayers),
              SetWorldFlagAction(flag: 'in_rest'),
            ],
          ),
          _card('fire', tags: const [CardTag.rest]),
        ],
      );
      // The arrival is only drawn on a due step, so walk up to one.
      for (var i = 0; i < kRestInterval; i++) {
        _play(c);
      }
      expect(c.state.worldState.flag('in_rest'), isTrue);
      expect(_only(c).intoxication, 2.0);
      _play(c);
      expect(
        _only(c).intoxication,
        closeTo(2 - kSoberingPerTurn * kRestSoberingFactor, 1e-9),
      );
    });
  });

  group('the hangover', () {
    test('comes only to someone who got as far as drunk', () {
      final tipsy = _controller(
        onceThen(const [
          DrinkAction(amount: 2, target: ActionTarget.allPlayers),
        ]),
        players: const ['A'],
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
        players: const ['A'],
      );
      _play(drunk);
      expect(_only(drunk).intoxicationLevel, IntoxicationLevel.drunk);
      expect(_only(drunk).isHungover, isFalse);
      // One turn on, 2.85 is back below drunk — and there it is.
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
        players: const ['A'],
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

  test('a cold plunge sobers without curing', () {
    const hungover = Player(
      id: 'p',
      name: 'A',
      intoxication: 5,
      wasDrunk: true,
      activeEffects: [_hangover],
    );
    final context = GameContext(
      state: const GameState(
        players: [hungover],
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
    const executor = ActionExecutor();
    final plunged = executor
        .execute(const SoberAction(amount: 1, cure: false), context)
        .currentPlayer;
    expect(plunged.intoxication, 4);
    expect(plunged.isHungover, isTrue);
    expect(plunged.wasDrunk, isTrue);

    final cured = executor.execute(const SoberAction(), context).currentPlayer;
    expect(cured.isHungover, isFalse);
    expect(cured.wasDrunk, isFalse);
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
      SoberAction(amount: 1, cure: false),
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
      expect(forTheDrunk, hasLength(9));

      final forTheHungover = [
        for (final card in cards)
          for (final choice in card.choices)
            if (choice.conditions.any(
              (x) => x is CurrentPlayerHungoverCondition,
            ))
              choice.label,
      ];
      expect(forTheHungover, ['Попросить всех говорить потише']);
    },
  );

  group('age', () {
    const young = 24, mature = 40, elder = 58;

    test('is always 20–65, over a hundred seeds', () {
      final seen = <int>{};
      for (var seed = 0; seed < 100; seed++) {
        final c = GameController(
          playerNames: const ['A', 'B', 'C', 'D', 'E', 'F'],
          cards: const [],
          itemCatalog: const ItemCatalog({}),
          effectCatalog: const EffectCatalog({}),
          adventureCatalog: const AdventureCatalog({}),
          biomeCatalog: const BiomeCatalog({}),
          originCatalog: const OriginCatalog({}),
          seed: seed,
          skipPrologue: true,
        );
        for (final p in c.state.players) {
          expect(p.age, inInclusiveRange(kMinAge, kMaxAge), reason: '$seed');
          expect(p.age, greaterThanOrEqualTo(20));
          seen.add(p.age);
        }
      }
      // Spread over the whole range, every bracket included.
      expect(seen.map(AgeBracket.of).toSet(), AgeBracket.values.toSet());
      expect(seen.length, greaterThan(40));
    });

    test('the same seed gives the same ages', () {
      List<int> ages(int seed) => [
        for (final p in _controller(
          const [],
          players: const ['A', 'B', 'C', 'D'],
        ).state.players)
          p.age,
      ];
      expect(rollAges(7, 4), rollAges(7, 4));
      expect(rollAges(7, 4), isNot(rollAges(8, 4)));
      GameController make(int seed) => GameController(
        playerNames: const ['A', 'B', 'C', 'D'],
        cards: const [],
        itemCatalog: const ItemCatalog({}),
        effectCatalog: const EffectCatalog({}),
        adventureCatalog: const AdventureCatalog({}),
        biomeCatalog: const BiomeCatalog({}),
        originCatalog: const OriginCatalog({}),
        seed: seed,
      );
      expect(
        make(11).state.players.map((p) => p.age),
        make(11).state.players.map((p) => p.age),
      );
      expect(make(11).state.players.map((p) => p.age), rollAges(11, 4));
      expect(ages(2), hasLength(4));
    });

    test('falls into brackets at 30 and 50', () {
      for (final (age, bracket) in [
        (20, AgeBracket.young),
        (29, AgeBracket.young),
        (30, AgeBracket.mature),
        (49, AgeBracket.mature),
        (50, AgeBracket.elder),
        (65, AgeBracket.elder),
      ]) {
        expect(AgeBracket.of(age), bracket, reason: '$age');
      }
    });

    test('one drink is 1.3, 1.0 and 0.75', () {
      for (final (age, amount) in [
        (young, 1.3),
        (mature, 1.0),
        (elder, 0.75),
      ]) {
        final c = _controller(
          onceThen(const [DrinkAction(target: ActionTarget.allPlayers)]),
          age: age,
        );
        _play(c);
        expect(_only(c).intoxication, closeTo(amount, 1e-9), reason: '$age');
      }
    });

    test('the hangover lasts 3, 6 and 9 cards', () {
      for (final (age, cards) in [(young, 3), (mature, 6), (elder, 9)]) {
        // Enough to get everybody as far as drunk.
        final c = _controller(
          onceThen(const [
            DrinkAction(amount: 4, target: ActionTarget.allPlayers),
          ]),
          age: age,
        );
        // Counted as cards drawn with the hangover on.
        var hungover = 0;
        for (var i = 0; i < 60; i++) {
          c.takeStep();
          final p = _only(c);
          if (p.isHungover) {
            hungover++;
            if (hungover == 1) {
              final effect = p.activeEffects.firstWhere(
                (e) => e.id == kHangoverEffectId,
              );
              expect(effect.remainingTurns, cards, reason: '$age');
            }
          } else if (hungover > 0) {
            break;
          }
          c.resolveCard();
        }
        expect(hungover, cards, reason: '$age');
      }
    });

    test('«Для храбрости» makes everybody tipsy at once, whatever the age', () {
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
      for (final age in [young, mature, elder]) {
        final c = _controller([bar], age: age)..takeStep();
        c.drinkForCourage();
        expect(
          c.state.currentPlayer.intoxicationLevel,
          IntoxicationLevel.tipsy,
          reason: '$age',
        );
        expect(c.state.pendingCard!.choices, hasLength(2), reason: '$age');
      }
    });

    /// How many of the drinker's own turns after the one they drank on
    /// still find them at least «навеселе», out of [drinks] drinks.
    int tipsyTurns(int age, int drinks, {int players = 4}) {
      final c = _controller(
        [
          _card(
            'first',
            conditions: const [MaximumStepCondition(steps: 1)],
            actions: [
              DrinkAction(
                amount: drinks.toDouble(),
                target: ActionTarget.allPlayers,
              ),
            ],
          ),
          _card('road', conditions: const [MinimumStepCondition(steps: 2)]),
        ],
        players: [for (var i = 0; i < players; i++) 'P$i'],
        age: age,
      );
      _play(c);
      final drinker = c.state.players.first.id;
      var turns = 0;
      for (var i = 0; i < 400; i++) {
        c.takeStep();
        final mine = c.state.currentPlayer.id == drinker;
        final level = c.state.players.first.intoxicationLevel;
        c.resolveCard();
        if (!mine) continue;
        if (level == IntoxicationLevel.sober) break;
        turns++;
      }
      return turns;
    }

    test('one drink holds «навеселе» five own turns at any age', () {
      for (final age in [kMinAge, young, mature, elder, kMaxAge]) {
        for (final players in [1, 3, 6]) {
          expect(
            tipsyTurns(age, 1, players: players),
            greaterThanOrEqualTo(5),
            reason: 'age $age, $players players',
          );
        }
      }
    });

    test('the bracket condition reads the current player, and round-trips', () {
      for (final bracket in AgeBracket.values) {
        final condition = CurrentPlayerAgeBracketCondition(bracket: bracket);
        expect(
          GameCondition.fromJson(condition.toJson()).toJson(),
          condition.toJson(),
        );
        for (final age in [young, mature, elder]) {
          final context = GameContext(
            state: GameState(
              players: [Player(id: 'p', name: 'A', age: age)],
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
          expect(
            condition.isSatisfied(context),
            AgeBracket.of(age) == bracket,
            reason: '$age $bracket',
          );
        }
      }
    });

    test('content answers differently at every age', () async {
      final cards = await const CardRepository().loadCards();
      final byBracket = <AgeBracket, List<String>>{};
      for (final card in cards) {
        for (final choice in card.choices) {
          for (final c in choice.conditions) {
            if (c is CurrentPlayerAgeBracketCondition) {
              byBracket.putIfAbsent(c.bracket, () => []).add(card.id);
            }
          }
        }
      }
      for (final bracket in AgeBracket.values) {
        expect(byBracket[bracket], hasLength(greaterThanOrEqualTo(2)));
      }
    });

    test('is saved with the player; an old save is mature', () {
      const p = Player(id: 'p', name: 'A', age: 61);
      expect(Player.fromJson(p.toJson()).age, 61);
      final old = p.toJson()..remove('age');
      expect(Player.fromJson(old).age, kDefaultAge);
      expect(Player.fromJson(old).ageBracket, AgeBracket.mature);
    });
  });
}
