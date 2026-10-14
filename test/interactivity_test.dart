import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/game_engine/data/adventure_repository.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

/// The scenes the interactivity pass gave a way in — the fourth playtest's
/// «телефон что-то прочитал, и ничего».
const _reworked = [
  'world_village_after_feast',
  'life_cartographer_argues_north',
  'life_smith_teaches_apprentice',
  'state_peddler_fixing_wheel',
  'road_porter_rests',
  'world_village_before_feast',
  'state_wanderer_asleep',
  'crafts_horse_doctor',
  'road_mason_measures',
  'road_funeral_procession',
  'road_courier_wrong_way',
  'village_cooper_hoops',
  'world_road_new_chapel',
  'crafts_tinker_sharpens_everything',
  'road_watchman_shift_over',
  'state_smith_mending_cart',
  'road_late_wedding',
  'road_woman_with_geese',
  'life_herbwoman_argues_price',
  'life_peddler_loses_to_child',
  'story_anvil_delivered',
  'home_cat_on_the_roof',
  'village_weaver_broken_thread',
  'story_well_run_dry',
  'home_supper_waits',
  'world_village_fresh_grave',
  'world_village_threshing_floor',
  'home_shoes_by_door',
  'story_field_burnt',
  'village_midwife_leaves_at_night',
  'home_letter_read_aloud',
  'home_moving_out',
  'world_village_apple_orchard',
  'story_bell_hauled_up',
  'village_miller_stone_dressing',
  'road_boy_with_stick',
  'village_boy_owes_apple',
  'story_roof_torn_off',
  'village_hive_moved',
  'home_wife_sharpens_knife',
  'life_wanderer_gives_directions',
  'story_belfry_empty',
  'story_forge_cold',
  'world_village_old_well',
  'story_digging_new_well',
  'home_someone_sings_inside',
  'village_roof_thatching',
  'story_fence_dug_together',
  'village_old_woman_names',
  'road_dog_follows',
  'trap_cold_shower_v6',
  'state_alchemist_boiling',
];

const _drinks = {
  'item_bravery_flask',
  'item_stash',
  'item_beer_keg',
  'item_flask',
};

