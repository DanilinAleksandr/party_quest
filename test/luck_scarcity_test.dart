import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

/// Conditions that make a branch rare by construction — it only appears for a
/// party that earned it. The same classification `content_health_test` uses
/// for "does this card react to anybody", plus the weather and season gates,
/// which are equally out of the player's hands.
const _gates = {
  'currentPlayerHasOrigin',
  'anyPlayerHasOrigin',
  'currentPlayerLacksOrigin',
  'anyPlayerMissingOrigin',
  'currentPlayerOriginUnknown',
  'currentPlayerHasItem',
  'partyHasItem',
  'anyPlayerHasItem',
  'currentPlayerMissingItem',
  'partyMissingItem',
  'currentPlayerHasEffect',
  'currentPlayerMissingEffect',
  'anyPlayerHasEffect',
  'worldFlagSet',
  'worldFlagUnset',
  'adventureCompleted',
  'adventureNotCompleted',
  'minimumStepsSinceFlag',
  'currentPlayerStatAtLeast',
  'currentPlayerStatAtMost',
  'globalModifierAtLeast',
  'globalModifierAtMost',
  'inWeather',
  'notInWeather',
  'inSeason',
  'minimumTurnsInWeather',
};

GameContext _context({int seed = 1}) => GameContext(
  state: const GameState(
    players: [Player(id: 'p1', name: 'A')],
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

int _luckAfter(List<GameAction> actions, {int seed = 1}) {
  final next = const ActionExecutor().executeAll(actions, _context(seed: seed));
  return next.currentPlayer.stats.valueOf(StatType.luck);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('an action with odds on it', () {
    test('with no chance set, behaves exactly as it always did', () {
      // The null case is the overwhelming majority of actions in the game,
      // so it has to be untouched rather than "1.0 by another name".
      expect(
        _luckAfter(const [ModifyStatAction(stat: StatType.luck, amount: 1)]),
        1,
      );
    });

    test('never fires at 0 and always fires at 1', () {
      // Both are independent of the seed: nextDouble() is [0, 1), so it is
      // never below 0 and always below 1.
      for (var seed = 1; seed <= 20; seed++) {
        expect(
          _luckAfter(const [
            ModifyStatAction(stat: StatType.luck, amount: 1, chance: 0),
          ], seed: seed),
          0,
          reason: 'seed $seed',
        );
        expect(
          _luckAfter(const [
            ModifyStatAction(stat: StatType.luck, amount: 1, chance: 1),
          ], seed: seed),
          1,
          reason: 'seed $seed',
        );
      }
    });

    test('a miss skips that action and nothing else', () {
      // The whole reason this lives on the action rather than the choice: a
      // branch that also hands over an item must still hand it over.
      final next = const ActionExecutor().executeAll(const [
        ModifyStatAction(stat: StatType.luck, amount: 1, chance: 0),
        ModifyStatAction(stat: StatType.charisma, amount: 1),
      ], _context());

      expect(next.currentPlayer.stats.valueOf(StatType.luck), 0);
      expect(next.currentPlayer.stats.valueOf(StatType.charisma), 1);
    });

    test('2% comes up about 2% of the time', () {
      // Seeded, so this is a fixed number rather than a coin toss in CI.
      var context = _context(seed: 7);
      const executor = ActionExecutor();
      const action = ModifyStatAction(
        stat: StatType.luck,
        amount: 1,
        chance: 0.02,
      );
      for (var i = 0; i < 5000; i++) {
        context = executor.execute(action, context);
      }

      final hits = context.currentPlayer.stats.valueOf(StatType.luck);
      expect(hits, greaterThan(50));
      expect(hits, lessThan(150));
    });

    test('chance round-trips through JSON and stays absent when unset', () {
      const chanced = ModifyStatAction(
        stat: StatType.luck,
        amount: 1,
        chance: 0.02,
      );
      final decoded = GameAction.fromJson(chanced.toJson()) as ModifyStatAction;
      expect(decoded.chance, 0.02);

      const plain = ModifyStatAction(stat: StatType.luck, amount: 1);
      expect(plain.toJson().containsKey('chance'), isFalse);
      expect(
        (GameAction.fromJson(plain.toJson()) as ModifyStatAction).chance,
        isNull,
      );
    });
  });

  group('luck in the shipped content', () {
    test('is never handed out freely on an ungated branch', () async {
      // The floor this change establishes, in the shape `content_health_test`
      // already uses: a stat that everything grants and almost nothing takes
      // stops being a stat and becomes a clock. Raise the exception list
      // deliberately; do not grow it to make a red test green.
      const allowed = {'luck_double_or_nothing'};

      final cards = await const CardRepository().loadCards();
      final free = <String>[];

      for (final card in cards) {
        final cardGated = card.conditions.any(
          (c) => _gates.contains(c.toJson()['condition']),
        );
        final branches = <(List<GameCondition>, List<GameAction>)>[
          (const [], card.actions),
          for (final choice in card.choices)
            (choice.conditions, choice.actions),
        ];

        for (final (conditions, actions) in branches) {
          final gated =
              cardGated ||
              conditions.any((c) => _gates.contains(c.toJson()['condition']));
          if (gated) continue;
          for (final action in actions) {
            if (action is ModifyStatAction &&
                action.stat == StatType.luck &&
                action.amount > 0 &&
                action.chance == null) {
              free.add(card.id);
            }
          }
        }
      }

      expect(free.toSet().difference(allowed), isEmpty);
    });

    test('the one exception is the safe half of an explicit gamble', () async {
      // «Синица в руках» is the small, certain side of a double-or-nothing.
      // Take the certainty away and the card stops being a choice.
      final cards = await const CardRepository().loadCards();
      final card = cards.firstWhere((c) => c.id == 'luck_double_or_nothing');
      final safe = card.choices.firstWhere((c) => c.label == 'Синица в руках');

      expect(safe.conditions, isEmpty);
      expect(safe.actions.whereType<ModifyStatAction>().single.chance, isNull);
    });
  });
}
