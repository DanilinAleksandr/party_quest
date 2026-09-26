import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/core/theme/influence_source.dart';
import 'package:drinking_quest/core/widgets/influence_badge.dart';
import 'package:drinking_quest/features/game/application/adventure_names.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

GameCard _entry(String id, String title, String adventureId) => GameCard(
  id: id,
  title: title,
  description: 'd',
  type: CardType.event,
  rarity: Rarity.common,
  weight: 1,
  actions: [StartAdventureAction(adventureId: adventureId)],
);

JourneyLogEntry _logged(String text) =>
    JourneyLogEntry(text: text, type: CardType.event);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('place flags', () {
    test('where the party is standing earns no badge', () {
      for (final flag in ['in_rest', 'in_tavern']) {
        expect(influencesOf([WorldFlagSetCondition(flag: flag)]), isEmpty);
        expect(
          influencesOf([MinimumStepsSinceFlagCondition(flag: flag, steps: 1)]),
          isEmpty,
        );
      }
    });

    test('what the world remembers still does', () {
      expect(
        influencesOf([const WorldFlagSetCondition(flag: 'grave_robbed')]),
        [InfluenceSource.world],
      );
    });

    test('«Сборы» in the shipped pack carries no badge', () async {
      final cards = await const CardRepository().loadCards();
      final departure = cards.singleWhere((c) => c.id == 'rest_departure');
      expect(influencesOf(departure.conditions), isEmpty);
    });
  });

  group('a remembered adventure', () {
    const funeral = AdventureCompletedCondition(adventureId: 'climax_funeral');

    test('is named on the badge', () {
      final tags = influenceTagsOf(
        [funeral],
        adventureNames: {'climax_funeral': 'Много людей у одной могилы'},
      );
      expect(tags.single.source, InfluenceSource.world);
      expect(tags.single.text, 'Много людей у одной могилы');
    });

    test('stays «Мир» when its name is not known', () {
      expect(influenceTagsOf([funeral]).single.text, 'Мир');
      expect(
        influenceTagsOf([funeral], adventureNames: const {}).single.text,
        'Мир',
      );
    });

    test('names the pill even behind a plain world flag', () {
      final tags = influenceTagsOf(
        [const WorldFlagSetCondition(flag: 'grave_robbed'), funeral],
        adventureNames: {'climax_funeral': 'Много людей у одной могилы'},
      );
      expect(tags.single.text, 'Много людей у одной могилы');
    });
  });

  group('adventure names', () {
    test('one way in is the name', () {
      final titles = adventureEntryTitles([
        _entry('a', 'Много людей у одной могилы', 'funeral'),
      ]);
      expect(rememberedAdventureNames(titles, const []), {
        'funeral': 'Много людей у одной могилы',
      });
    });

    test('of several ways in, the one this party took', () {
      final titles = adventureEntryTitles([
        _entry('a', 'Корни под ногами', 'circle'),
        _entry('b', 'Огонь у ограды', 'circle'),
      ]);
      expect(rememberedAdventureNames(titles, const []), isEmpty);
      expect(
        rememberedAdventureNames(titles, [
          _logged('Аня: Дорога'),
          _logged('Боря: Огонь у ограды'),
        ]),
        {'circle': 'Огонь у ограды'},
      );
    });

    test('the funeral goes by its journal line in the shipped pack', () async {
      final cards = await const CardRepository().loadCards();
      final names = rememberedAdventureNames(
        adventureEntryTitles(cards),
        const [],
      );
      expect(names['climax_funeral'], 'Много людей у одной могилы');
    });
  });
}