bool _pays(List<GameAction> actions) => actions.any(
  (a) =>
      a is DrinkAction ||
      (a is TakeItemAction && _drinks.contains(a.itemId)) ||
      (a is ChanceCheckAction && _pays(a.winnerActions)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every reworked scene has two ways in that anyone sees', () async {
    final cards = await const CardRepository().loadCards();
    for (final id in _reworked) {
      final card = cards.singleWhere((c) => c.id == id);
      final open = card.choices.where(
        (c) =>
            c.conditions.isEmpty &&
            !c.inspect &&
            c.label != 'Пройти мимо' &&
            !c.label.startsWith('Пожать плечами'),
      );
      expect(open.length, greaterThanOrEqualTo(2), reason: id);
    }
  });

  test('a price always costs the player', () async {
    // Paid in drink: the player either gives a drink away or drinks along.
    // «Пьёт торговец» with nothing gone from the player is a gift.
    final pay = RegExp(
      r'(налить|угостить|поставить (ему|им) кружк|за выпивку|за кружку|'
      r'пьёт (он|торговец|лавочник)|цена:)',
      caseSensitive: false,
    );
    final cards = await const CardRepository().loadCards();
    final free = [
      for (final card in cards)
        for (final choice in card.choices)
          if (pay.hasMatch('${choice.label} ${choice.outcome ?? ''}') &&
              !_pays(choice.actions))
            '${card.id}: «${choice.label}»',
    ];
    expect(free, isEmpty);

    final drunkPrice = cards.singleWhere(
      (c) => c.id == 'village_drunk_pays_double',
    );
    final double = drunkPrice.choices.singleWhere(
      (c) => c.label.startsWith('Заплатить вдвое'),
    );
    expect(double.actions.whereType<DrinkAction>(), hasLength(2));
  });

  test('about one night watch in three has something out there', () async {
    final cards = await const CardRepository().loadCards();
    final calm = cards.singleWhere((c) => c.id == 'rest_night_watch').weight;
    for (final biome in [
      'forest',
      'mountains',
      'desert',
      'coast',
      'floodlands',
      'graveyard',
    ]) {
      final threats = cards
          .where((c) => c.id.startsWith('watch_'))
          .where(
            (c) => c.conditions.any(
              (k) => k is InBiomeCondition && k.biomeId == biome,
            ),
          )
          // The wyvern comes once, late; the night's usual odds are the rest.
          .where((c) => c.id != 'watch_mountains_wyvern')
          .fold<int>(0, (s, c) => s + c.weight);
      final share = threats / (threats + calm);
      expect(share, inInclusiveRange(0.25, 0.35), reason: biome);
    }
    final wyvern = cards.singleWhere((c) => c.id == 'watch_mountains_wyvern');
    expect(
      wyvern.conditions.whereType<WorldFlagUnsetCondition>().map((k) => k.flag),
      contains('wyvern_seen'),
    );
    expect(wyvern.conditions.whereType<MinimumStepCondition>(), isNotEmpty);
  });

  test(
    'fifteen pairs of passages, each side with a sign and a throw',
    () async {
      final cards = await const CardRepository().loadCards();
      final pairs = cards.where((c) => c.id.startsWith('luck_two_passages_'));
      expect(pairs, hasLength(15));
      expect(cards.where((c) => c.id == 'luck_mystery_choice'), isEmpty);
      for (final card in pairs) {
        final sides = card.choices.where((c) => c.conditions.isEmpty).toList();
        expect(sides, hasLength(2), reason: card.id);
        for (final side in sides) {
          final throwOf = side.actions.whereType<ChanceCheckAction>().single;
          expect(throwOf.stat, StatType.luck, reason: card.id);
          expect(throwOf.winnerOutcome, isNotNull, reason: card.id);
          expect(throwOf.loserOutcome, isNotNull, reason: card.id);
        }
        expect(
          card.choices.where(
            (c) => c.conditions.any(
              (k) =>
                  k is CurrentPlayerHasItemCondition &&
                  k.itemId == 'item_ward_amulet',
            ),
          ),
          hasLength(1),
          reason: card.id,
        );
      }
    },
  );

  test('Frol\'s coin reaches the ghost, and the loop closes', () async {
    final cards = await const CardRepository().loadCards();
    final adventures = await const AdventureRepository().loadCatalog();
    const coin = 'item_frol_coin';

    // Frol hands it over.
    final frol = cards.singleWhere((c) => c.id == 'ghost_debtor_frol');
    bool gives(List<GameAction> actions) => actions.any(
      (a) =>
          (a is GiveItemAction && a.itemId == coin) ||
          (a is ChanceCheckAction && gives(a.winnerActions)),
    );
    expect(frol.choices.where((c) => gives(c.actions)), isNotEmpty);

    // Carrying it, the way back to the tavern opens.
    final lit = cards.singleWhere((c) => c.id == 'abandoned_tavern_lit');
    expect(
      lit.conditions.whereType<CurrentPlayerHasItemCondition>().single.itemId,
      coin,
    );
    expect(
      lit.actions.whereType<StartAdventureAction>().single.adventureId,
      'abandoned_tavern',
    );

    // At the door, the debt can be paid, and it is taken and rewarded.
    final tavern = adventures.byId('abandoned_tavern');
    final door = tavern.nodes['tavern_entrance']!;
    final pay = door.choices.singleWhere((c) => c.label == 'Отдать долг Фрола');
    expect(
      pay.conditions.whereType<CurrentPlayerHasItemCondition>().single.itemId,
      coin,
    );
    expect(
      pay.onSuccess.actions.whereType<TakeItemAction>().single.itemId,
      coin,
    );
    final paid = tavern.nodes[pay.onSuccess.to.toJson()['nodeId']]!;
    expect(paid.choices, isNotEmpty);
    expect(
      paid.onEnterActions.whereType<SetWorldFlagAction>().map((a) => a.flag),
      contains('ghost_at_rest'),
    );
    expect(paid.onEnterActions.whereType<GiveItemAction>(), isNotEmpty);
  });
}
