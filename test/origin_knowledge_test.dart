import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/game_engine/data/adventure_repository.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

/// Guards the design doc's «правило знания»: an origin may shorten the road
/// to a story, but must never be the only road to it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Adventure ids a card can start, split by whether reaching them depends
  /// on who the player turned out to be.
  ({Set<String> viaOrigin, Set<String> viaAnyone}) adventureRoutes(
    List<GameCard> cards,
  ) {
    final viaOrigin = <String>{};
    final viaAnyone = <String>{};

    bool isOriginGated(List<GameCondition> conditions) => conditions.any(
      (c) =>
          c is CurrentPlayerHasOriginCondition || c is AnyPlayerHasOriginCondition,
    );

    Iterable<String> startedBy(List<GameAction> actions) => actions
        .whereType<StartAdventureAction>()
        .map((a) => a.adventureId);

    for (final card in cards) {
      // A card-level grant is reachable by whoever draws the card.
      final cardGated = isOriginGated(card.conditions);
      for (final id in startedBy(card.actions)) {
        (cardGated ? viaOrigin : viaAnyone).add(id);
      }
      for (final choice in card.choices) {
        final gated = cardGated || isOriginGated(choice.conditions);
        for (final id in startedBy(choice.actions)) {
          (gated ? viaOrigin : viaAnyone).add(id);
        }
      }
    }
    return (viaOrigin: viaOrigin, viaAnyone: viaAnyone);
  }

  /// Adventures that legitimately belong to one origin, because they are
  /// *about* that origin rather than about the world: the innkeeper spots
  /// one of his own and tests how deep it runs. A stranger in that scene
  /// would make no sense, so it isn't content being locked away — see the
  /// carve-out in «правило знания».
  ///
  /// Named one by one on purpose: a new entry here has to be a decision,
  /// not something that quietly slips past because it happened to be
  /// origin-gated.
  const personalOriginStories = {'drunkard_temptation'};

  test(
    'every adventure a knowledge shortcut leads to is also reachable without '
    'any origin — knowledge shortens the road, it never owns it',
    () async {
      final cards = await const CardRepository().loadCards();
      final routes = adventureRoutes(cards);

      final ownedByOrigin = routes.viaOrigin
          .difference(routes.viaAnyone)
          .difference(personalOriginStories);
      expect(
        ownedByOrigin,
        isEmpty,
        reason:
            'these adventures can only be entered by a specific origin: '
            '$ownedByOrigin',
      );
    },
  );

  test('a knowledge shortcut never pays out in items or stats', () async {
    final cards = await const CardRepository().loadCards();

    // The knowledge reactions authored so far, by the card they live on.
    // Listed explicitly rather than detected: an origin-gated choice that
    // grants an item is perfectly legitimate in general (see the wolf-blood
    // and drunkard reactions) — the rule applies to choices whose whole
    // point is that the character already knows something.
    const knowledgeChoices = {
      'road_tracks': 'Прочитать след',
      'road_landmark': 'Это дым, а не башня',
      'desert_mirage': 'Это не вода',
      'mountains_dragon_tracks': 'Такое здесь видели',
      'forest_ancient_tree': 'На коре вырезан знак',
      'coast_smugglers': 'Груз чужой',
    };

    for (final entry in knowledgeChoices.entries) {
      final card = cards.firstWhere((c) => c.id == entry.key);
      final choice = card.choices.firstWhere(
        (c) => c.label.startsWith(entry.value),
        orElse: () => throw StateError(
          'knowledge choice "${entry.value}" is gone from ${entry.key}',
        ),
      );

      expect(
        choice.actions.whereType<GiveItemAction>(),
        isEmpty,
        reason: '${entry.key}: knowledge must not be paid out as an item',
      );
      expect(
        choice.actions.whereType<ModifyStatAction>(),
        isEmpty,
        reason: '${entry.key}: knowledge must not be paid out as a stat',
      );
    }
  });

  test('the dragon-chain shortcut lands on a real stage, not past the end', () async {
    final cards = await const CardRepository().loadCards();
    final tracks = cards.firstWhere((c) => c.id == 'mountains_dragon_tracks');
    final shortcut = tracks.choices.firstWhere(
      (c) => c.conditions.whereType<CurrentPlayerHasOriginCondition>().isNotEmpty,
    );

    final setFlags = shortcut.actions
        .whereType<SetWorldFlagAction>()
        .where((a) => a.value)
        .map((a) => a.flag)
        .toSet();

    // It must skip stages, not the whole story: the flags it sets are
    // exactly the ones that let the burned-village card in, and it must
    // stop short of the lair itself.
    expect(setFlags, contains('dragon_trail_rumors'));
    expect(setFlags, isNot(contains('dragon_lair_known')));

    // And the stage it hands off to must still exist and still be gated on
    // the flag the shortcut set — otherwise the shortcut leads nowhere.
    final village = cards.firstWhere((c) => c.id == 'mountains_dragon_village');
    expect(
      village.conditions.whereType<WorldFlagSetCondition>().map((c) => c.flag),
      contains('dragon_trail_rumors'),
    );
  });

  test('every adventure a card starts actually exists', () async {
    final cards = await const CardRepository().loadCards();
    final adventures = await const AdventureRepository().loadCatalog();
    final routes = adventureRoutes(cards);

    for (final id in {...routes.viaOrigin, ...routes.viaAnyone}) {
      expect(adventures.contains(id), isTrue, reason: 'unknown adventure: $id');
    }
  });
}
