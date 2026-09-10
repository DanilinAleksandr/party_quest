import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

GameCard _card(
  String id, {
  List<CardTag> tags = const [],
  List<GameCondition> conditions = const [],
  List<GameAction> actions = const [],
  int weight = 1,
}) => GameCard(
  id: id,
  title: 't',
  description: 'd',
  type: CardType.event,
  rarity: Rarity.common,
  weight: weight,
  tags: tags,
  conditions: conditions,
  actions: actions,
);

final _arrival = _card(
  'rest_arrival',
  actions: const [SetWorldFlagAction(flag: 'in_rest', value: true)],
);
final _content = _card('rest_content', tags: const [CardTag.rest]);
final _departure = _card(
  'rest_departure',
  tags: const [CardTag.rest],
  conditions: const [
    WorldFlagSetCondition(flag: 'in_rest'),
    MinimumTurnsInRestCondition(turns: 1),
  ],
  actions: const [SetWorldFlagAction(flag: 'in_rest', value: false)],
);
final _road = _card('road');
final _prologue = _card('prologue', tags: const [CardTag.prologue]);
final _tavern = _card('tavern', tags: const [CardTag.tavern]);

GameContext _at({
  required int steps,
  required List<GameCard> cards,
  JourneyPhase phase = JourneyPhase.journey,
  bool inTavern = false,
  bool inRest = false,
  int turnsInRest = 0,
}) => GameContext(
  state: GameState(
    players: const [
      Player(id: 'p1', name: 'A'),
      Player(id: 'p2', name: 'B'),
    ],
    currentPlayerIndex: 0,
    status: GameStatus.inProgress,
    partySteps: steps,
    phase: phase,
    worldState: WorldState(
      flags: {if (inTavern) 'in_tavern': true, if (inRest) 'in_rest': true},
      turnsInRest: turnsInRest,
    ),
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

GameController _controller(List<GameCard> cards) => GameController(
  playerNames: const ['A', 'B'],
  cards: cards,
  itemCatalog: const ItemCatalog({}),
  effectCatalog: const EffectCatalog({}),
  adventureCatalog: const AdventureCatalog({}),
  biomeCatalog: const BiomeCatalog({}),
  originCatalog: const OriginCatalog({}),
  seed: 3,
  // Infinite, so ten steps cannot end the journey out from under the test.
  journeySteps: null,
  skipPrologue: true,
);

/// One full step: draw and resolve whatever came up.
void _step(GameController controller) {
  controller.takeStep();
  if (controller.state.pendingCard != null) controller.resolveCard();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final all = [_arrival, _content, _departure, _road, _prologue, _tavern];

  group('the halt falls due', () {
    test(
      'on every ${kRestInterval}th step, and only arrivals are drawable',
      () {
        for (final step in [
          kRestInterval,
          kRestInterval * 2,
          kRestInterval * 9,
        ]) {
          final pool = CardCatalog(
            all,
          ).eligibleCards(_at(steps: step, cards: all));
          expect(pool.map((c) => c.id), ['rest_arrival'], reason: 'step $step');
        }
      },
    );

    test('not on any other step, and rest content stays off the road', () {
      for (var step = 0; step <= kRestInterval * 3; step++) {
        if (step > 0 && step % kRestInterval == 0) continue;
        final ids = CardCatalog(
          all,
        ).eligibleCards(_at(steps: step, cards: all)).map((c) => c.id);
        expect(ids, contains('road'), reason: 'step $step');
        // Neither the halt's content nor the card that would start one: an
        // arrival carries no conditions, so only the schedule keeps the
        // party from pitching camp whenever the weighting felt like it.
        expect(ids, isNot(contains('rest_arrival')), reason: 'step $step');
        expect(ids, isNot(contains('rest_content')), reason: 'step $step');
        expect(ids, isNot(contains('rest_departure')), reason: 'step $step');
      }
    });

    test('not while the party is already resting', () {
      // Otherwise the tenth step inside a long halt would start a second one.
      final pool = CardCatalog(all).eligibleCards(
        _at(steps: kRestInterval, cards: all, inRest: true, turnsInRest: 3),
      );
      expect(pool.map((c) => c.id), isNot(contains('rest_arrival')));
    });

    test('not inside the prologue or a tavern', () {
      expect(
        CardCatalog(all)
            .eligibleCards(
              _at(
                steps: kRestInterval,
                cards: all,
                phase: JourneyPhase.prologue,
              ),
            )
            .map((c) => c.id),
        ['prologue'],
      );
      expect(
        CardCatalog(all)
            .eligibleCards(
              _at(steps: kRestInterval, cards: all, inTavern: true),
            )
            .map((c) => c.id),
        ['tavern'],
      );
    });

    test('and falls back to the road when nothing can begin a halt', () {
      // A card set with no arrival card would otherwise hit an empty pool on
      // its tenth step and take the step down with it.
      final noArrival = [_road, _content];
      final pool = CardCatalog(
        noArrival,
      ).eligibleCards(_at(steps: kRestInterval, cards: noArrival));
      expect(pool.map((c) => c.id), ['road']);
    });
  });

  group('inside the halt', () {
    test('only rest content is eligible', () {
      final pool = CardCatalog(
        all,
      ).eligibleCards(_at(steps: 11, cards: all, inRest: true, turnsInRest: 1));
      expect(
        pool.map((c) => c.id),
        containsAll(['rest_content', 'rest_departure']),
      );
      expect(pool.map((c) => c.id), isNot(contains('road')));
      expect(pool.map((c) => c.id), isNot(contains('rest_arrival')));
    });

    test('the way out waits for at least one card at the fire', () {
      final pool = CardCatalog(
        all,
      ).eligibleCards(_at(steps: 11, cards: all, inRest: true));
      expect(pool.map((c) => c.id), ['rest_content']);
    });
  });

  group('a halt end to end', () {
    // Only one rest card besides the arrival, so every draw below is forced
    // and the step counter is the only thing under test.
    List<GameCard> fixture() => [_road, _arrival, _departure];

    test('costs the party no journey length, and gives it back after', () {
      final controller = _controller(fixture());

      for (var i = 0; i < kRestInterval; i++) {
        _step(controller);
      }
      expect(controller.state.partySteps, kRestInterval);
      expect(controller.state.worldState.flag('in_rest'), isTrue);

      // The step inside the halt: the counter is frozen, exactly as it is
      // inside a tavern — an evening at the fire does not shorten the road.
      _step(controller);
      expect(controller.state.partySteps, kRestInterval);
      expect(controller.state.worldState.flag('in_rest'), isFalse);

      // And the moment it is over, the road resumes.
      _step(controller);
      expect(controller.state.partySteps, kRestInterval + 1);
    });

    test('leaves turnsInRest at zero once it is over', () {
      final controller = _controller(fixture());
      for (var i = 0; i < kRestInterval + 2; i++) {
        _step(controller);
      }
      expect(controller.state.worldState.flag('in_rest'), isFalse);
      expect(controller.state.worldState.turnsInRest, 0);
    });
  });

  group('the shipped pack', () {
    test('has an arrival, a departure, and content between them', () async {
      final cards = await const CardRepository().loadCards();

      final arrivals = cards.where((c) => c.beginsRest).toList();
      expect(arrivals, isNotEmpty);
      expect(arrivals.every((c) => !c.hasTag(CardTag.rest)), isTrue);

      final inside = cards.where((c) => c.hasTag(CardTag.rest)).toList();
      final departures = inside.where(
        (c) => c.actions.any(
          (a) => a is SetWorldFlagAction && a.flag == 'in_rest' && !a.value,
        ),
      );
      expect(departures, isNotEmpty);
      expect(inside.length - departures.length, 8);
    });

    test('always has something to draw at the fire', () async {
      // An empty pool inside the halt is a crash, not a quiet miss: the pack
      // has to hold content that needs no condition to appear.
      final cards = await const CardRepository().loadCards();
      final unconditional = cards.where(
        (c) => c.hasTag(CardTag.rest) && c.conditions.isEmpty,
      );
      expect(unconditional, isNotEmpty);
    });
  });
}
