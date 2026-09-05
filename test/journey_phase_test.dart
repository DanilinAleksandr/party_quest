import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

const _player = Player(id: 'p1', name: 'A');

GameContext _buildContext({
  List<GameCard> cards = const [],
  JourneyPhase phase = JourneyPhase.journey,
  WorldState worldState = const WorldState(),
}) {
  return GameContext(
    state: GameState(
      players: const [_player],
      currentPlayerIndex: 0,
      status: GameStatus.inProgress,
      phase: phase,
      worldState: worldState,
    ),
    random: RandomProvider(seed: 1),
    cardCatalog: CardCatalog(cards),
    itemCatalog: const ItemCatalog({}),
    effectCatalog: const EffectCatalog({}),
    adventureCatalog: const AdventureCatalog({}),
    biomeCatalog: const BiomeCatalog({}),
    originCatalog: const OriginCatalog({}),
    eventBus: GameEventBus(),
    mode: GameMode.classic,
  );
}

const _prologueCard = GameCard(
  id: 'prologue_card',
  title: 't',
  description: 'd',
  type: CardType.event,
  rarity: Rarity.common,
  weight: 5,
  tags: [CardTag.prologue],
);

const _journeyCard = GameCard(
  id: 'journey_card',
  title: 't',
  description: 'd',
  type: CardType.event,
  rarity: Rarity.common,
  weight: 5,
);

const _tavernCard = GameCard(
  id: 'tavern_card',
  title: 't',
  description: 'd',
  type: CardType.event,
  rarity: Rarity.common,
  weight: 5,
  tags: [CardTag.tavern],
);

