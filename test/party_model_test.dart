import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

const _sharedItem = InventoryItem(
  id: 'itm_shared',
  name: 'Shared Item',
  description: 'd',
  rarity: Rarity.common,
  usageType: ItemUsageType.manual,
  isConsumable: false,
  ownership: ItemOwnership.shared,
);

const _personalItem = InventoryItem(
  id: 'itm_personal',
  name: 'Personal Item',
  description: 'd',
  rarity: Rarity.common,
  usageType: ItemUsageType.manual,
  isConsumable: false,
);

GameContext _buildContext({
  required List<Player> players,
  int seed = 1,
  List<GameCard> cards = const [],
  WorldState worldState = const WorldState(),
}) {
  return GameContext(
    state: GameState(
      players: players,
      currentPlayerIndex: 0,
      status: GameStatus.inProgress,
      worldState: worldState,
    ),
    random: RandomProvider(seed: seed),
    cardCatalog: CardCatalog(cards),
    itemCatalog: ItemCatalog({
      _sharedItem.id: _sharedItem,
      _personalItem.id: _personalItem,
    }),
    effectCatalog: const EffectCatalog({}),
    adventureCatalog: const AdventureCatalog({}),
    biomeCatalog: const BiomeCatalog({}),
    originCatalog: const OriginCatalog({}),
    eventBus: GameEventBus(),
    mode: GameMode.classic,
  );
}

