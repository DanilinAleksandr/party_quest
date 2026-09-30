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

const _biomesWithVillages = [
  'forest',
  'mountains',
  'coast',
  'desert',
  'floodlands',
];

bool _enters(GameCard c) => c.actions.any(
  (a) => a is SetWorldFlagAction && a.flag == 'in_village' && a.value,
);

bool _beginsDetour(GameCard c) => c.actions.any(
  (a) =>
      a is SetWorldFlagAction &&
      (a.flag == 'in_rest' || a.flag == 'in_tavern') &&
      a.value,
);

GameCard _card(
  String id, {
  List<CardTag> tags = const [],
  List<GameCondition> conditions = const [],
  List<GameAction> actions = const [],
}) => GameCard(
  id: id,
  title: id,
  description: 'd',
  type: CardType.event,
  rarity: Rarity.common,
  weight: 1,
  tags: tags,
  conditions: conditions,
  actions: actions,
);

GameContext _context(
  List<GameCard> cards, {
  Map<String, bool> flags = const {},
  int steps = 20,
  int turnsInVillage = 0,
  int turnsInBiome = 10,
  String biome = 'forest',
}) => GameContext(
  state: GameState(
    players: const [Player(id: 'p', name: 'A')],
    currentPlayerIndex: 0,
    status: GameStatus.inProgress,
    partySteps: steps,
    worldState: WorldState(
      flags: flags,
      currentBiomeId: biome,
      turnsInVillage: turnsInVillage,
      turnsInCurrentBiome: turnsInBiome,
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

  group('the draw', () {
    final road = _card('road');
    final lane = _card('lane', tags: const [CardTag.village]);
    final out = _card(
      'out',
      tags: const [CardTag.village],
      actions: const [SetWorldFlagAction(flag: 'in_village', value: false)],
    );
    // The way to a halt, like the game's own: no rest tag — that marks what
    // happens at the fire, not the arriving.
    final halt = _card(
      'halt',
      actions: const [SetWorldFlagAction(flag: 'in_rest', value: true)],
    );
    final all = [road, lane, out, halt];

    test('keeps village content off the road, and only it in a village', () {
      final onRoad = CardCatalog(all).eligibleCards(_context(all, steps: 3));
      expect(onRoad.map((c) => c.id), ['road']);
      final inVillage = CardCatalog(all).eligibleCards(
        _context(all, steps: 3, flags: const {'in_village': true}),
      );
      expect(inVillage.map((c) => c.id), containsAll(['lane', 'out']));
      expect(inVillage.map((c) => c.id), isNot(contains('road')));
    });

    test('lets a village have seven cards at most, then only the way out', () {
      final at7 = CardCatalog(all).eligibleCards(
        _context(
          all,
          steps: 3,
          flags: const {'in_village': true},
          turnsInVillage: 7,
        ),
      );
      expect(at7.map((c) => c.id), containsAll(['lane', 'out']));
      final at8 = CardCatalog(all).eligibleCards(
        _context(
          all,
          steps: 3,
          flags: const {'in_village': true},
          turnsInVillage: 8,
        ),
      );
      expect(at8.map((c) => c.id), ['out']);
    });

    test('begins no halt in a village', () {
      final due = CardCatalog(all).eligibleCards(
        _context(all, steps: 10, flags: const {'in_village': true}),
      );
      expect(due.map((c) => c.id), isNot(contains('halt')));
      // And the halt's own step is the halt's: no village begins on it.
      final onRoad = CardCatalog(all).eligibleCards(_context(all, steps: 10));
      expect(onRoad.map((c) => c.id), ['halt']);
    });

    test('a spacing holds before the flag was ever set, and after', () {
      const spaced = FlagNotSetWithinStepsCondition(
        flag: 'left_village',
        steps: 12,
      );
      final never = _context(const []);
      expect(spaced.isSatisfied(never), isTrue);
      GameContext leftAt(int at, int now) =>
          _context(
            const [],
            steps: now,
            flags: const {'left_village': true},
          ).withState(
            _context(const [], steps: now).state.copyWith(
              worldState: const WorldState(
                flags: {'left_village': true},
              ).copyWith(flagSetAtStep: {'left_village': at}),
            ),
          );
      expect(spaced.isSatisfied(leftAt(10, 21)), isFalse);
      expect(spaced.isSatisfied(leftAt(10, 22)), isTrue);
      expect(GameCondition.fromJson(spaced.toJson()).toJson(), spaced.toJson());
    });
  });

  group('the content', () {
    late List<GameCard> cards;
    setUpAll(() async => cards = await const CardRepository().loadCards());

    test('has a way in for each biome with villages, and none elsewhere', () {
      final ways = cards.where(_enters).toList();
      final biomes = <String>{
        for (final c in ways)
          for (final cond in c.conditions)
            if (cond is InBiomeCondition) cond.biomeId,
      };
      expect(biomes, _biomesWithVillages.toSet());
      for (final c in ways) {
        final conds = c.conditions;
        expect(conds.whereType<InBiomeCondition>(), hasLength(1), reason: c.id);
        expect(
          conds.whereType<FlagNotSetWithinStepsCondition>().single.steps,
          12,
          reason: c.id,
        );
        expect(
          conds.whereType<MinimumTurnsInBiomeCondition>().single.turns,
          3,
          reason: c.id,
        );
        expect(c.hasTag(CardTag.village), isFalse, reason: c.id);
        expect(c.hasChoices, isFalse, reason: c.id);
      }
    });

    test('leaves out a village with a way home', () {
      final exits = cards.where((c) => c.endsVillage).toList();
      expect(exits, hasLength(2));
      for (final c in exits) {
        expect(c.hasTag(CardTag.village), isTrue);
        expect(
          c.actions.any(
            (a) => a is SetWorldFlagAction && a.flag == 'left_village',
          ),
          isTrue,
        );
      }
    });

    test('offers at least ten village cards in every biome', () {
      for (final biome in _biomesWithVillages) {
        final context = _context(
          cards,
          biome: biome,
          flags: const {'in_village': true},
          turnsInVillage: 1,
          steps: 30,
        );
        final content = CardCatalog(
          cards,
        ).eligibleCards(context).where((c) => !c.endsVillage).toList();
        expect(content.length, greaterThanOrEqualTo(10), reason: biome);
      }
    });
  });

  test('in play: 3–7 cards a village, never in the graveyard, spaced, and '
      'the road standing still', () async {
    final cards = await const CardRepository().loadCards();
    final items = await const ItemRepository().loadCatalog();
    final effects = await const EffectRepository().loadCatalog();
    final adventures = await const AdventureRepository().loadCatalog();
    final biomes = await const BiomeRepository().loadCatalog();
    final origins = await const OriginRepository().loadCatalog();

    var visits = 0;
    for (var seed = 0; seed < 150; seed++) {
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
      var inside = 0;
      int? steps;
      int? leftAt;
      for (var drawn = 0, guard = 0; drawn < 120 && guard < 500; guard++) {
        c.takeStep();
        if (c.state.pendingParticipantSelection != null) {
          c.resolveParticipant(c.state.players.first.id);
        }
        final card = c.state.pendingCard;
        if (card == null) continue;
        drawn++;
        final world = c.state.worldState;
        final inVillage = world.flag('in_village');
        final why = 'seed $seed, ${card.id}';
        expect(card.hasTag(CardTag.village), inVillage, reason: why);
        if (inVillage) {
          expect(_beginsDetour(card), isFalse, reason: why);
          expect(c.state.partySteps, steps, reason: why);
          if (!card.endsVillage) inside++;
        }
        if (_enters(card)) {
          expect(world.currentBiomeId, isNot('graveyard'), reason: why);
          if (leftAt != null) {
            expect(
              c.state.partySteps - leftAt,
              greaterThanOrEqualTo(12),
              reason: why,
            );
          }
        }
        final n = card.choices.length;
        c.resolveCard(choiceIndex: n > 0 ? pick.nextInt(n) : null);
        for (var k = 0; c.state.pendingAdventureNode != null && k < 30; k++) {
          final m = c.state.pendingAdventureNode!.choices.length;
          c.resolveAdventureChoice(m == 0 ? 0 : pick.nextInt(m));
        }
        if (_enters(card)) {
          steps = c.state.partySteps;
          inside = 0;
          visits++;
        }
        if (inVillage && !c.state.worldState.flag('in_village')) {
          expect(inside, inInclusiveRange(3, 7), reason: why);
          leftAt = c.state.partySteps;
        }
        if (c.state.status != GameStatus.inProgress) break;
      }
    }
    expect(visits, greaterThan(150));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