void main() {
  group('InPhaseCondition', () {
    test('is satisfied only while GameState.phase matches', () {
      final duringPrologue = _buildContext(phase: JourneyPhase.prologue);
      final duringJourney = _buildContext(phase: JourneyPhase.journey);

      const condition = InPhaseCondition(phase: JourneyPhase.prologue);

      expect(condition.isSatisfied(duringPrologue), isTrue);
      expect(condition.isSatisfied(duringJourney), isFalse);
    });
  });

  group('SetPhaseAction', () {
    test('changes GameState.phase', () {
      final context = _buildContext(phase: JourneyPhase.prologue);
      const executor = ActionExecutor();

      final next = executor.execute(
        const SetPhaseAction(phase: JourneyPhase.journey),
        context,
      );

      expect(next.state.phase, JourneyPhase.journey);
    });
  });

  group('CardCatalog phase-tag filtering', () {
    test(
      'during prologue, only CardTag.prologue cards are eligible',
      () {
        final context = _buildContext(
          cards: [_prologueCard, _journeyCard],
          phase: JourneyPhase.prologue,
        );

        final eligible = context.cardCatalog.eligibleCards(context);

        expect(eligible.map((c) => c.id), equals(['prologue_card']));
      },
    );

    test(
      'outside prologue, every card stays eligible regardless of tag',
      () {
        final context = _buildContext(
          cards: [_prologueCard, _journeyCard],
          phase: JourneyPhase.journey,
        );

        final eligible = context.cardCatalog.eligibleCards(context);

        expect(
          eligible.map((c) => c.id),
          containsAll(['prologue_card', 'journey_card']),
        );
      },
    );
  });

  group('CardCatalog tavern-tag filtering', () {
    test(
      'while in_tavern is set, only CardTag.tavern cards are eligible — '
      'even a card whose own conditions are otherwise satisfied',
      () {
        final context = _buildContext(
          cards: [_tavernCard, _journeyCard],
          worldState: const WorldState(flags: {'in_tavern': true}),
        );

        final eligible = context.cardCatalog.eligibleCards(context);

        expect(eligible.map((c) => c.id), equals(['tavern_card']));
      },
    );

    test(
      'while in_tavern is unset, every card stays eligible regardless of '
      'tag',
      () {
        final context = _buildContext(cards: [_tavernCard, _journeyCard]);

        final eligible = context.cardCatalog.eligibleCards(context);

        expect(
          eligible.map((c) => c.id),
          containsAll(['tavern_card', 'journey_card']),
        );
      },
    );
  });

  group('GameController end-to-end journey phase', () {
    GameController buildController({required List<GameCard> cards}) {
      return GameController(
        playerNames: const ['A', 'B'],
        cards: cards,
        itemCatalog: const ItemCatalog({}),
        effectCatalog: const EffectCatalog({}),
        adventureCatalog: const AdventureCatalog({}),
        biomeCatalog: BiomeCatalog({
          'forest': const Biome(id: 'forest', name: 'Лес', description: 'd'),
        }),
        originCatalog: const OriginCatalog({}),
        seed: 42,
      );
    }

    test('a new game starts in JourneyPhase.prologue', () {
      final controller = buildController(cards: [_prologueCard]);
      expect(controller.state.phase, JourneyPhase.prologue);
    });

    test('only prologue-tagged cards draw while still in prologue', () {
      final controller = buildController(cards: [_prologueCard, _journeyCard]);

      controller.takeStep();

      expect(controller.state.pendingCard?.id, 'prologue_card');
      expect(controller.state.phase, JourneyPhase.prologue);
    });

    test(
      'a "leave prologue" card flips the phase and biome, and normal '
      'draw resumes afterward',
      () {
        const leaveProlgueCard = GameCard(
          id: 'leave_prologue',
          title: 't',
          description: 'd',
          type: CardType.event,
          rarity: Rarity.common,
          weight: 5,
          tags: [CardTag.prologue],
          // Mirrors the real leave-prologue content cards: the tag alone
          // only restricts draws *during* prologue, it doesn't stop this
          // card from being drawn again afterward — that's what this
          // condition is for.
          conditions: [InPhaseCondition(phase: JourneyPhase.prologue)],
          actions: [
            SetPhaseAction(phase: JourneyPhase.journey),
            SetBiomeAction(biomeId: 'forest'),
          ],
        );
        final controller = buildController(
          cards: [leaveProlgueCard, _journeyCard],
        );

        controller.takeStep();
        controller.resolveCard(choiceIndex: null);

        expect(controller.state.phase, JourneyPhase.journey);
        expect(controller.state.worldState.currentBiomeId, 'forest');

        controller.takeStep();
        expect(controller.state.pendingCard?.id, 'journey_card');
      },
    );
  });

  group('GameController journey length', () {
    GameController buildController(int? journeySteps) {
      return GameController(
        playerNames: const ['A', 'B'],
        cards: [_journeyCard],
        itemCatalog: const ItemCatalog({}),
        effectCatalog: const EffectCatalog({}),
        adventureCatalog: const AdventureCatalog({}),
        biomeCatalog: const BiomeCatalog({}),
        originCatalog: const OriginCatalog({}),
        seed: 1,
        skipPrologue: true,
        journeySteps: journeySteps,
      );
    }

    test('infinite mode never auto-finishes no matter how many steps pass', () {
      final controller = buildController(null);
      expect(controller.stepsToWin, isNull);

      for (var i = 0; i < 30; i++) {
        controller.takeStep();
        controller.resolveCard(choiceIndex: null);
      }

      expect(controller.state.status, isNot(GameStatus.finished));
    });

    test('endJourneyManually finishes an infinite-mode match', () {
      final controller = buildController(null);

      controller.endJourneyManually();

      expect(controller.state.status, GameStatus.finished);
    });
  });

  group('GameController tavern pause', () {
    const toTavernCard = GameCard(
      id: 'to_tavern',
      title: 't',
      description: 'd',
      type: CardType.event,
      rarity: Rarity.common,
      weight: 5,
      // Tavern entry no longer touches `currentBiomeId` at all — see
      // alko_quest_tavern_as_detour — it's purely a WorldState flag flip,
      // reusing the already-generic SetWorldFlagAction.
      actions: [SetWorldFlagAction(flag: 'in_tavern', value: true)],
    );
    const leaveTavernCard = GameCard(
      id: 'leave_tavern',
      title: 't',
      description: 'd',
      type: CardType.event,
      rarity: Rarity.common,
      weight: 5,
      tags: [CardTag.tavern],
      conditions: [WorldFlagSetCondition(flag: 'in_tavern')],
      actions: [SetWorldFlagAction(flag: 'in_tavern', value: false)],
    );
    // Once `in_tavern` is set, only CardTag.tavern-tagged cards are
    // eligible (see CardCatalog.eligibleCards) — a deck with only
    // `toTavernCard` would have nothing left to draw on the next step, so
    // tests that take more than one step inside the tavern need at least
    // one tavern-tagged card in the pool too.
    const tavernFillerCard = GameCard(
      id: 'tavern_filler',
      title: 't',
      description: 'd',
      type: CardType.event,
      rarity: Rarity.common,
      weight: 5,
      tags: [CardTag.tavern],
      conditions: [WorldFlagSetCondition(flag: 'in_tavern')],
    );

    test(
      'partySteps does not advance while the party is in the tavern, and '
      'the real biome never changes',
      () {
        final controller = GameController(
          playerNames: const ['A', 'B'],
          cards: [toTavernCard, tavernFillerCard],
          itemCatalog: const ItemCatalog({}),
          effectCatalog: const EffectCatalog({}),
          adventureCatalog: const AdventureCatalog({}),
          biomeCatalog: const BiomeCatalog({}),
          originCatalog: const OriginCatalog({}),
          seed: 1,
          skipPrologue: true,
        );
        final realBiomeOnEntry = controller.state.worldState.currentBiomeId;

        // This first step still counts — the flag is unset at the moment
        // `_incrementPartySteps` runs, and only flips true once the card's
        // own action resolves afterward.
        controller.takeStep();
        controller.resolveCard(choiceIndex: null);
        expect(controller.state.worldState.flag('in_tavern'), isTrue);
        // This is the direct proof of "resumes the same real biome": the
        // party is now "inside" the tavern, but the biome it was actually
        // traveling through never changed.
        expect(controller.state.worldState.currentBiomeId, realBiomeOnEntry);
        final stepsOnArrival = controller.state.partySteps;
        expect(stepsOnArrival, 1);

        // Now the party starts its next step already inside the tavern, so
        // this one should be skipped.
        controller.takeStep();
        controller.resolveCard(choiceIndex: null);

        expect(controller.state.partySteps, stepsOnArrival);
      },
    );

    test('partySteps advances normally outside the tavern', () {
      final controller = GameController(
        playerNames: const ['A', 'B'],
        cards: [_journeyCard],
        itemCatalog: const ItemCatalog({}),
        effectCatalog: const EffectCatalog({}),
        adventureCatalog: const AdventureCatalog({}),
        biomeCatalog: const BiomeCatalog({}),
        originCatalog: const OriginCatalog({}),
        seed: 1,
        skipPrologue: true,
      );

      controller.takeStep();
      controller.resolveCard(choiceIndex: null);

      expect(controller.state.partySteps, 1);
    });

    test('turnsInTavern increments while inside', () {
      final controller = GameController(
        playerNames: const ['A', 'B'],
        cards: [toTavernCard, tavernFillerCard],
        itemCatalog: const ItemCatalog({}),
        effectCatalog: const EffectCatalog({}),
        adventureCatalog: const AdventureCatalog({}),
        biomeCatalog: const BiomeCatalog({}),
        originCatalog: const OriginCatalog({}),
        seed: 1,
        skipPrologue: true,
      );

      // Entry step: the flag isn't set yet when the counter increments, so
      // it starts this step at 0.
      controller.takeStep();
      controller.resolveCard(choiceIndex: null);
      expect(controller.state.worldState.turnsInTavern, 0);

      controller.takeStep();
      controller.resolveCard(choiceIndex: null);
      expect(controller.state.worldState.turnsInTavern, 1);

      controller.takeStep();
      controller.resolveCard(choiceIndex: null);
      expect(controller.state.worldState.turnsInTavern, 2);
    });

    test('turnsInTavern resets to 0 once the party leaves', () {
      final controller = GameController(
        playerNames: const ['A', 'B'],
        cards: [toTavernCard, leaveTavernCard],
        itemCatalog: const ItemCatalog({}),
        effectCatalog: const EffectCatalog({}),
        adventureCatalog: const AdventureCatalog({}),
        biomeCatalog: const BiomeCatalog({}),
        originCatalog: const OriginCatalog({}),
        seed: 1,
        skipPrologue: true,
      );

      // Only `toTavernCard` is eligible before the flag is set.
      controller.takeStep();
      controller.resolveCard(choiceIndex: null);
      expect(controller.state.worldState.turnsInTavern, 0);

      // Only `leaveTavernCard` carries CardTag.tavern, so it's the only
      // eligible draw once inside — deterministic. `turnsInTavern` is
      // still computed *before* this step's action clears the flag, so it
      // reads 1 here (same one-step-lag `turnsInCurrentBiome` already has
      // around `SetBiomeAction`) — the reset only shows up on the step
      // after that.
      controller.takeStep();
      controller.resolveCard(choiceIndex: null);
      expect(controller.state.worldState.flag('in_tavern'), isFalse);
      expect(controller.state.worldState.turnsInTavern, 1);

      controller.takeStep();
      controller.resolveCard(choiceIndex: null);
      expect(controller.state.worldState.turnsInTavern, 0);
    });

    test(
      'a tavern-tagged exit card clears the flag and the party resumes the '
      'same real biome',
      () {
        final controller = GameController(
          playerNames: const ['A', 'B'],
          cards: [toTavernCard, leaveTavernCard],
          itemCatalog: const ItemCatalog({}),
          effectCatalog: const EffectCatalog({}),
          adventureCatalog: const AdventureCatalog({}),
          biomeCatalog: const BiomeCatalog({}),
          originCatalog: const OriginCatalog({}),
          seed: 1,
          skipPrologue: true,
        );
        final realBiome = controller.state.worldState.currentBiomeId;

        // Only `toTavernCard` is eligible before the flag is set (
        // `leaveTavernCard` requires it), so this draw is deterministic.
        controller.takeStep();
        controller.resolveCard(choiceIndex: null);
        expect(controller.state.worldState.flag('in_tavern'), isTrue);

        // Once inside, only `leaveTavernCard` carries CardTag.tavern, so
        // it's the only eligible draw — deterministic again.
        controller.takeStep();
        controller.resolveCard(choiceIndex: null);

        expect(controller.state.worldState.flag('in_tavern'), isFalse);
        expect(controller.state.worldState.currentBiomeId, realBiome);
      },
    );
  });
}
