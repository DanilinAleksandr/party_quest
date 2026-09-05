import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/game_engine/data/adventure_repository.dart';
import 'package:drinking_quest/game_engine/data/biome_repository.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/data/content_validator.dart';
import 'package:drinking_quest/game_engine/data/effect_repository.dart';
import 'package:drinking_quest/game_engine/data/item_repository.dart';
import 'package:drinking_quest/game_engine/data/origin_repository.dart';
import 'package:drinking_quest/game_engine/logic/adventure_catalog.dart';
import 'package:drinking_quest/game_engine/logic/biome_catalog.dart';
import 'package:drinking_quest/game_engine/logic/effect_catalog.dart';
import 'package:drinking_quest/game_engine/logic/item_catalog.dart';
import 'package:drinking_quest/game_engine/logic/origin_catalog.dart';
import 'package:drinking_quest/game_engine/models/models.dart';
import 'package:drinking_quest/game_engine/unique_by_id.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled content packs pass validation with zero errors', () async {
    final cards = await const CardRepository().loadCards();
    final items = await const ItemRepository().loadCatalog();
    final effects = await const EffectRepository().loadCatalog();
    final adventures = await const AdventureRepository().loadCatalog();
    final biomes = await const BiomeRepository().loadCatalog();
    final origins = await const OriginRepository().loadCatalog();

    const validator = ContentValidator();
    final errors = validator.validate(
      cards: cards,
      itemCatalog: items,
      effectCatalog: effects,
      adventureCatalog: adventures,
      biomeCatalog: biomes,
      originCatalog: origins,
    );

    expect(errors, isEmpty, reason: errors.join('\n'));
  });

  test(
    'no bundled adventure node silently grants a reward — AdventureEngine '
    'never shows a node\'s text unless it has choices, so a node with only '
    'autoTransition and a mechanical grant in onEnterActions would hand out '
    'an item/effect/stat/origin the player never sees a reason for (this is '
    'exactly the bug the traveling-merchant/legendary-reveal nodes had)',
    () async {
      final adventures = await const AdventureRepository().loadCatalog();

      final offenders = <String>[];
      for (final adventure in adventures.all) {
        for (final node in adventure.nodes.values) {
          if (node.hasChoices) continue;
          final grantsSomething = node.onEnterActions.any(
            (action) =>
                action is GiveItemAction ||
                action is ApplyEffectAction ||
                action is ModifyStatAction ||
                action is RevealOriginAction,
          );
          if (grantsSomething) {
            offenders.add('${adventure.id} -> ${node.id}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'These nodes grant something but have no choices, so their '
            'text (and the reason for the grant) is never shown — give '
            'them a single "Понятно" choice instead of autoTransition:\n'
            '${offenders.join('\n')}',
      );
    },
  );

  group('ContentValidator', () {
    const item = InventoryItem(
      id: 'itm_ok',
      name: 'ok',
      description: 'd',
      rarity: Rarity.common,
      usageType: ItemUsageType.automatic,
      isConsumable: false,
    );
    const effect = GameEffect(
      id: 'eff_ok',
      name: 'ok',
      description: 'd',
      polarity: EffectPolarity.positive,
      duration: 1,
      remainingTurns: 1,
    );

    test('flags a card action referencing an unknown item id', () {
      final card = GameCard(
        id: 'c1',
        title: 't',
        description: 'd',
        type: CardType.item,
        rarity: Rarity.common,
        weight: 1,
        actions: const [GiveItemAction(itemId: 'itm_does_not_exist')],
      );

      const validator = ContentValidator();
      final errors = validator.validate(
        cards: [card],
        itemCatalog: const ItemCatalog({'itm_ok': item}),
        effectCatalog: const EffectCatalog({'eff_ok': effect}),
        adventureCatalog: const AdventureCatalog({}),
        biomeCatalog: const BiomeCatalog({
          'forest': Biome(id: 'forest', name: 'Forest', description: 'd'),
        }),
        originCatalog: const OriginCatalog({}),
      );

      expect(errors, [contains('itm_does_not_exist')]);
    });

    test('flags a card condition referencing an unknown effect id', () {
      final card = GameCard(
        id: 'c1',
        title: 't',
        description: 'd',
        type: CardType.event,
        rarity: Rarity.common,
        weight: 1,
        conditions: const [
          CurrentPlayerHasEffectCondition(effectId: 'eff_missing'),
        ],
      );

      const validator = ContentValidator();
      final errors = validator.validate(
        cards: [card],
        itemCatalog: const ItemCatalog({'itm_ok': item}),
        effectCatalog: const EffectCatalog({'eff_ok': effect}),
        adventureCatalog: const AdventureCatalog({}),
        biomeCatalog: const BiomeCatalog({
          'forest': Biome(id: 'forest', name: 'Forest', description: 'd'),
        }),
        originCatalog: const OriginCatalog({}),
      );

      expect(errors, [contains('eff_missing')]);
    });

    test(
      'flags a card whose choices are all conditioned with no unconditioned fallback',
      () {
        final card = GameCard(
          id: 'no_fallback',
          title: 't',
          description: 'd',
          type: CardType.event,
          rarity: Rarity.common,
          weight: 1,
          choices: const [
            CardChoice(
              label: 'a',
              conditions: [WorldFlagSetCondition(flag: 'x')],
            ),
            CardChoice(
              label: 'b',
              conditions: [WorldFlagUnsetCondition(flag: 'x')],
            ),
          ],
        );

        const validator = ContentValidator();
        final errors = validator.validate(
          cards: [card],
          itemCatalog: const ItemCatalog({}),
          effectCatalog: const EffectCatalog({}),
          adventureCatalog: const AdventureCatalog({}),
          biomeCatalog: const BiomeCatalog({
            'forest': Biome(id: 'forest', name: 'Forest', description: 'd'),
          }),
          originCatalog: const OriginCatalog({}),
        );

        expect(errors, [contains('none of them is unconditioned')]);
      },
    );

    test('flags duplicate card ids and non-positive weights', () {
      final cardA = GameCard(
        id: 'dup',
        title: 't',
        description: 'd',
        type: CardType.event,
        rarity: Rarity.common,
        weight: 1,
      );
      final cardB = GameCard(
        id: 'dup',
        title: 't',
        description: 'd',
        type: CardType.event,
        rarity: Rarity.common,
        weight: 0,
      );

      const validator = ContentValidator();
      final errors = validator.validate(
        cards: [cardA, cardB],
        itemCatalog: const ItemCatalog({}),
        effectCatalog: const EffectCatalog({}),
        adventureCatalog: const AdventureCatalog({}),
        biomeCatalog: const BiomeCatalog({
          'forest': Biome(id: 'forest', name: 'Forest', description: 'd'),
        }),
        originCatalog: const OriginCatalog({}),
      );

      expect(
        errors,
        containsAll([
          contains('Duplicate card id'),
          contains('non-positive weight'),
        ]),
      );
    });

    test(
      'flags a startAdventure action referencing an unknown adventure id',
      () {
        final card = GameCard(
          id: 'c1',
          title: 't',
          description: 'd',
          type: CardType.legendary,
          rarity: Rarity.legendary,
          weight: 1,
          actions: const [
            StartAdventureAction(adventureId: 'missing_adventure'),
          ],
        );

        const validator = ContentValidator();
        final errors = validator.validate(
          cards: [card],
          itemCatalog: const ItemCatalog({}),
          effectCatalog: const EffectCatalog({}),
          adventureCatalog: const AdventureCatalog({}),
          biomeCatalog: const BiomeCatalog({
            'forest': Biome(id: 'forest', name: 'Forest', description: 'd'),
          }),
          originCatalog: const OriginCatalog({}),
        );

        expect(errors, [contains('missing_adventure')]);
      },
    );

    test(
      'flags an adventure node destination pointing at a non-existent node',
      () {
        final adventure = Adventure(
          id: 'adv1',
          entryNodeId: 'start',
          nodes: {
            'start': const AdventureNode(
              id: 'start',
              text: 't',
              autoTransition: GoToNode(nodeId: 'does_not_exist'),
            ),
          },
        );

        const validator = ContentValidator();
        final errors = validator.validate(
          cards: const [],
          itemCatalog: const ItemCatalog({}),
          effectCatalog: const EffectCatalog({}),
          adventureCatalog: AdventureCatalog({'adv1': adventure}),
          biomeCatalog: const BiomeCatalog({
            'forest': Biome(id: 'forest', name: 'Forest', description: 'd'),
          }),
          originCatalog: const OriginCatalog({}),
        );

        expect(errors, [contains('does_not_exist')]);
      },
    );

    test('flags a cycle of auto-transition-only nodes', () {
      final adventure = Adventure(
        id: 'adv_cycle',
        entryNodeId: 'a',
        nodes: const {
          'a': AdventureNode(
            id: 'a',
            text: 't',
            autoTransition: GoToNode(nodeId: 'b'),
          ),
          'b': AdventureNode(
            id: 'b',
            text: 't',
            autoTransition: GoToNode(nodeId: 'a'),
          ),
        },
      );

      const validator = ContentValidator();
      final errors = validator.validate(
        cards: const [],
        itemCatalog: const ItemCatalog({}),
        effectCatalog: const EffectCatalog({}),
        adventureCatalog: AdventureCatalog({'adv_cycle': adventure}),
        biomeCatalog: const BiomeCatalog({
          'forest': Biome(id: 'forest', name: 'Forest', description: 'd'),
        }),
        originCatalog: const OriginCatalog({}),
      );

      expect(errors, [contains('cycle')]);
    });

    test(
      'does not flag a loop that passes through a node with player choices',
      () {
        final adventure = Adventure(
          id: 'adv_safe_loop',
          entryNodeId: 'a',
          nodes: const {
            'a': AdventureNode(
              id: 'a',
              text: 't',
              autoTransition: GoToNode(nodeId: 'b'),
            ),
            'b': AdventureNode(
              id: 'b',
              text: 't',
              choices: [
                AdventureChoice(
                  label: 'again',
                  onSuccess: NodeTransition(to: GoToNode(nodeId: 'a')),
                ),
                AdventureChoice(
                  label: 'stop',
                  onSuccess: NodeTransition(to: EndAdventure()),
                ),
              ],
            ),
          },
        );

        const validator = ContentValidator();
        final errors = validator.validate(
          cards: const [],
          itemCatalog: const ItemCatalog({}),
          effectCatalog: const EffectCatalog({}),
          adventureCatalog: AdventureCatalog({'adv_safe_loop': adventure}),
          biomeCatalog: const BiomeCatalog({
            'forest': Biome(id: 'forest', name: 'Forest', description: 'd'),
          }),
          originCatalog: const OriginCatalog({}),
        );

        expect(errors, isEmpty);
      },
    );
  });

  group('uniqueById', () {
    test('throws with a clear message on a duplicate id', () {
      expect(
        () => uniqueById(['a', 'b', 'a'], (s) => s, 'item'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Duplicate item id "a"'),
          ),
        ),
      );
    });

    test('builds a map keyed by id when there are no duplicates', () {
      final map = uniqueById(['a', 'b', 'c'], (s) => s, 'item');
      expect(map, {'a': 'a', 'b': 'b', 'c': 'c'});
    });
  });
}
