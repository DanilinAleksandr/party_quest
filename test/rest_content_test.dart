import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/features/game/application/outcome_names.dart';
import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/data/adventure_repository.dart';
import 'package:drinking_quest/game_engine/data/biome_repository.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/data/effect_repository.dart';
import 'package:drinking_quest/game_engine/data/item_repository.dart';
import 'package:drinking_quest/game_engine/data/origin_repository.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

GameCard _rest(String id) => GameCard(
  id: id,
  title: id,
  description: 'd',
  type: CardType.event,
  rarity: Rarity.common,
  weight: 1,
  tags: const [CardTag.rest],
);

GameContext _at(
  List<GameCard> cards, {
  List<String> recentRest = const [],
  Map<String, bool> flags = const {'in_rest': true},
  Map<String, int> setAt = const {},
  int steps = 20,
  String biome = 'forest',
  List<Player> players = const [Player(id: 'p', name: 'A')],
}) => GameContext(
  state: GameState(
    players: players,
    currentPlayerIndex: 0,
    status: GameStatus.inProgress,
    partySteps: steps,
    recentRestCards: recentRest,
    worldState: WorldState(
      flags: flags,
      flagSetAtStep: setAt,
      currentBiomeId: biome,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the halt keeps its own no-repeat window', () {
    final cards = [for (var i = 0; i < 9; i++) _rest('r$i')];

    test('the last $kRestNoRepeatWindow halt cards wait', () {
      final recent = [for (var i = 0; i < kRestNoRepeatWindow; i++) 'r$i'];
      final eligible = CardCatalog(
        cards,
      ).eligibleCards(_at(cards, recentRest: recent)).map((c) => c.id);
      expect(eligible, unorderedEquals(['r6', 'r7', 'r8']));
    });

    test('too few to keep it: the one longest ago comes back', () {
      final few = cards.take(3).toList();
      // r0 was drawn first, so it is the one that may come again.
      final eligible = CardCatalog(few)
          .eligibleCards(_at(few, recentRest: ['r0', 'r1', 'r2']))
          .map((c) => c.id);
      expect(eligible, ['r0']);
    });

    test('the way out is never what keeps the halt going', () {
      final departure = GameCard(
        id: 'out',
        title: 'out',
        description: 'd',
        type: CardType.event,
        rarity: Rarity.common,
        weight: 1,
        tags: const [CardTag.rest],
        actions: const [SetWorldFlagAction(flag: 'in_rest', value: false)],
      );
      expect(departure.isRestContent, isFalse);
      final pool = [_rest('r0'), departure];
      final eligible = CardCatalog(
        pool,
      ).eligibleCards(_at(pool, recentRest: ['r0'])).map((c) => c.id);
      // r0 is in the window, but without it only the way out is left — so
      // the window gives way.
      expect(eligible, containsAll(['r0', 'out']));
    });
  });

  group('the new halt cards', () {
    late List<GameCard> all;
    setUpAll(() async => all = await const CardRepository().loadCards());

    GameCard byId(String id) => all.firstWhere((c) => c.id == id);

    bool eligible(GameCard card, GameContext context) =>
        card.conditions.every((c) => c.isSatisfied(context));

    test('the road echoes need what they echo', () {
      final toast = byId('rest_toast_to_tavern');
      final pie = byId('rest_village_pie');
      expect(eligible(toast, _at(all)), isFalse);
      expect(eligible(pie, _at(all)), isFalse);
      // Left the tavern 10 steps ago, the village 12 — the toast, not the pie.
      final after = _at(
        all,
        flags: const {
          'in_rest': true,
          'left_tavern': true,
          'left_village': true,
        },
        setAt: const {'left_tavern': 10, 'left_village': 8},
      );
      expect(eligible(toast, after), isTrue);
      expect(eligible(pie, after), isFalse);
    });

    test('the firelight needs the thing it lights, and comes once', () {
      for (final (id, item) in [
        ('rest_firelight_odd_stone', 'item_odd_stone'),
        ('rest_firelight_wooden_figurine', 'item_wooden_figurine'),
        ('rest_firelight_forgotten_note', 'item_forgotten_note'),
      ]) {
        final card = byId(id);
        expect(eligible(card, _at(all)), isFalse, reason: id);
        final holder = Player(
          id: 'p',
          name: 'A',
          inventory: [
            InventoryItem(
              id: item,
              name: item,
              description: 'd',
              rarity: Rarity.common,
              usageType: ItemUsageType.manual,
              isConsumable: false,
            ),
          ],
        );
        expect(eligible(card, _at(all, players: [holder])), isTrue, reason: id);
        final seen = _at(
          all,
          players: [holder],
          flags: {'in_rest': true, 'item_glimmer_${id.substring(15)}': true},
        );
        expect(eligible(card, seen), isFalse, reason: id);
      }
    });

    test('a biome halt card is only drawn in its biome', () {
      const own = {
        'rest_forest_eyes': 'forest',
        'rest_mountains_echo': 'mountains',
        'rest_coast_driftwood': 'coast',
        'rest_desert_cold': 'desert',
        'rest_floodlands_bank': 'floodlands',
        'rest_graveyard_keeper': 'graveyard',
      };
      for (final MapEntry(key: id, value: home) in own.entries) {
        for (final biome in own.values) {
          expect(
            eligible(byId(id), _at(all, biome: biome)),
            biome == home,
            reason: '$id in $biome',
          );
        }
      }
      // And the water run is not made in the desert.
      expect(
        eligible(byId('rest_water_run'), _at(all, biome: 'desert')),
        isFalse,
      );
    });
  });

  test('the youngest companion is the one sent for water', () {
    final state = GameState(
      players: const [
        Player(id: 'a', name: 'Аня', age: 22),
        Player(id: 'b', name: 'Боря', age: 31),
        Player(id: 'c', name: 'Вика', age: 25),
      ],
      currentPlayerIndex: 0,
      status: GameStatus.inProgress,
    );
    // Аня is youngest but it is her turn: she sends the next youngest.
    expect(fillOutcomeNames('{youngest} уходит', state), 'Вика уходит');
  });

  test('in play: by card 100 the commonest halt card comes at most twice '
      'in 90% of matches', () async {
    final cards = await const CardRepository().loadCards();
    final items = await const ItemRepository().loadCatalog();
    final effects = await const EffectRepository().loadCatalog();
    final adventures = await const AdventureRepository().loadCatalog();
    final biomes = await const BiomeRepository().loadCatalog();
    final origins = await const OriginRepository().loadCatalog();
    const seeds = 300;
    var atMostTwice = 0;
    for (var seed = 0; seed < seeds; seed++) {
      final pick = Random(seed);
      final c = GameController(
        playerNames: const ['A', 'B', 'C', 'D'],
        cards: cards,
        itemCatalog: items,
        effectCatalog: effects,
        adventureCatalog: adventures,
        biomeCatalog: biomes,
        originCatalog: origins,
        seed: seed,
        journeySteps: null,
      );
      final seen = <String, int>{};
      for (var drawn = 0, guard = 0; drawn < 100 && guard < 400; guard++) {
        c.takeStep();
        if (c.state.pendingParticipantSelection != null) {
          c.resolveParticipant(c.state.players.first.id);
        }
        final card = c.state.pendingCard;
        if (card == null) continue;
        drawn++;
        if (card.isRestContent) seen[card.id] = (seen[card.id] ?? 0) + 1;
        final n = card.choices.length;
        c.resolveCard(choiceIndex: n > 0 ? pick.nextInt(n) : null);
        for (var k = 0; c.state.pendingAdventureNode != null && k < 30; k++) {
          final m = c.state.pendingAdventureNode!.choices.length;
          c.resolveAdventureChoice(m == 0 ? 0 : pick.nextInt(m));
        }
        if (c.state.status != GameStatus.inProgress) break;
      }
      if (seen.values.fold(0, max) <= 2) atMostTwice++;
    }
    expect(atMostTwice / seeds, greaterThanOrEqualTo(0.9));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
