import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

GameContext _buildContext({required List<Player> players}) {
  return GameContext(
    state: GameState(
      players: players,
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
}

void main() {
  group('CurrentPlayerStatAtLeastCondition', () {
    test('true when the resolved player meets the threshold', () {
      final context = _buildContext(
        players: [
          Player(
            id: 'p1',
            name: 'A',
            stats: const PlayerStats({StatType.charisma: 2}),
          ),
        ],
      );
      expect(
        const CurrentPlayerStatAtLeastCondition(
          stat: StatType.charisma,
          value: 2,
        ).isSatisfied(context),
        isTrue,
      );
    });

    test('false when the resolved player falls short', () {
      final context = _buildContext(
        players: [
          Player(
            id: 'p1',
            name: 'A',
            stats: const PlayerStats({StatType.charisma: 1}),
          ),
        ],
      );
      expect(
        const CurrentPlayerStatAtLeastCondition(
          stat: StatType.charisma,
          value: 2,
        ).isSatisfied(context),
        isFalse,
      );
    });

    test('an unset stat defaults to 0, not satisfying a positive threshold', () {
      final context = _buildContext(
        players: [const Player(id: 'p1', name: 'A')],
      );
      expect(
        const CurrentPlayerStatAtLeastCondition(
          stat: StatType.cunning,
          value: 1,
        ).isSatisfied(context),
        isFalse,
      );
    });
  });

  group('AnyPlayerStatAtLeastCondition', () {
    test('true if at least one player meets the threshold, not just currentPlayer', () {
      final context = _buildContext(
        players: [
          const Player(id: 'p1', name: 'A'),
          Player(
            id: 'p2',
            name: 'B',
            stats: const PlayerStats({StatType.cunning: 3}),
          ),
        ],
      );
      expect(
        const AnyPlayerStatAtLeastCondition(
          stat: StatType.cunning,
          value: 2,
        ).isSatisfied(context),
        isTrue,
      );
    });

    test('false when nobody in the party meets the threshold', () {
      final context = _buildContext(
        players: [
          const Player(id: 'p1', name: 'A'),
          Player(
            id: 'p2',
            name: 'B',
            stats: const PlayerStats({StatType.cunning: 1}),
          ),
        ],
      );
      expect(
        const AnyPlayerStatAtLeastCondition(
          stat: StatType.cunning,
          value: 2,
        ).isSatisfied(context),
        isFalse,
      );
    });
  });

  group('Stat-gated choice end-to-end (a negotiation-style AdventureChoice)', () {
    test('the negotiate choice is only offered once charisma is high enough', () {
      final adventure = Adventure(
        id: 'negotiation_test',
        entryNodeId: 'confrontation',
        nodes: const {
          'confrontation': AdventureNode(
            id: 'confrontation',
            text: 't',
            choices: [
              AdventureChoice(
                label: 'Negotiate',
                conditions: [
                  CurrentPlayerStatAtLeastCondition(
                    stat: StatType.charisma,
                    value: 2,
                  ),
                ],
                onSuccess: NodeTransition(to: EndAdventure()),
              ),
              AdventureChoice(
                label: 'Accept the curse',
                onSuccess: NodeTransition(to: EndAdventure()),
              ),
            ],
          ),
        },
      );
      final engine = AdventureEngine(const ActionExecutor());

      final lowCharisma = _buildContext(
        players: [const Player(id: 'p1', name: 'A')],
      );
      final entered = engine.enter(adventure, lowCharisma);
      expect(
        entered.state.pendingAdventureNode!.choices.map((c) => c.label),
        ['Accept the curse'],
      );

      final highCharisma = _buildContext(
        players: [
          Player(
            id: 'p1',
            name: 'A',
            stats: const PlayerStats({StatType.charisma: 2}),
          ),
        ],
      );
      final enteredHigh = engine.enter(adventure, highCharisma);
      expect(
        enteredHigh.state.pendingAdventureNode!.choices.map((c) => c.label),
        ['Negotiate', 'Accept the curse'],
      );
    });
  });

  group('item_ward_amulet auto-block (effect_mystery pairing)', () {
    test('holding the ward effect absorbs the next curse instead of applying it', () {
      const wardEffect = GameEffect(
        id: 'effect_mystery',
        name: 'Оберег',
        description: 'd',
        polarity: EffectPolarity.positive,
        duration: -1,
        remainingTurns: -1,
        blocksNextNegativeEffect: true,
      );
      const curseEffect = GameEffect(
        id: 'effect_witchs_mark',
        name: 'Отмеченный ведьмой',
        description: 'd',
        polarity: EffectPolarity.negative,
        duration: -1,
        remainingTurns: -1,
      );
      final context = GameContext(
        state: GameState(
          players: const [Player(id: 'p1', name: 'A')],
          currentPlayerIndex: 0,
          status: GameStatus.inProgress,
        ),
        random: RandomProvider(seed: 1),
        cardCatalog: const CardCatalog([]),
        itemCatalog: const ItemCatalog({}),
        effectCatalog: const EffectCatalog({
          'effect_mystery': wardEffect,
          'effect_witchs_mark': curseEffect,
        }),
        adventureCatalog: const AdventureCatalog({}),
        biomeCatalog: const BiomeCatalog({}),
        originCatalog: const OriginCatalog({}),
        eventBus: GameEventBus(),
        mode: GameMode.classic,
      );
      const executor = ActionExecutor();

      var next = executor.execute(
        const ApplyEffectAction(effectId: 'effect_mystery'),
        context,
      );
      expect(next.currentPlayer.activeEffects.map((e) => e.id), ['effect_mystery']);

      next = executor.execute(
        const ApplyEffectAction(effectId: 'effect_witchs_mark'),
        next,
      );

      expect(next.currentPlayer.activeEffects, isEmpty);
    });
  });
}
