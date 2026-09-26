import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

GameContext _at({
  required int steps,
  required List<GameCard> cards,
  WorldState worldState = const WorldState(),
}) => GameContext(
  state: GameState(
    players: const [
      Player(id: 'p1', name: 'A'),
      Player(id: 'p2', name: 'B'),
    ],
    currentPlayerIndex: 0,
    status: GameStatus.inProgress,
    partySteps: steps,
    phase: JourneyPhase.journey,
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

/// The world after a halt the party got up from at step [leftAt].
WorldState _afterHalt({required int leftAt}) => WorldState(
  flags: const {'left_rest': true},
  flagSetAtStep: {'left_rest': leftAt},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MaximumStepsSinceFlagCondition', () {
    const condition = MaximumStepsSinceFlagCondition(flag: 'x', steps: 3);

    test('false when the flag was never set', () {
      expect(condition.isSatisfied(_at(steps: 5, cards: const [])), isFalse);
    });

    test('true inside the window, false once it has passed', () {
      const executor = ActionExecutor();
      var context = _at(steps: 10, cards: const []);
      context = executor.execute(const SetWorldFlagAction(flag: 'x'), context);

      for (final (steps, open) in [
        (10, true),
        (11, true),
        (13, true),
        (14, false),
      ]) {
        final at = context.withState(context.state.copyWith(partySteps: steps));
        expect(condition.isSatisfied(at), open, reason: 'step $steps');
      }
    });

    test('false again once the flag is unset', () {
      const executor = ActionExecutor();
      var context = _at(steps: 10, cards: const []);
      context = executor.execute(const SetWorldFlagAction(flag: 'x'), context);
      context = executor.execute(
        const SetWorldFlagAction(flag: 'x', value: false),
        context,
      );
      expect(condition.isSatisfied(context), isFalse);
    });

    test('survives JSON', () {
      final back = GameCondition.fromJson(condition.toJson());
      expect(back, isA<MaximumStepsSinceFlagCondition>());
      back as MaximumStepsSinceFlagCondition;
      expect((back.flag, back.steps), ('x', 3));
    });
  });

  group('the rest echo in the shipped pack', () {
    late List<GameCard> cards;
    late GameCard echo;
    late GameCard road;

    setUpAll(() async {
      cards = await const CardRepository().loadCards();
      echo = cards.singleWhere((c) => c.id == 'curse_whisper');
      road = cards.singleWhere((c) => c.id == 'curse_whisper_road');
    });

    bool eligible(GameCard card, GameContext context) =>
        card.conditions.every((c) => c.isSatisfied(context));

    test('never comes before the party has sat at a fire', () {
      for (var step = 1; step <= 30; step++) {
        expect(eligible(echo, _at(steps: step, cards: cards)), isFalse);
      }
    });

    test('comes in the first three steps after one, and not after', () {
      for (final (since, open) in [
        (1, true),
        (2, true),
        (3, true),
        (4, false),
      ]) {
        final context = _at(
          steps: 10 + since,
          cards: cards,
          worldState: _afterHalt(leftAt: 10),
        );
        expect(eligible(echo, context), open, reason: '$since after');
      }
    });

    test('closes its window behind it, so a halt echoes once', () {
      expect(
        echo.actions.whereType<SetWorldFlagAction>().any(
          (a) => a.flag == 'left_rest' && !a.value,
        ),
        isTrue,
      );
    });

    test('outweighs the road inside the window, by a long way', () {
      expect(echo.weight, greaterThanOrEqualTo(road.weight * 50));
    });

    test('the road version keeps the old weight and never mentions a fire', () {
      expect(road.weight, 2);
      expect(road.conditions, isEmpty);
      expect(road.description, isNot(contains('привал')));
      expect(echo.description, contains('привале'));
    });

    test('«Сборы» is what opens the window', () {
      final departure = cards.singleWhere((c) => c.id == 'rest_departure');
      expect(
        departure.actions.whereType<SetWorldFlagAction>().any(
          (a) => a.flag == 'left_rest' && a.value,
        ),
        isTrue,
      );
    });
  });
}
