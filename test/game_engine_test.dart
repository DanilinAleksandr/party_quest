import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

const _testItem = InventoryItem(
  id: 'itm_test',
  name: 'Test Item',
  description: 'd',
  rarity: Rarity.common,
  usageType: ItemUsageType.automatic,
  isConsumable: false,
);

const _luckyEffect = GameEffect(
  id: 'eff_test',
  name: 'Test Effect',
  description: 'd',
  polarity: EffectPolarity.positive,
  duration: 2,
  remainingTurns: 2,
  reactions: {
    GameEventKind.turnStarted: [
      ModifyStatAction(stat: StatType.luck, amount: 1),
    ],
  },
);

const _oneTurnEffect = GameEffect(
  id: 'eff_short',
  name: 'Short Effect',
  description: 'd',
  polarity: EffectPolarity.negative,
  duration: 1,
  remainingTurns: 1,
);

const _wardEffect = GameEffect(
  id: 'eff_ward',
  name: 'Ward',
  description: 'd',
  polarity: EffectPolarity.positive,
  duration: -1,
  remainingTurns: -1,
  blocksNextNegativeEffect: true,
);

GameContext _buildContext({
  required List<Player> players,
  int seed = 1,
  List<GameCard> cards = const [],
  GameMode mode = GameMode.classic,
}) {
  return GameContext(
    state: GameState(
      players: players,
      currentPlayerIndex: 0,
      status: GameStatus.inProgress,
    ),
    random: RandomProvider(seed: seed),
    cardCatalog: CardCatalog(cards),
    itemCatalog: ItemCatalog({_testItem.id: _testItem}),
    effectCatalog: EffectCatalog({
      _luckyEffect.id: _luckyEffect,
      _oneTurnEffect.id: _oneTurnEffect,
      _wardEffect.id: _wardEffect,
    }),
    adventureCatalog: const AdventureCatalog({}),
    biomeCatalog: const BiomeCatalog({}),
    originCatalog: const OriginCatalog({}),
    eventBus: GameEventBus(),
    mode: mode,
  );
}

