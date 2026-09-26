import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/game_engine/data/adventure_repository.dart';
import 'package:drinking_quest/game_engine/data/biome_repository.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/data/effect_repository.dart';
import 'package:drinking_quest/game_engine/data/item_repository.dart';
import 'package:drinking_quest/game_engine/data/origin_repository.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<GameCard> cards;
  setUpAll(() async {
    cards = await const CardRepository().loadCards();
  });

  test('every prologue_* card is gated to the prologue', () {
    // The `prologue` tag lets a card *into* the prologue; only the phase
    // condition keeps it out afterwards. The neutral road cards carry the
    // tag on purpose and are allowed both sides, so the id is the test.
    final ungated = [
      for (final card in cards)
        if (card.id.startsWith('prologue_') &&
            !card.conditions.any(
              (c) => c is InPhaseCondition && c.phase == JourneyPhase.prologue,
            ))
          card.id,
    ];
    expect(ungated, isEmpty);
  });

  test('every tavern card is gated to the tavern', () {
    final ungated = [
      for (final card in cards)
        if (card.hasTag(CardTag.tavern) &&
            !card.conditions.any(
              (c) => c is WorldFlagSetCondition && c.flag == 'in_tavern',
            ))
          card.id,
    ];
    expect(ungated, isEmpty);
  });

  test('no prologue_* card is drawn once the prologue is over', () async {
    final items = await const ItemRepository().loadCatalog();
    final effects = await const EffectRepository().loadCatalog();
    final adventures = await const AdventureRepository().loadCatalog();
    final biomes = await const BiomeRepository().loadCatalog();
    final origins = await const OriginRepository().loadCatalog();

    for (var seed = 0; seed < 12; seed++) {
      final controller = GameController(
        playerNames: const ['A', 'B', 'C'],
        cards: cards,
        itemCatalog: items,
        effectCatalog: effects,
        adventureCatalog: adventures,
        biomeCatalog: biomes,
        originCatalog: origins,
        seed: seed,
        journeySteps: null,
      );
      var draws = 0;
      while (controller.state.partySteps < 40 && draws++ < 200) {
        controller.takeStep();
        if (controller.state.pendingParticipantSelection != null) {
          controller.resolveParticipant(controller.state.players.first.id);
        }
        final card = controller.state.pendingCard;
        if (card == null) continue;
        if (controller.state.phase == JourneyPhase.journey) {
          expect(
            card.id,
            isNot(startsWith('prologue_')),
            reason: 'seed $seed, step ${controller.state.partySteps}',
          );
        }
        controller.resolveCard(choiceIndex: card.hasChoices ? 0 : null);
        for (
          var guard = 0;
          controller.state.pendingAdventureNode != null && guard < 30;
          guard++
        ) {
          controller.resolveAdventureChoice(0);
        }
      }
      expect(controller.state.partySteps, greaterThanOrEqualTo(30));
    }
  });
}
