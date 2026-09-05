import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

const _testOrigin = Origin(
  id: 'origin_test',
  name: 'Test Origin',
  description: 'd',
  category: OriginCategory.lifePath,
  rarity: Rarity.common,
  statModifiers: {StatType.strength: 1, StatType.luck: -1},
);

GameContext _buildContext({
  required List<Player> players,
  WorldState worldState = const WorldState(),
  List<GameCard> cards = const [],
  OriginCatalog originCatalog = const OriginCatalog({'origin_test': _testOrigin}),
  int seed = 1,
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
    itemCatalog: const ItemCatalog({}),
    effectCatalog: const EffectCatalog({}),
    adventureCatalog: const AdventureCatalog({}),
    biomeCatalog: const BiomeCatalog({}),
    originCatalog: originCatalog,
    eventBus: GameEventBus(),
    mode: GameMode.classic,
  );
}

const _sailor = Player(id: 'p1', name: 'A', originId: 'origin_sailor');
const _noOrigin = Player(id: 'p2', name: 'B');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Origin conditions', () {
    test('CurrentPlayerHasOriginCondition checks whoever the event resolved to', () {
      final withSailor = _buildContext(players: [_sailor]);
      final withoutSailor = _buildContext(players: [_noOrigin]);

      expect(
        const CurrentPlayerHasOriginCondition(originId: 'origin_sailor').isSatisfied(withSailor),
        isTrue,
      );
      expect(
        const CurrentPlayerHasOriginCondition(originId: 'origin_sailor').isSatisfied(withoutSailor),
        isFalse,
      );
    });

    test(
      'CurrentPlayerLacksOriginCondition closes a door for one origin, and '
      'stays open for a player whose origin is still unrevealed',
      () {
        final withSailor = _buildContext(players: [_sailor]);
        final unrevealed = _buildContext(players: [_noOrigin]);

        const lacksSailor = CurrentPlayerLacksOriginCondition(
          originId: 'origin_sailor',
        );

        expect(lacksSailor.isSatisfied(withSailor), isFalse);
        // Not being revealed as a sailor means the world has no reason to
        // treat you as one — the option stays available.
        expect(lacksSailor.isSatisfied(unrevealed), isTrue);
      },
    );

    test('AnyPlayerHasOriginCondition checks the whole party, not just currentPlayer', () {
      final context = _buildContext(players: [_noOrigin, _sailor]);
      expect(
        const AnyPlayerHasOriginCondition(originId: 'origin_sailor').isSatisfied(context),
        isTrue,
      );
      expect(
        const AnyPlayerHasOriginCondition(originId: 'origin_mountaineer').isSatisfied(context),
        isFalse,
      );
    });
  });

  group('HasOriginParticipant', () {
    const resolver = ParticipantResolver();

    test('resolves to a player with the given origin', () {
      final context = _buildContext(players: [_noOrigin, _sailor]);
      final result =
          resolver.resolve(
                const HasOriginParticipant(originId: 'origin_sailor'),
                context,
              )
              as ResolvedParticipant;
      expect(result.context.currentPlayer.id, _sailor.id);
    });

    test('falls back to a random player when nobody has that origin', () {
      final context = _buildContext(players: [_noOrigin]);
      final result =
          resolver.resolve(
                const HasOriginParticipant(originId: 'origin_sailor'),
                context,
              )
              as ResolvedParticipant;
      expect(result.context.currentPlayer.id, _noOrigin.id);
    });
  });

  group('MinimumStepsSinceFlagCondition', () {
    test('false when the flag was never set', () {
      final context = _buildContext(players: [_noOrigin]);
      expect(
        const MinimumStepsSinceFlagCondition(flag: 'x', steps: 3).isSatisfied(context),
        isFalse,
      );
    });

    test('false before enough steps have passed, true once they have', () {
      const executor = ActionExecutor();
      var context = _buildContext(
        players: [_noOrigin],
        worldState: const WorldState(),
      );
      // Simulate partySteps=2 when the flag is set.
      context = context.withState(context.state.copyWith(partySteps: 2));
      context = executor.execute(const SetWorldFlagAction(flag: 'x'), context);

      const condition = MinimumStepsSinceFlagCondition(flag: 'x', steps: 3);

      final tooEarly = context.withState(context.state.copyWith(partySteps: 4));
      expect(condition.isSatisfied(tooEarly), isFalse);

      final justEnough = context.withState(context.state.copyWith(partySteps: 5));
      expect(condition.isSatisfied(justEnough), isTrue);
    });

    test('false again once the flag is unset', () {
      const executor = ActionExecutor();
      var context = _buildContext(players: [_noOrigin]);
      context = executor.execute(const SetWorldFlagAction(flag: 'x'), context);
      context = context.withState(context.state.copyWith(partySteps: 10));
      context = executor.execute(
        const SetWorldFlagAction(flag: 'x', value: false),
        context,
      );

      expect(
        const MinimumStepsSinceFlagCondition(flag: 'x', steps: 1).isSatisfied(context),
        isFalse,
      );
    });
  });

  group('GameController end-to-end delayed payoff', () {
    test(
      'a payoff card only becomes eligible after enough steps have passed since the trigger fired',
      () {
        final trigger = GameCard(
          id: 'trigger',
          title: 't',
          description: 'd',
          type: CardType.event,
          rarity: Rarity.common,
          weight: 1,
          conditions: const [WorldFlagUnsetCondition(flag: 'x')],
          actions: const [SetWorldFlagAction(flag: 'x')],
        );
        // Only eligible once the flag is set, at ordinary weight — the
        // "nothing special happened" filler that competes with `payoff`
        // once both become eligible.
        final idle = GameCard(
          id: 'idle',
          title: 't',
          description: 'd',
          type: CardType.event,
          rarity: Rarity.common,
          weight: 1,
          conditions: const [WorldFlagSetCondition(flag: 'x')],
        );
        // Weighted so overwhelmingly heavier than `idle` that once both are
        // eligible, this is drawn for all practical purposes — avoids the
        // test depending on a precisely-tuned RNG seed to be deterministic.
        final payoff = GameCard(
          id: 'payoff',
          title: 't',
          description: 'd',
          type: CardType.event,
          rarity: Rarity.common,
          weight: 1000000,
          conditions: const [
            WorldFlagSetCondition(flag: 'x'),
            MinimumStepsSinceFlagCondition(flag: 'x', steps: 2),
          ],
        );

        final controller = GameController(
          playerNames: const ['A'],
          cards: [trigger, idle, payoff],
          itemCatalog: const ItemCatalog({}),
          effectCatalog: const EffectCatalog({}),
          adventureCatalog: const AdventureCatalog({}),
          biomeCatalog: const BiomeCatalog({}),
          originCatalog: const OriginCatalog({}),
          seed: 1,
          skipPrologue: true,
        );

        // Step 1: only `trigger` is eligible (flag unset) — it fires and
        // sets the flag, stamping the current party step.
        controller.takeStep();
        expect(controller.state.pendingCard?.id, 'trigger');
        controller.resolveCard();
        expect(controller.state.worldState.flag('x'), isTrue);

        // Step 2: flag is set but only 1 step has passed since — `payoff`
        // isn't eligible yet (needs 2), so `idle` is the only option.
        controller.takeStep();
        expect(controller.state.pendingCard?.id, 'idle');
        controller.resolveCard();

        // Step 3: now 2 steps have passed since the flag was set — the
        // delayed payoff finally becomes eligible, and its overwhelming
        // weight makes it the one drawn.
        controller.takeStep();
        expect(controller.state.pendingCard?.id, 'payoff');
      },
    );
  });

  group('AnyPlayerMissingOriginCondition', () {
    test('true while at least one player is still Unknown', () {
      final context = _buildContext(players: [_sailor, _noOrigin]);
      expect(
        const AnyPlayerMissingOriginCondition().isSatisfied(context),
        isTrue,
      );
    });

    test('false once every player has a revealed origin', () {
      final context = _buildContext(players: [_sailor]);
      expect(
        const AnyPlayerMissingOriginCondition().isSatisfied(context),
        isFalse,
      );
    });
  });

  group('CurrentPlayerOriginUnknownCondition', () {
    test('true when whoever the event resolved to is still Unknown', () {
      final context = _buildContext(players: [_noOrigin]);
      expect(
        const CurrentPlayerOriginUnknownCondition().isSatisfied(context),
        isTrue,
      );
    });

    test('false once that specific player has been revealed', () {
      final context = _buildContext(players: [_sailor]);
      expect(
        const CurrentPlayerOriginUnknownCondition().isSatisfied(context),
        isFalse,
      );
    });

    test(
      'is unaffected by other players still being Unknown, unlike AnyPlayerMissingOriginCondition',
      () {
        final context = _buildContext(players: [_sailor, _noOrigin]);
        expect(
          const CurrentPlayerOriginUnknownCondition().isSatisfied(context),
          isFalse,
        );
      },
    );
  });

  group('Origin JSON round-trip', () {
    test('rarity and category survive fromJson/toJson', () {
      final json = _testOrigin.toJson();
      expect(json['rarity'], 'common');
      expect(json['category'], 'lifePath');

      final parsed = Origin.fromJson(json);
      expect(parsed.rarity, Rarity.common);
      expect(parsed.category, OriginCategory.lifePath);
      expect(parsed.statModifiers, _testOrigin.statModifiers);
    });
  });

  group('UnknownOriginParticipant', () {
    const resolver = ParticipantResolver();

    test('resolves to a player who has no origin yet', () {
      final context = _buildContext(players: [_sailor, _noOrigin]);
      final result =
          resolver.resolve(const UnknownOriginParticipant(), context)
              as ResolvedParticipant;
      expect(result.context.currentPlayer.id, _noOrigin.id);
    });

    test('falls back to a random player when everyone is already revealed', () {
      final context = _buildContext(players: [_sailor]);
      final result =
          resolver.resolve(const UnknownOriginParticipant(), context)
              as ResolvedParticipant;
      expect(result.context.currentPlayer.id, _sailor.id);
    });
  });

  group('RevealOriginAction', () {
    const executor = ActionExecutor();

    test('sets originId and applies the origin\'s stat modifiers once', () {
      final context = _buildContext(players: [_noOrigin]);

      final next = executor.execute(
        const RevealOriginAction(originId: 'origin_test'),
        context,
      );

      expect(next.currentPlayer.originId, 'origin_test');
      expect(next.currentPlayer.stats.valueOf(StatType.strength), 1);
      expect(next.currentPlayer.stats.valueOf(StatType.luck), -1);
    });

    test('is a no-op for a player who already has an origin', () {
      final context = _buildContext(players: [_sailor]);

      final next = executor.execute(
        const RevealOriginAction(originId: 'origin_test'),
        context,
      );

      expect(next.currentPlayer.originId, 'origin_sailor');
      expect(next.currentPlayer.stats.valueOf(StatType.strength), 0);
    });
  });

  group('GameController end-to-end origin reveal', () {
    test('a revealed origin persists through the rest of the match', () {
      final revealCard = GameCard(
        id: 'reveal',
        title: 't',
        description: 'd',
        type: CardType.event,
        rarity: Rarity.common,
        weight: 1,
        conditions: const [AnyPlayerMissingOriginCondition()],
        participant: const UnknownOriginParticipant(),
        actions: const [RevealOriginAction(originId: 'origin_test')],
      );
      final filler = GameCard(
        id: 'filler',
        title: 't',
        description: 'd',
        type: CardType.event,
        rarity: Rarity.common,
        weight: 1,
      );

      final controller = GameController(
        playerNames: const ['A'],
        cards: [revealCard, filler],
        itemCatalog: const ItemCatalog({}),
        effectCatalog: const EffectCatalog({}),
        adventureCatalog: const AdventureCatalog({}),
        biomeCatalog: const BiomeCatalog({}),
        originCatalog: const OriginCatalog({'origin_test': _testOrigin}),
        seed: 1,
        skipPrologue: true,
      );

      // Every player starts Unknown.
      expect(controller.state.players.single.originId, isNull);

      // Draw and resolve steps until the reveal card fires (both cards
      // share equal weight, so this is bounded but not on the very first
      // draw necessarily).
      for (var i = 0; i < 20; i++) {
        controller.takeStep();
        if (controller.state.pendingCard?.id == 'reveal') break;
        controller.resolveCard();
      }
      expect(controller.state.pendingCard?.id, 'reveal');
      controller.resolveCard();

      expect(controller.state.players.single.originId, 'origin_test');
      expect(
        controller.state.players.single.stats.valueOf(StatType.strength),
        1,
      );

      // Take several more steps — the origin should never be cleared or
      // overwritten, and `AnyPlayerMissingOriginCondition` should now keep
      // `reveal` out of the pool entirely (it's the only other-than-filler
      // card, so if it were still eligible the draw would throw once its
      // own precondition trivially holds — instead `filler` keeps being
      // the only eligible card).
      for (var i = 0; i < 5; i++) {
        controller.takeStep();
        expect(controller.state.pendingCard?.id, 'filler');
        controller.resolveCard();
        expect(controller.state.players.single.originId, 'origin_test');
      }
    });
  });
}