const _p1 = Player(id: 'p1', name: 'A');
const _p2 = Player(id: 'p2', name: 'B');
const _p3 = Player(id: 'p3', name: 'C');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ParticipantResolver', () {
    const resolver = ParticipantResolver();

    test('RandomPlayerParticipant resolves to some player in the party', () {
      final context = _buildContext(players: [_p1, _p2, _p3]);
      final result =
          resolver.resolve(const RandomPlayerParticipant(), context)
              as ResolvedParticipant;

      expect([_p1.id, _p2.id, _p3.id], contains(result.context.currentPlayer.id));
      expect(result.context.state.secondaryPlayerIndex, isNull);
    });

    test('TwoRandomPlayersParticipant picks two distinct players', () {
      final context = _buildContext(players: [_p1, _p2, _p3], seed: 5);
      final result =
          resolver.resolve(const TwoRandomPlayersParticipant(), context)
              as ResolvedParticipant;

      final primary = result.context.currentPlayer;
      final secondary = result.context.state.secondaryPlayer;
      expect(secondary, isNotNull);
      expect(primary.id, isNot(secondary!.id));
    });

    test('MaxStatParticipant picks the player with the highest stat', () {
      final strong = _p1.copyWith(
        stats: const PlayerStats({StatType.strength: 10}),
      );
      final weak = _p2.copyWith(
        stats: const PlayerStats({StatType.strength: 1}),
      );
      final context = _buildContext(players: [weak, strong]);

      final result =
          resolver.resolve(
                const MaxStatParticipant(stat: StatType.strength),
                context,
              )
              as ResolvedParticipant;

      expect(result.context.currentPlayer.id, strong.id);
    });

    test('MinStatParticipant picks the player with the lowest stat', () {
      final strong = _p1.copyWith(
        stats: const PlayerStats({StatType.luck: 10}),
      );
      final weak = _p2.copyWith(stats: const PlayerStats({StatType.luck: 1}));
      final context = _buildContext(players: [strong, weak]);

      final result =
          resolver.resolve(
                const MinStatParticipant(stat: StatType.luck),
                context,
              )
              as ResolvedParticipant;

      expect(result.context.currentPlayer.id, weak.id);
    });

    test('HasItemParticipant picks a holder of the item', () {
      final holder = _p2.copyWith(inventory: const [_personalItem]);
      final context = _buildContext(players: [_p1, holder, _p3]);

      final result =
          resolver.resolve(
                const HasItemParticipant(itemId: 'itm_personal'),
                context,
              )
              as ResolvedParticipant;

      expect(result.context.currentPlayer.id, holder.id);
    });

    test('HasItemParticipant falls back to a random player when nobody holds it', () {
      final context = _buildContext(players: [_p1, _p2]);

      final result =
          resolver.resolve(
                const HasItemParticipant(itemId: 'itm_personal'),
                context,
              )
              as ResolvedParticipant;

      expect([_p1.id, _p2.id], contains(result.context.currentPlayer.id));
    });

    test('ChosenParticipant needs a manual pick instead of resolving', () {
      final context = _buildContext(players: [_p1, _p2]);
      final result = resolver.resolve(const ChosenParticipant(), context);
      expect(result, isA<NeedsManualPick>());
    });

    test('resolveChosen sets the picked player as currentPlayer', () {
      final context = _buildContext(players: [_p1, _p2]);
      final next = resolver.resolveChosen(_p2.id, context);
      expect(next.currentPlayer.id, _p2.id);
    });

    test('PreviousParticipant resolves to WorldState.previousParticipantId', () {
      final context = _buildContext(
        players: [_p1, _p2, _p3],
        worldState: const WorldState(previousParticipantId: 'p2'),
      );
      final result =
          resolver.resolve(const PreviousParticipant(), context)
              as ResolvedParticipant;
      expect(result.context.currentPlayer.id, 'p2');
    });

    test('PreviousParticipant falls back to random when there is no previous event', () {
      final context = _buildContext(players: [_p1, _p2]);
      final result =
          resolver.resolve(const PreviousParticipant(), context)
              as ResolvedParticipant;
      expect([_p1.id, _p2.id], contains(result.context.currentPlayer.id));
    });

    test('PreviousWinner / PreviousLoser resolve to the remembered duel outcome', () {
      final context = _buildContext(
        players: [_p1, _p2, _p3],
        worldState: const WorldState(
          previousWinnerId: 'p3',
          previousLoserId: 'p1',
        ),
      );

      final winnerResult =
          resolver.resolve(const PreviousWinner(), context)
              as ResolvedParticipant;
      expect(winnerResult.context.currentPlayer.id, 'p3');

      final loserResult =
          resolver.resolve(const PreviousLoser(), context)
              as ResolvedParticipant;
      expect(loserResult.context.currentPlayer.id, 'p1');
    });

    test('LeaderParticipant resolves to WorldState.leaderId', () {
      final context = _buildContext(
        players: [_p1, _p2],
        worldState: const WorldState(leaderId: 'p2'),
      );
      final result =
          resolver.resolve(const LeaderParticipant(), context)
              as ResolvedParticipant;
      expect(result.context.currentPlayer.id, 'p2');
    });

    test('LeaderParticipant falls back to random when nobody has been made leader', () {
      final context = _buildContext(players: [_p1, _p2]);
      final result =
          resolver.resolve(const LeaderParticipant(), context)
              as ResolvedParticipant;
      expect([_p1.id, _p2.id], contains(result.context.currentPlayer.id));
    });
  });

  group('SetLeaderAction / LeaderIsSetCondition', () {
    test('SetLeaderAction makes the resolved target the leader', () {
      final context = _buildContext(players: [_p1, _p2]);
      const executor = ActionExecutor();

      final next = executor.execute(const SetLeaderAction(), context);

      expect(next.state.worldState.leaderId, _p1.id);
    });

    test('a leader stays leader across steps until reassigned', () {
      final context = _buildContext(players: [_p1, _p2]).withState(
        GameState(
          players: const [_p1, _p2],
          currentPlayerIndex: 1,
          status: GameStatus.inProgress,
          worldState: const WorldState(leaderId: 'p1'),
        ),
      );
      const executor = ActionExecutor();

      // p2 (index 1) is currentPlayer here; setting the leader again hands
      // the role to whoever is currentPlayer *now* — leadership isn't
      // sticky against reassignment, just against the passage of time.
      final next = executor.execute(const SetLeaderAction(), context);

      expect(next.state.worldState.leaderId, _p2.id);
    });

    test('LeaderIsSetCondition / LeaderIsUnsetCondition read WorldState.leaderId', () {
      final withLeader = _buildContext(
        players: [_p1],
        worldState: const WorldState(leaderId: 'p1'),
      );
      final withoutLeader = _buildContext(players: [_p1]);

      expect(const LeaderIsSetCondition().isSatisfied(withLeader), isTrue);
      expect(const LeaderIsSetCondition().isSatisfied(withoutLeader), isFalse);
      expect(const LeaderIsUnsetCondition().isSatisfied(withoutLeader), isTrue);
      expect(const LeaderIsUnsetCondition().isSatisfied(withLeader), isFalse);
    });
  });

  group('StartDuelAction remembers the outcome', () {
    test('records previousWinnerId / previousLoserId once a duel resolves', () {
      final context = _buildContext(players: [_p1, _p2], seed: 7);
      const executor = ActionExecutor();

      final next = executor.execute(const StartDuelAction(), context);

      final worldState = next.state.worldState;
      expect(worldState.previousWinnerId, isNotNull);
      expect(worldState.previousLoserId, isNotNull);
      expect(worldState.previousWinnerId, isNot(worldState.previousLoserId));
      expect(
        {worldState.previousWinnerId, worldState.previousLoserId},
        {_p1.id, _p2.id},
      );
    });
  });

  group('GameController chains PreviousParticipant across steps', () {
    test(
      'a card drawn after another resolves PreviousParticipant to the earlier card\'s actor',
      () {
        final anchorCard = GameCard(
          id: 'anchor',
          title: 't',
          description: 'd',
          type: CardType.event,
          rarity: Rarity.common,
          weight: 1,
          conditions: const [MaximumStepCondition(steps: 1)],
        );
        final followUpCard = GameCard(
          id: 'follow_up',
          title: 't',
          description: 'd',
          type: CardType.event,
          rarity: Rarity.common,
          weight: 1,
          conditions: const [MinimumStepCondition(steps: 2)],
          participant: const PreviousParticipant(),
        );

        final controller = GameController(
          playerNames: const ['A', 'B', 'C'],
          cards: [anchorCard, followUpCard],
          itemCatalog: const ItemCatalog({}),
          effectCatalog: const EffectCatalog({}),
          adventureCatalog: const AdventureCatalog({}),
          biomeCatalog: const BiomeCatalog({}),
          originCatalog: const OriginCatalog({}),
          seed: 3,
          skipPrologue: true,
        );

        controller.takeStep();
        final firstActorId = controller.state.currentPlayer.id;
        controller.resolveCard();

        controller.takeStep();
        expect(controller.state.pendingCard?.id, 'follow_up');
        expect(controller.state.currentPlayer.id, firstActorId);
      },
    );
  });

  group('ActionTarget secondary/left/right', () {
    test('secondaryPlayer resolves to GameState.secondaryPlayer', () {
      final context = _buildContext(players: [_p1, _p2, _p3]).withState(
        GameState(
          players: const [_p1, _p2, _p3],
          currentPlayerIndex: 0,
          secondaryPlayerIndex: 2,
          status: GameStatus.inProgress,
        ),
      );
      const executor = ActionExecutor();

      final next = executor.execute(
        const ModifyStatAction(
          stat: StatType.luck,
          amount: 1,
          target: ActionTarget.secondaryPlayer,
        ),
        context,
      );

      expect(
        next.players.firstWhere((p) => p.id == _p3.id).stats.valueOf(StatType.luck),
        1,
      );
      expect(
        next.players.firstWhere((p) => p.id != _p3.id).stats.valueOf(StatType.luck),
        0,
      );
    });

    test('secondaryPlayer falls back to currentPlayer when none was picked', () {
      final context = _buildContext(players: [_p1, _p2]);
      const executor = ActionExecutor();

      final next = executor.execute(
        const ModifyStatAction(
          stat: StatType.luck,
          amount: 1,
          target: ActionTarget.secondaryPlayer,
        ),
        context,
      );

      expect(next.currentPlayer.stats.valueOf(StatType.luck), 1);
    });

    test('leftOfCurrentPlayer/rightOfCurrentPlayer wrap around the table', () {
      final context = _buildContext(players: [_p1, _p2, _p3]);
      const executor = ActionExecutor();

      final leftOfFirst = executor.execute(
        const ModifyStatAction(
          stat: StatType.luck,
          amount: 1,
          target: ActionTarget.leftOfCurrentPlayer,
        ),
        context,
      );
      // currentPlayer is p1 (index 0); left wraps to the last player, p3.
      expect(
        leftOfFirst.players.firstWhere((p) => p.id == _p3.id).stats.valueOf(StatType.luck),
        1,
      );

      final rightOfFirst = executor.execute(
        const ModifyStatAction(
          stat: StatType.luck,
          amount: 1,
          target: ActionTarget.rightOfCurrentPlayer,
        ),
        context,
      );
      expect(
        rightOfFirst.players.firstWhere((p) => p.id == _p2.id).stats.valueOf(StatType.luck),
        1,
      );
    });
  });

  group('Personal vs shared items', () {
    test('a shared item is granted to GameState.partyInventory, not a player', () {
      final context = _buildContext(players: [_p1, _p2]);
      const executor = ActionExecutor();

      final next = executor.execute(
        const GiveItemAction(itemId: 'itm_shared'),
        context,
      );

      expect(next.state.partyInventory.map((i) => i.id), contains('itm_shared'));
      expect(next.currentPlayer.inventory, isEmpty);
    });

    test('a personal item is granted to the targeted player as before', () {
      final context = _buildContext(players: [_p1, _p2]);
      const executor = ActionExecutor();

      final next = executor.execute(
        const GiveItemAction(itemId: 'itm_personal'),
        context,
      );

      expect(next.currentPlayer.inventory.map((i) => i.id), contains('itm_personal'));
      expect(next.state.partyInventory, isEmpty);
    });

    test('TakeItemAction removes a shared item from the party inventory', () {
      final context = _buildContext(players: [_p1, _p2]).withState(
        GameState(
          players: const [_p1, _p2],
          currentPlayerIndex: 0,
          status: GameStatus.inProgress,
          partyInventory: const [_sharedItem],
        ),
      );
      const executor = ActionExecutor();

      final next = executor.execute(
        const TakeItemAction(itemId: 'itm_shared'),
        context,
      );

      expect(next.state.partyInventory, isEmpty);
    });

    test('PartyHasItemCondition / PartyMissingItemCondition read the shared pool', () {
      final withItem = _buildContext(players: [_p1]).withState(
        GameState(
          players: const [_p1],
          currentPlayerIndex: 0,
          status: GameStatus.inProgress,
          partyInventory: const [_sharedItem],
        ),
      );
      final withoutItem = _buildContext(players: [_p1]);

      expect(
        const PartyHasItemCondition(itemId: 'itm_shared').isSatisfied(withItem),
        isTrue,
      );
      expect(
        const PartyMissingItemCondition(itemId: 'itm_shared').isSatisfied(withoutItem),
        isTrue,
      );
    });
  });

  group('EffectLifecycle.expireForAllPlayers', () {
    test('ticks down every player, not just the current one', () {
      const shortEffect = GameEffect(
        id: 'eff_short',
        name: 'Short',
        description: 'd',
        polarity: EffectPolarity.negative,
        duration: 1,
        remainingTurns: 1,
      );
      final cursed = _p2.copyWith(activeEffects: const [shortEffect]);
      final context = _buildContext(players: [_p1, cursed]);
      const lifecycle = EffectLifecycle();

      // currentPlayer is p1 (index 0), but the effect sitting on p2 should
      // still expire — durations count party steps, not whoever's turn it
      // notionally is.
      final next = lifecycle.expireForAllPlayers(context);

      expect(
        next.players.firstWhere((p) => p.id == cursed.id).activeEffects,
        isEmpty,
      );
    });
  });

  group('GameController party flow', () {
    test(
      'a ChosenParticipant card suspends on pendingParticipantSelection until resolveParticipant is called',
      () {
        final chosenCard = GameCard(
          id: 'chosen_card',
          title: 'Кто идёт?',
          description: 'd',
          type: CardType.event,
          rarity: Rarity.common,
          weight: 1,
          participant: const ChosenParticipant(),
        );

        final controller = GameController(
          playerNames: const ['A', 'B'],
          cards: [chosenCard],
          itemCatalog: const ItemCatalog({}),
          effectCatalog: const EffectCatalog({}),
          adventureCatalog: const AdventureCatalog({}),
          biomeCatalog: const BiomeCatalog({}),
          originCatalog: const OriginCatalog({}),
          seed: 1,
          skipPrologue: true,
        );

        controller.takeStep();
        expect(controller.state.pendingParticipantSelection?.id, 'chosen_card');
        expect(controller.state.pendingCard, isNull);

        final pickedId = controller.state.players[1].id;
        controller.resolveParticipant(pickedId);

        expect(controller.state.pendingParticipantSelection, isNull);
        expect(controller.state.pendingCard?.id, 'chosen_card');
        expect(controller.state.currentPlayer.id, pickedId);
      },
    );

    test('the party finishes cooperatively once partySteps reaches the goal', () {
      final filler = GameCard(
        id: 'filler',
        title: 't',
        description: 'd',
        type: CardType.event,
        rarity: Rarity.common,
        weight: 1,
      );

      final controller = GameController(
        playerNames: const ['A', 'B'],
        cards: [filler],
        itemCatalog: const ItemCatalog({}),
        effectCatalog: const EffectCatalog({}),
        adventureCatalog: const AdventureCatalog({}),
        biomeCatalog: const BiomeCatalog({}),
        originCatalog: const OriginCatalog({}),
        seed: 1,
        skipPrologue: true,
      );

      for (var i = 0; i < 20; i++) {
        controller.takeStep();
        if (controller.state.status == GameStatus.finished) break;
        controller.resolveCard();
      }

      expect(controller.state.status, GameStatus.finished);
      expect(controller.state.partySteps, 20);
    });
  });
}
