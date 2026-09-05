import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/core/constants/ally_flags.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

/// The automatic half of `tool/content_health.py`.
///
/// The script is for reading — histograms, faction tables, origin paths. This
/// is the part that has to fail on its own when content drifts, so a wave
/// that quietly flattens the game gets caught by `flutter test` rather than
/// by somebody remembering to run the report.
///
/// Thresholds are floors, not targets: they encode "не хуже, чем сейчас",
/// and should be raised deliberately when a wave improves them, never
/// lowered to make a red test green.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Measured 2026-07-28: 0 flat, average 4.94, every system in use.
  const maxFlatCards = 0;
  const minAverageModifiers = 4.0;

  /// Which system a condition makes a card react to. `null` means it says
  /// nothing about *this party* — biome, phase, table size — so counting it
  /// would flatter every card equally. The switch is exhaustive over the
  /// sealed hierarchy on purpose: a new condition type must be classified
  /// before this compiles, which is exactly the sync guarantee the Python
  /// report cannot give itself.
  String? systemOf(GameCondition condition) => switch (condition) {
    CurrentPlayerHasOriginCondition _ ||
    AnyPlayerHasOriginCondition _ ||
    CurrentPlayerLacksOriginCondition _ ||
    AnyPlayerMissingOriginCondition _ ||
    CurrentPlayerOriginUnknownCondition _ => 'origin',
    CurrentPlayerHasItemCondition _ ||
    PartyHasItemCondition _ ||
    AnyPlayerHasItemCondition _ ||
    CurrentPlayerMissingItemCondition _ ||
    PartyMissingItemCondition _ => 'item',
    CurrentPlayerHasEffectCondition _ ||
    AnyPlayerHasEffectCondition _ ||
    CurrentPlayerMissingEffectCondition _ => 'effect',
    WorldFlagSetCondition c =>
      allyFlags.containsKey(c.flag) ? 'ally' : 'world',
    WorldFlagUnsetCondition _ ||
    MinimumStepsSinceFlagCondition _ ||
    AdventureCompletedCondition _ ||
    AdventureNotCompletedCondition _ ||
    GlobalModifierAtLeastCondition _ => 'world',
    CurrentPlayerStatAtLeastCondition _ ||
    AnyPlayerStatAtLeastCondition _ => 'stat',
    InWeatherCondition _ ||
    NotInWeatherCondition _ ||
    InSeasonCondition _ ||
    NotInSeasonCondition _ ||
    MinimumTurnsInWeatherCondition _ => 'ambient',
    InBiomeCondition _ ||
    NotInBiomeCondition _ ||
    MinimumTurnsInBiomeCondition _ ||
    MinimumTurnsInTavernCondition _ ||
    MinimumPlayersCondition _ ||
    MaximumPlayersCondition _ ||
    MinimumStepCondition _ ||
    MaximumStepCondition _ ||
    GameModeCondition _ ||
    InPhaseCondition _ ||
    LeaderIsSetCondition _ ||
    LeaderIsUnsetCondition _ => null,
  };

  ({int count, Set<String> systems}) analyse(GameCard card) {
    final modifiers = <String>{};
    final systems = <String>{};
    for (final choice in card.choices) {
      for (final condition in choice.conditions) {
        final system = systemOf(condition);
        if (system == null) continue;
        systems.add(system);
        modifiers.add('$system:${condition.toJson()}');
      }
    }
    return (count: modifiers.length, systems: systems);
  }

  test('no choice card is completely flat', () async {
    final cards = await const CardRepository().loadCards();
    final flat = [
      for (final card in cards)
        if (card.hasChoices && analyse(card).count == 0) card.id,
    ];

    expect(
      flat.length,
      lessThanOrEqualTo(maxFlatCards),
      reason:
          'these cards play out identically for every party: $flat\n'
          'run `python tool/content_health.py` for the full picture',
    );
  });

  test('average modifiers per choice card stays above the floor', () async {
    final cards = await const CardRepository().loadCards();
    final choiceCards = cards.where((c) => c.hasChoices).toList();
    final average =
        choiceCards.fold<int>(0, (sum, c) => sum + analyse(c).count) /
        choiceCards.length;

    expect(
      average,
      greaterThanOrEqualTo(minAverageModifiers),
      reason:
          'average is ${average.toStringAsFixed(2)}, floor is '
          '$minAverageModifiers — content is flattening out',
    );
  });

  test('every system is still present in the content', () async {
    final cards = await const CardRepository().loadCards();
    final usage = <String, int>{};
    for (final card in cards.where((c) => c.hasChoices)) {
      for (final system in analyse(card).systems) {
        usage[system] = (usage[system] ?? 0) + 1;
      }
    }

    // A system that falls out of the content entirely is a design
    // regression, not a style choice — the report warns about thin ones,
    // this fails on empty ones.
    for (final system in ['origin', 'item', 'effect', 'world', 'ally', 'stat',
      'ambient']) {
      expect(
        usage[system] ?? 0,
        greaterThan(0),
        reason: '$system disappeared from the content',
      );
    }
  });
}
