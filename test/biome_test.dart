import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/data/biome_repository.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

const _forest = Biome(id: 'forest', name: 'Лес', description: 'd');
const _desert = Biome(id: 'desert', name: 'Пустыня', description: 'd');

GameContext _buildContext({
  required List<Player> players,
  List<GameCard> cards = const [],
  WorldState worldState = const WorldState(),
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
    biomeCatalog: BiomeCatalog({'forest': _forest, 'desert': _desert}),
    originCatalog: const OriginCatalog({}),
    eventBus: GameEventBus(),
    mode: GameMode.classic,
  );
}

const _player = Player(id: 'p1', name: 'A');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InBiomeCondition / NotInBiomeCondition', () {
    test('InBiomeCondition matches only the current biome', () {
      final inForest = _buildContext(
        players: [_player],
        worldState: const WorldState(currentBiomeId: 'forest'),
      );
      final inDesert = _buildContext(
        players: [_player],
        worldState: const WorldState(currentBiomeId: 'desert'),
      );

      expect(
        const InBiomeCondition(biomeId: 'forest').isSatisfied(inForest),
        isTrue,
      );
      expect(
        const InBiomeCondition(biomeId: 'forest').isSatisfied(inDesert),
        isFalse,
      );
      expect(
        const NotInBiomeCondition(biomeId: 'forest').isSatisfied(inDesert),
        isTrue,
      );
      expect(
        const NotInBiomeCondition(biomeId: 'forest').isSatisfied(inForest),
        isFalse,
      );
    });
  });

  group('SetBiomeAction', () {
    test('changes WorldState.currentBiomeId', () {
      final context = _buildContext(
        players: [_player],
        worldState: const WorldState(currentBiomeId: 'forest'),
      );
      const executor = ActionExecutor();

      final next = executor.execute(
        const SetBiomeAction(biomeId: 'desert'),
        context,
      );

      expect(next.state.worldState.currentBiomeId, 'desert');
    });

    test('resets turnsInCurrentBiome back to 0', () {
      final context = _buildContext(
        players: [_player],
        worldState: const WorldState(
          currentBiomeId: 'forest',
          turnsInCurrentBiome: 12,
        ),
      );
      const executor = ActionExecutor();

      final next = executor.execute(
        const SetBiomeAction(biomeId: 'desert'),
        context,
      );

      expect(next.state.worldState.turnsInCurrentBiome, 0);
    });

    test(
      'throws for an unknown biome id, the same safety net item/effect actions get',
      () {
        final context = _buildContext(players: [_player]);
        const executor = ActionExecutor();

        expect(
          () =>
              executor.execute(const SetBiomeAction(biomeId: 'ocean'), context),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('MinimumTurnsInBiomeCondition', () {
    test('is satisfied only once the turn count is reached', () {
      final tooEarly = _buildContext(
        players: [_player],
        worldState: const WorldState(turnsInCurrentBiome: 6),
      );
      final justEnough = _buildContext(
        players: [_player],
        worldState: const WorldState(turnsInCurrentBiome: 7),
      );

      expect(
        const MinimumTurnsInBiomeCondition(turns: 7).isSatisfied(tooEarly),
        isFalse,
      );
      expect(
        const MinimumTurnsInBiomeCondition(turns: 7).isSatisfied(justEnough),
        isTrue,
      );
    });
  });

  group('GameController turn-in-biome tracking', () {
    test(
      'turnsInCurrentBiome increments every turn and resets on a biome change',
      () {
        final transitionCard = GameCard(
          id: 'force_transition',
          title: 't',
          description: 'd',
          type: CardType.event,
          rarity: Rarity.common,
          weight: 1,
          actions: const [SetBiomeAction(biomeId: 'desert')],
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
          cards: [filler],
          itemCatalog: const ItemCatalog({}),
          effectCatalog: const EffectCatalog({}),
          adventureCatalog: const AdventureCatalog({}),
          biomeCatalog: BiomeCatalog({'forest': _forest, 'desert': _desert}),
          originCatalog: const OriginCatalog({}),
          seed: 1,
          skipPrologue: true,
        );

        controller.takeStep();
        expect(controller.state.worldState.turnsInCurrentBiome, 1);
        controller.resolveCard();
        controller.takeStep();
        expect(controller.state.worldState.turnsInCurrentBiome, 2);
        controller.resolveCard();

        // Swap in a card that forces a biome change and confirm the counter
        // resets on the following turn.
        final forcedController = GameController(
          playerNames: const ['A'],
          cards: [transitionCard],
          itemCatalog: const ItemCatalog({}),
          effectCatalog: const EffectCatalog({}),
          adventureCatalog: const AdventureCatalog({}),
          biomeCatalog: BiomeCatalog({'forest': _forest, 'desert': _desert}),
          originCatalog: const OriginCatalog({}),
          seed: 1,
          skipPrologue: true,
        );
        forcedController.takeStep();
        forcedController.resolveCard();
        expect(forcedController.state.worldState.currentBiomeId, 'desert');
        expect(forcedController.state.worldState.turnsInCurrentBiome, 0);
      },
    );
  });

  group('Road-event lean modifiers', () {
    test(
      'SetBiomeAction clears every lean_<biomeId> modifier once the biome actually changes',
      () {
        final context = _buildContext(
          players: [_player],
          worldState: const WorldState(
            currentBiomeId: 'forest',
            modifiers: {'lean_desert': 3, 'lean_forest': 1, 'unrelated': 7},
          ),
        );
        const executor = ActionExecutor();

        final next = executor.execute(
          const SetBiomeAction(biomeId: 'desert'),
          context,
        );

        expect(next.state.worldState.modifier('lean_desert'), 0);
        expect(next.state.worldState.modifier('lean_forest'), 0);
        expect(
          next.state.worldState.modifier('unrelated'),
          7,
          reason: 'unrelated modifiers should be left alone',
        );
      },
    );

    test(
      'the bundled leaned transition card for a biome is only eligible once its lean modifier is set',
      () async {
        final cards = await const CardRepository().loadCards();
        final biomeCatalog = await const BiomeRepository().loadCatalog();

        GameContext contextFor(Map<String, int> modifiers) => GameContext(
          state: GameState(
            players: const [_player],
            currentPlayerIndex: 0,
            status: GameStatus.inProgress,
            worldState: WorldState(
              currentBiomeId: 'forest',
              turnsInCurrentBiome: 7,
              modifiers: modifiers,
            ),
          ),
          random: RandomProvider(seed: 1),
          cardCatalog: CardCatalog(cards),
          itemCatalog: const ItemCatalog({}),
          effectCatalog: const EffectCatalog({}),
          adventureCatalog: const AdventureCatalog({}),
          biomeCatalog: biomeCatalog,
          originCatalog: const OriginCatalog({}),
          eventBus: GameEventBus(),
          mode: GameMode.classic,
        );

        final withoutLean = contextFor(const {});
        final eligibleWithoutLean = withoutLean.cardCatalog
            .eligibleCards(withoutLean)
            .map((c) => c.id);
        expect(eligibleWithoutLean, contains('transition_to_desert'));
        expect(
          eligibleWithoutLean,
          isNot(contains('transition_to_desert_leaned')),
        );

        final withLean = contextFor(const {'lean_desert': 1});
        final eligibleWithLean = withLean.cardCatalog
            .eligibleCards(withLean)
            .map((c) => c.id);
        expect(eligibleWithLean, contains('transition_to_desert'));
        expect(eligibleWithLean, contains('transition_to_desert_leaned'));
      },
    );
  });

  group('CardCatalog biome gating', () {
    test('a biome-gated card is only eligible in its own biome', () {
      final forestCard = GameCard(
        id: 'forest_only',
        title: 't',
        description: 'd',
        type: CardType.event,
        rarity: Rarity.common,
        weight: 1,
        conditions: const [InBiomeCondition(biomeId: 'forest')],
      );
      final universalCard = GameCard(
        id: 'anywhere',
        title: 't',
        description: 'd',
        type: CardType.event,
        rarity: Rarity.common,
        weight: 1,
      );

      final inForest = _buildContext(
        players: [_player],
        cards: [forestCard, universalCard],
        worldState: const WorldState(currentBiomeId: 'forest'),
      );
      final inDesert = _buildContext(
        players: [_player],
        cards: [forestCard, universalCard],
        worldState: const WorldState(currentBiomeId: 'desert'),
      );

      expect(
        inForest.cardCatalog.eligibleCards(inForest).map((c) => c.id),
        containsAll(['forest_only', 'anywhere']),
      );
      expect(inDesert.cardCatalog.eligibleCards(inDesert).map((c) => c.id), [
        'anywhere',
      ]);
    });
  });

  group('GameController biome-gated card choices', () {
    test(
      'a choice gated by an item condition is hidden until the item is held, with a safe fallback shown otherwise',
      () {
        final card = GameCard(
          id: 'gated_choice_card',
          title: 't',
          description: 'd',
          type: CardType.event,
          rarity: Rarity.common,
          weight: 1,
          choices: const [
            CardChoice(
              label: 'only with key',
              conditions: [CurrentPlayerHasItemCondition(itemId: 'itm_key')],
            ),
            CardChoice(label: 'always available'),
          ],
        );

        final controller = GameController(
          playerNames: const ['A', 'B'],
          cards: [card],
          itemCatalog: const ItemCatalog({}),
          effectCatalog: const EffectCatalog({}),
          adventureCatalog: const AdventureCatalog({}),
          biomeCatalog: BiomeCatalog({'forest': _forest}),
          originCatalog: const OriginCatalog({}),
          seed: 1,
          skipPrologue: true,
        );

        controller.takeStep();

        expect(controller.state.pendingCard!.choices.map((c) => c.label), [
          'always available',
        ]);
      },
    );
  });

  group('Bundled biome content', () {
    test('every biome has at least a few cards eligible in it', () async {
      final cards = await const CardRepository().loadCards();
      final biomeCatalog = await const BiomeRepository().loadCatalog();

      for (final biome in biomeCatalog.all) {
        // Tavern is no longer a real `currentBiomeId` destination — it's a
        // flag-gated detour (see alko_quest_tavern_as_detour), so its own
        // content only becomes eligible while `in_tavern` is set, same as
        // `CardTag.prologue` content only becomes eligible during prologue.
        final context = biome.id == 'tavern'
            ? _contextForTavern(cards)
            : _contextFor(cards, biome.id);
        final eligible = context.cardCatalog.eligibleCards(context);
        expect(
          eligible.length,
          greaterThan(3),
          reason: 'biome "${biome.id}" has too little content to feel distinct',
        );
      }
    });

    test(
      'a transition card exists for every biome and never targets itself',
      () async {
        final cards = await const CardRepository().loadCards();
        final biomeCatalog = await const BiomeRepository().loadCatalog();
        final biomeIds = biomeCatalog.all.map((b) => b.id).toSet();

        // Transition cards are gated on NotInBiomeCondition(dest) rather
        // than a fixed source biome, so every biome is reachable directly
        // from every other biome via a single card — there's exactly one
        // arrival card per destination, not one per (source, dest) pair.
        // Prologue "leave the road" cards also carry a SetBiomeAction but
        // are gated on JourneyPhase.prologue instead — there's no "already
        // there" case to exclude during prologue, so they're a different
        // kind of arrival card and sit outside this self-exclusion check
        // (they still count toward "every biome is reachable" below).
        //
        // Tavern is intentionally excluded from `biomeIds` below — it's no
        // longer reached via SetBiomeAction at all (see
        // alko_quest_tavern_as_detour): entering/leaving sets
        // WorldState.flag('in_tavern') instead, and the real biome never
        // actually changes, so there's no "arrival card" for it to check.
        final arrivalCards = cards.where(
          (c) =>
              c.actions.any((a) => a is SetBiomeAction) &&
              !c.hasTag(CardTag.prologue),
        );
        final prologueArrivals = cards.where(
          (c) =>
              c.actions.any((a) => a is SetBiomeAction) &&
              c.hasTag(CardTag.prologue),
        );
        final destinations = <String>{};
        for (final card in arrivalCards) {
          final notIn = card.conditions.whereType<NotInBiomeCondition>();
          final setsTo = card.actions.whereType<SetBiomeAction>().first;
          expect(
            notIn.map((c) => c.biomeId),
            contains(setsTo.biomeId),
            reason:
                'transition card "${card.id}" should exclude its own destination biome via notInBiome',
          );
          destinations.add(setsTo.biomeId);
        }
        for (final card in prologueArrivals) {
          destinations.add(card.actions.whereType<SetBiomeAction>().first.biomeId);
        }

        expect(
          destinations,
          biomeIds.where((id) => id != 'tavern').toSet(),
          reason: 'every real biome should be reachable via some transition card',
        );
      },
    );
  });
}

GameContext _contextFor(List<GameCard> cards, String biomeId) {
  return GameContext(
    state: GameState(
      players: const [_player],
      currentPlayerIndex: 0,
      status: GameStatus.inProgress,
      worldState: WorldState(currentBiomeId: biomeId),
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

GameContext _contextForTavern(List<GameCard> cards) {
  return GameContext(
    state: GameState(
      players: const [_player],
      currentPlayerIndex: 0,
      status: GameStatus.inProgress,
      worldState: const WorldState(flags: {'in_tavern': true}),
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