void main() {
  group('RandomProvider', () {
    test('the same seed reproduces the same sequence', () {
      final a = RandomProvider(seed: 42);
      final b = RandomProvider(seed: 42);
      final sequenceA = List.generate(10, (_) => a.nextInt(1000));
      final sequenceB = List.generate(10, (_) => b.nextInt(1000));
      expect(sequenceA, sequenceB);
    });
  });

  group('CardCatalog conditions', () {
    test('excludes cards whose conditions are not met', () {
      final needsThree = GameCard(
        id: 'needs_three',
        title: 't',
        description: 'd',
        type: CardType.event,
        rarity: Rarity.common,
        weight: 10,
        conditions: const [MinimumPlayersCondition(count: 3)],
      );
      final alwaysEligible = GameCard(
        id: 'always',
        title: 't',
        description: 'd',
        type: CardType.event,
        rarity: Rarity.common,
        weight: 10,
      );

      final context = _buildContext(
        players: [
          const Player(id: 'p1', name: 'A'),
          const Player(id: 'p2', name: 'B'),
        ],
        cards: [needsThree, alwaysEligible],
      );

      final eligible = context.cardCatalog.eligibleCards(context);
      expect(eligible.map((c) => c.id), ['always']);
    });

    test('game mode rarity pool always gates cards, unconditionally', () {
      final legendary = GameCard(
        id: 'legendary_card',
        title: 't',
        description: 'd',
        type: CardType.legendary,
        rarity: Rarity.legendary,
        weight: 1,
      );
      final noLegendaryMode = GameMode(
        id: 'no_legendary',
        name: 'No Legendary',
        allowedRarities: const {
          Rarity.common,
          Rarity.uncommon,
          Rarity.rare,
          Rarity.epic,
        },
      );

      final context = _buildContext(
        players: [const Player(id: 'p1', name: 'A')],
        cards: [legendary],
        mode: noLegendaryMode,
      );

      expect(context.cardCatalog.eligibleCards(context), isEmpty);
    });
  });

  group('ActionExecutor', () {
    test('GiveItemAction adds the item and emits OnItemReceived', () {
      final context = _buildContext(
        players: [const Player(id: 'p1', name: 'A')],
      );
      final received = <GameEvent>[];
      context.eventBus.subscribe((event, ctx) => received.add(event));

      const executor = ActionExecutor();
      final next = executor.execute(
        const GiveItemAction(itemId: 'itm_test'),
        context,
      );

      expect(
        next.currentPlayer.inventory.map((i) => i.id),
        contains('itm_test'),
      );
      expect(received.whereType<OnItemReceived>(), hasLength(1));
    });

    test(
      'AddChronicleEntryAction appends a chronicle entry with {player} filled in',
      () {
        final context = _buildContext(
          players: [const Player(id: 'p1', name: 'Alex')],
        );

        const executor = ActionExecutor();
        final next = executor.execute(
          const AddChronicleEntryAction(text: '🐉 {player} — Драконорождённый.'),
          context,
        );

        expect(next.state.chronicle, hasLength(1));
        expect(next.state.chronicle.single.text, '🐉 Alex — Драконорождённый.');
      },
    );

    test(
      'AddChronicleEntryAction leaves a placeholder-free party line untouched',
      () {
        final context = _buildContext(
          players: [const Player(id: 'p1', name: 'Alex')],
        );

        const executor = ActionExecutor();
        final next = executor.execute(
          const AddChronicleEntryAction(
            text: '🤝 Компания заключила союз с капитаном пиратов.',
          ),
          context,
        );

        expect(
          next.state.chronicle.single.text,
          '🤝 Компания заключила союз с капитаном пиратов.',
        );
      },
    );

    test(
      'ApplyEffectAction refreshes rather than duplicates an existing effect',
      () {
        final context = _buildContext(
          players: [const Player(id: 'p1', name: 'A')],
        );
        const executor = ActionExecutor();

        var next = executor.execute(
          const ApplyEffectAction(effectId: 'eff_test'),
          context,
        );
        next = executor.execute(
          const ApplyEffectAction(effectId: 'eff_test'),
          next,
        );

        expect(next.currentPlayer.activeEffects, hasLength(1));
        expect(next.currentPlayer.activeEffects.single.remainingTurns, 2);
      },
    );

    test('RemoveEffectAction removes a matching active effect', () {
      final context = _buildContext(
        players: [const Player(id: 'p1', name: 'A')],
      );
      const executor = ActionExecutor();

      var next = executor.execute(
        const ApplyEffectAction(effectId: 'eff_short'),
        context,
      );
      expect(next.currentPlayer.activeEffects, hasLength(1));

      next = executor.execute(
        const RemoveEffectAction(effectId: 'eff_short'),
        next,
      );
      expect(next.currentPlayer.activeEffects, isEmpty);
    });

    test(
      'RemoveEffectAction is a no-op when the player does not have the effect',
      () {
        final context = _buildContext(
          players: [const Player(id: 'p1', name: 'A')],
        );
        const executor = ActionExecutor();

        final next = executor.execute(
          const RemoveEffectAction(effectId: 'eff_short'),
          context,
        );
        expect(next.currentPlayer.activeEffects, isEmpty);
      },
    );

    test('a ward consumes itself instead of letting the next curse land', () {
      final context = _buildContext(
        players: [const Player(id: 'p1', name: 'A')],
      );
      const executor = ActionExecutor();

      var next = executor.execute(
        const ApplyEffectAction(effectId: 'eff_ward'),
        context,
      );
      expect(next.currentPlayer.activeEffects.map((e) => e.id), ['eff_ward']);

      next = executor.execute(
        const ApplyEffectAction(effectId: 'eff_short'),
        next,
      );

      expect(next.currentPlayer.activeEffects, isEmpty);
    });

    test('a ward does not block a positive effect', () {
      final context = _buildContext(
        players: [const Player(id: 'p1', name: 'A')],
      );
      const executor = ActionExecutor();

      var next = executor.execute(
        const ApplyEffectAction(effectId: 'eff_ward'),
        context,
      );
      next = executor.execute(
        const ApplyEffectAction(effectId: 'eff_test'),
        next,
      );

      expect(
        next.currentPlayer.activeEffects.map((e) => e.id),
        unorderedEquals(['eff_ward', 'eff_test']),
      );
    });

    test(
      'StartDuelAction applies winner/loser actions to the right players',
      () {
        final context = _buildContext(
          players: [
            const Player(id: 'p1', name: 'A'),
            const Player(id: 'p2', name: 'B'),
          ],
          seed: 7,
        );
        const executor = ActionExecutor();

        final next = executor.execute(
          const StartDuelAction(
            winnerActions: [
              ModifyStatAction(stat: StatType.strength, amount: 5),
            ],
            loserActions: [
              ModifyStatAction(stat: StatType.strength, amount: -5),
            ],
          ),
          context,
        );

        final strengths = next.players
            .map((p) => p.stats.valueOf(StatType.strength))
            .toSet();
        // Exactly one player gained 5, the other lost 5 — regardless of which
        // one the seeded coin flip picked as the winner.
        expect(strengths, {5, -5});
      },
    );
  });

  group('EventDispatcher', () {
    test("runs an effect's reaction to the event it declares", () {
      var context = _buildContext(
        players: [const Player(id: 'p1', name: 'A')],
      );
      const executor = ActionExecutor();
      context = executor.execute(
        const ApplyEffectAction(effectId: 'eff_test'),
        context,
      );
      expect(context.currentPlayer.stats.valueOf(StatType.luck), 0);

      final dispatcher = EventDispatcher(executor);
      final next = dispatcher.dispatch(
        OnTurnStarted(player: context.currentPlayer),
        context,
      );

      expect(next.currentPlayer.stats.valueOf(StatType.luck), 1);
    });

    test('does not react to event kinds the effect has no reaction for', () {
      var context = _buildContext(
        players: [const Player(id: 'p1', name: 'A')],
      );
      const executor = ActionExecutor();
      context = executor.execute(
        const ApplyEffectAction(effectId: 'eff_test'),
        context,
      );

      final dispatcher = EventDispatcher(executor);
      final next = dispatcher.dispatch(
        OnCardDrawn(card: _dummyCard, player: context.currentPlayer),
        context,
      );

      expect(next.currentPlayer.stats.valueOf(StatType.luck), 0);
    });
  });

  group('EffectLifecycle', () {
    test(
      'expires an effect once its duration runs out and emits OnEffectExpired',
      () {
        var context = _buildContext(
          players: [const Player(id: 'p1', name: 'A')],
        );
        const executor = ActionExecutor();
        context = executor.execute(
          const ApplyEffectAction(effectId: 'eff_short'),
          context,
        );
        expect(context.currentPlayer.activeEffects, hasLength(1));

        final received = <GameEvent>[];
        context.eventBus.subscribe((event, ctx) => received.add(event));

        const lifecycle = EffectLifecycle();
        final next = lifecycle.expireForAllPlayers(context);

        expect(next.currentPlayer.activeEffects, isEmpty);
        expect(received.whereType<OnEffectExpired>(), hasLength(1));
      },
    );
  });

  group('GameController determinism', () {
    test('the same seed draws the same first card', () {
      final cards = [
        GameCard(
          id: 'c1',
          title: 't',
          description: 'd',
          type: CardType.event,
          rarity: Rarity.common,
          weight: 5,
        ),
        GameCard(
          id: 'c2',
          title: 't',
          description: 'd',
          type: CardType.event,
          rarity: Rarity.common,
          weight: 5,
        ),
        GameCard(
          id: 'c3',
          title: 't',
          description: 'd',
          type: CardType.event,
          rarity: Rarity.common,
          weight: 5,
        ),
      ];
      const itemCatalog = ItemCatalog({});
      const effectCatalog = EffectCatalog({});
      const adventureCatalog = AdventureCatalog({});
      const biomeCatalog = BiomeCatalog({});
      const originCatalog = OriginCatalog({});

      GameController build() => GameController(
        playerNames: const ['A', 'B'],
        cards: cards,
        itemCatalog: itemCatalog,
        effectCatalog: effectCatalog,
        adventureCatalog: adventureCatalog,
        biomeCatalog: biomeCatalog,
        originCatalog: originCatalog,
        seed: 999,
        skipPrologue: true,
      );

      final controllerA = build();
      final controllerB = build();
      controllerA.takeStep();
      controllerB.takeStep();

      expect(
        controllerA.state.pendingCard?.id,
        controllerB.state.pendingCard?.id,
      );
    });
  });

  group('GameController journey log', () {
    test('resolving a card appends a structured JourneyLogEntry', () {
      final card = GameCard(
        id: 'c1',
        title: 'Странная находка',
        description: 'd',
        type: CardType.luck,
        rarity: Rarity.legendary,
        weight: 5,
      );
      final controller = GameController(
        playerNames: const ['A', 'B'],
        cards: [card],
        itemCatalog: const ItemCatalog({}),
        effectCatalog: const EffectCatalog({}),
        adventureCatalog: const AdventureCatalog({}),
        biomeCatalog: const BiomeCatalog({}),
        originCatalog: const OriginCatalog({}),
        seed: 1,
        skipPrologue: true,
      );

      expect(controller.state.journeyLog, isEmpty);

      controller.takeStep();
      controller.resolveCard();

      expect(controller.state.journeyLog, hasLength(1));
      final entry = controller.state.journeyLog.single;
      expect(entry.text, contains('Странная находка'));
      expect(entry.type, CardType.luck);
      expect(entry.rarity, Rarity.legendary);
      expect(entry.biomeId, 'forest');
      expect(entry.relatedPlayerId, isNotNull);
    });
  });
}

final _dummyCard = GameCard(
  id: 'dummy',
  title: 't',
  description: 'd',
  type: CardType.event,
  rarity: Rarity.common,
  weight: 1,
);
