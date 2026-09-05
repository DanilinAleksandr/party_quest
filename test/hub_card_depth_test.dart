import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/core/constants/ally_flags.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

/// Which system a condition makes a card react to. Used to measure how many
/// *different* things can change how a card plays out — see «правило
/// узловых карточек».
enum ModifierKind { origin, item, ally, world, effect, stat, ambient }

ModifierKind? _kindOf(GameCondition condition) => switch (condition) {
  CurrentPlayerHasOriginCondition _ ||
  AnyPlayerHasOriginCondition _ ||
  CurrentPlayerLacksOriginCondition _ => ModifierKind.origin,
  CurrentPlayerHasItemCondition _ ||
  PartyHasItemCondition _ ||
  AnyPlayerHasItemCondition _ ||
  CurrentPlayerMissingItemCondition _ ||
  PartyMissingItemCondition _ => ModifierKind.item,
  WorldFlagSetCondition c => allyFlags.containsKey(c.flag)
      ? ModifierKind.ally
      : ModifierKind.world,
  WorldFlagUnsetCondition _ ||
  MinimumStepsSinceFlagCondition _ ||
  AdventureCompletedCondition _ ||
  AdventureNotCompletedCondition _ => ModifierKind.world,
  CurrentPlayerHasEffectCondition _ ||
  AnyPlayerHasEffectCondition _ ||
  CurrentPlayerMissingEffectCondition _ => ModifierKind.effect,
  CurrentPlayerStatAtLeastCondition _ ||
  AnyPlayerStatAtLeastCondition _ => ModifierKind.stat,
  InWeatherCondition _ ||
  NotInWeatherCondition _ ||
  InSeasonCondition _ ||
  NotInSeasonCondition _ => ModifierKind.ambient,
  _ => null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The cards this wave designated as hubs — the ones a party sees most
  /// often, so the ones where sameness hurts most. Listed by id so a later
  /// edit that quietly strips their branches fails here instead of silently
  /// flattening the game's most-drawn moments back to "опять эта карточка".
  const hubCards = {
    'curse_amulet_escape',
    'event_wanderer_riddle',
    'luck_ward_offer',
    'graveyard_epitaph',
  };

  test(
    'every hub card carries at least 4 modifiers across at least 3 systems',
    () async {
      final cards = await const CardRepository().loadCards();

      for (final id in hubCards) {
        final card = cards.firstWhere(
          (c) => c.id == id,
          orElse: () => throw StateError('hub card $id no longer exists'),
        );

        // Counted per distinct *thing* (this origin, that item), not per
        // choice: two choices gated on the same item are one modifier.
        final modifiers = <String>{};
        final kinds = <ModifierKind>{};
        for (final choice in card.choices) {
          for (final condition in choice.conditions) {
            final kind = _kindOf(condition);
            if (kind == null) continue;
            kinds.add(kind);
            modifiers.add('${kind.name}:${condition.toJson()}');
          }
        }

        expect(
          modifiers.length,
          greaterThanOrEqualTo(4),
          reason: '$id has only ${modifiers.length} modifiers',
        );
        expect(
          kinds.length,
          greaterThanOrEqualTo(3),
          reason: '$id draws on only ${kinds.length} systems: $kinds',
        );
      }
    },
  );

  test('every hub card still has a way through for a party with nothing', () async {
    final cards = await const CardRepository().loadCards();

    // The deep branching must never leave an unlucky party staring at a card
    // they cannot resolve. `ContentValidator` enforces this globally, but
    // these four are where the risk is highest, so it is asserted directly.
    for (final id in hubCards) {
      final card = cards.firstWhere((c) => c.id == id);
      expect(
        card.choices.where((c) => c.conditions.isEmpty),
        isNotEmpty,
        reason: '$id has no unconditioned choice',
      );
    }
  });

  test('the paladin order is reachable and leaves a mark on the world', () async {
    final cards = await const CardRepository().loadCards();

    final trigger = cards.firstWhere((c) => c.id == 'road_paladin_outpost');
    expect(
      trigger.actions.whereType<StartAdventureAction>().map((a) => a.adventureId),
      contains('paladin_outpost'),
    );
    // No origin condition on the way in: anyone can meet the order.
    expect(
      trigger.conditions.whereType<CurrentPlayerHasOriginCondition>(),
      isEmpty,
    );

    // The order's standing must be readable by other content, or the whole
    // faction stays a one-off scene.
    int cardsReacting(String flag) => cards
        .where(
          (c) => [
            ...c.conditions,
            for (final choice in c.choices) ...choice.conditions,
          ].whereType<WorldFlagSetCondition>().any((w) => w.flag == flag),
        )
        .length;

    expect(cardsReacting('paladin_ally'), greaterThanOrEqualTo(3));
    expect(cardsReacting('declared_heretic'), greaterThanOrEqualTo(3));
  });
}
