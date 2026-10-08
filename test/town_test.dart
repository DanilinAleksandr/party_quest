import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/data/adventure_repository.dart';
import 'package:drinking_quest/game_engine/data/biome_repository.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/data/effect_repository.dart';
import 'package:drinking_quest/game_engine/data/item_repository.dart';
import 'package:drinking_quest/game_engine/data/origin_repository.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

GameCard _card(String id, List<CardTag> tags) => GameCard(
  id: id,
  title: id,
  description: 'd',
  type: CardType.event,
  rarity: Rarity.common,
  weight: 1,
  tags: tags,
);

GameContext _at(
  List<GameCard> cards, {
  Map<String, bool> flags = const {},
  JourneyPhase phase = JourneyPhase.journey,
  String biome = 'forest',
}) => GameContext(
  state: GameState(
    players: const [Player(id: 'p', name: 'A')],
    currentPlayerIndex: 0,
    status: GameStatus.inProgress,
    partySteps: 3,
    phase: phase,
    worldState: WorldState(flags: flags, currentBiomeId: biome),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a town card is drawn nowhere while there is no town', () {
    final cards = [
      _card('market', const [CardTag.town]),
      _card('market_square', const [CardTag.town, CardTag.village]),
      _card('town_tavern', const [CardTag.town, CardTag.tavern]),
      _card('town_prologue', const [CardTag.town, CardTag.prologue]),
      _card('road', const []),
      _card('village', const [CardTag.village]),
      _card('tavern', const [CardTag.tavern]),
      _card('prologue', const [CardTag.prologue]),
    ];
    for (final (flags, phase) in [
      (const <String, bool>{}, JourneyPhase.journey),
      (const {'in_village': true}, JourneyPhase.journey),
      (const {'in_tavern': true}, JourneyPhase.journey),
      (const <String, bool>{}, JourneyPhase.prologue),
    ]) {
      final eligible = CardCatalog(
        cards,
      ).eligibleCards(_at(cards, flags: flags, phase: phase));
      expect(eligible, isNotEmpty, reason: '$flags $phase');
      expect(
        eligible.where((c) => c.hasTag(CardTag.town)),
        isEmpty,
        reason: '$flags $phase',
      );
    }
  });

  test('the town content is tagged, all of it', () async {
    final cards = await const CardRepository().loadCards();
    final town = cards.where((c) => c.hasTag(CardTag.town)).toList();
    // The whole of life_town.json and the paver.
    expect(town.length, greaterThanOrEqualTo(14));
    for (final id in ['town_market_closing', 'town_dyer_hands']) {
      expect(town.map((c) => c.id), contains(id));
    }
  });

  test(
    'in play: no town card turns up, in any biome',
    () async {
      final cards = await const CardRepository().loadCards();
      final items = await const ItemRepository().loadCatalog();
      final effects = await const EffectRepository().loadCatalog();
      final adventures = await const AdventureRepository().loadCatalog();
      final biomes = await const BiomeRepository().loadCatalog();
      final origins = await const OriginRepository().loadCatalog();
      final seen = <String>{};
      for (var seed = 0; seed < 80; seed++) {
        final pick = Random(seed);
        final c = GameController(
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
        for (var drawn = 0, guard = 0; drawn < 150 && guard < 600; guard++) {
          c.takeStep();
          if (c.state.pendingParticipantSelection != null) {
            c.resolveParticipant(c.state.players.first.id);
          }
          final card = c.state.pendingCard;
          if (card == null) continue;
          drawn++;
          seen.add(c.state.worldState.currentBiomeId);
          expect(card.hasTag(CardTag.town), isFalse, reason: card.id);
          final n = card.choices.length;
          c.resolveCard(choiceIndex: n > 0 ? pick.nextInt(n) : null);
          for (var k = 0; c.state.pendingAdventureNode != null && k < 30; k++) {
            final m = c.state.pendingAdventureNode!.choices.length;
            c.resolveAdventureChoice(m == 0 ? 0 : pick.nextInt(m));
          }
          if (c.state.status != GameStatus.inProgress) break;
        }
      }
      expect(seen, containsAll(['forest', 'desert', 'floodlands']));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
