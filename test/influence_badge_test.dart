import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/core/theme/influence_source.dart';
import 'package:drinking_quest/core/widgets/influence_badge.dart';
import 'package:drinking_quest/features/game/presentation/widgets/card_resolution_dialog.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

/// The longest name in the real 35-origin roster — the worst case the badge
/// has to survive on a narrow phone.
const _longestOrigin = Origin(
  id: 'origin_ancient_kings_heir',
  name: '👑 Наследник древних королей',
  description: 'd',
  category: OriginCategory.trueNature,
  rarity: Rarity.epic,
);

const _catalog = OriginCatalog({
  'origin_ancient_kings_heir': _longestOrigin,
});

Future<void> _openDialog(
  WidgetTester tester,
  GameCard card, {
  OriginCatalog? origins,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showCardResolutionDialog(
            context: context,
            card: card,
            participants: null,
            onResolve: (_) {},
            origins: origins,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('influencesOf classification', () {
    test('recognises each of the five sources', () {
      expect(
        influencesOf([
          const CurrentPlayerHasOriginCondition(originId: 'origin_hunter'),
        ]),
        [InfluenceSource.origin],
      );
      expect(
        influencesOf([
          const CurrentPlayerHasItemCondition(itemId: 'item_flask'),
        ]),
        [InfluenceSource.item],
      );
      expect(
        influencesOf([
          const CurrentPlayerStatAtLeastCondition(
            stat: StatType.charisma,
            value: 2,
          ),
        ]),
        [InfluenceSource.stat],
      );
      // captain_ally is in the shared ally registry, so it reads as an ally
      // rather than as generic world memory.
      expect(
        influencesOf([const WorldFlagSetCondition(flag: 'captain_ally')]),
        [InfluenceSource.ally],
      );
      expect(
        influencesOf([const WorldFlagSetCondition(flag: 'stole_magic_book')]),
        [InfluenceSource.world],
      );
    });

    test('reports several sources at once, always in the same order', () {
      final sources = influencesOf([
        const CurrentPlayerStatAtLeastCondition(
          stat: StatType.cunning,
          value: 2,
        ),
        const CurrentPlayerHasOriginCondition(originId: 'origin_hunter'),
        const CurrentPlayerHasItemCondition(itemId: 'item_flask'),
      ]);
      expect(sources, [
        InfluenceSource.origin,
        InfluenceSource.item,
        InfluenceSource.stat,
      ]);
    });

    test('does not badge absences, guards or ambient context', () {
      expect(
        influencesOf([
          // "you don't have one yet" — a reason it's offered, not influence
          const CurrentPlayerMissingItemCondition(itemId: 'item_flask'),
          // a door closed for one origin is felt as an absence, and an
          // absence cannot carry a badge
          const CurrentPlayerLacksOriginCondition(originId: 'origin_drunkard'),
          const WorldFlagUnsetCondition(flag: 'in_tavern'),
          const AdventureNotCompletedCondition(adventureId: 'dragon'),
          // already visible in BiomeBanner / the season scene
          const InBiomeCondition(biomeId: 'forest'),
          const InWeatherCondition(weather: Weather.rain),
          const InSeasonCondition(season: Season.autumn),
          const MinimumTurnsInBiomeCondition(turns: 4),
          // table and pacing plumbing
          const MinimumPlayersCondition(count: 2),
          const MinimumStepCondition(steps: 4),
        ]),
        isEmpty,
      );
    });
  });

  group('badge labels', () {
    test('an origin badge names the origin itself', () {
      expect(
        influenceTagsOf([
          const CurrentPlayerHasOriginCondition(
            originId: 'origin_ancient_kings_heir',
          ),
        ], origins: _catalog),
        [(source: InfluenceSource.origin, text: '👑 Наследник древних королей')],
      );
    });

    test('falls back to the category word without a catalog or a match', () {
      const gated = [
        CurrentPlayerHasOriginCondition(originId: 'origin_ancient_kings_heir'),
      ];
      expect(influenceTagsOf(gated).single.text, 'Происхождение');
      expect(
        influenceTagsOf([
          const CurrentPlayerHasOriginCondition(originId: 'origin_unknown_id'),
        ], origins: _catalog).single.text,
        'Происхождение',
      );
    });

    test('"someone at the table" stays generic — it may not be this player', () {
      expect(
        influenceTagsOf([
          const AnyPlayerHasOriginCondition(
            originId: 'origin_ancient_kings_heir',
          ),
        ], origins: _catalog).single.text,
        'Происхождение',
      );
    });

    test('every other source keeps its category word', () {
      expect(
        influenceTagsOf([
          const CurrentPlayerHasItemCondition(itemId: 'item_flask'),
          const WorldFlagSetCondition(flag: 'captain_ally'),
        ], origins: _catalog).map((t) => t.text),
        ['Предмет', 'Союзник'],
      );
    });
  });

  group('dialog rendering', () {
    testWidgets('a gated option is labelled with its source, a plain one is not', (
      tester,
    ) async {
      const card = GameCard(
        id: 'c',
        title: 'Всадники из-за бархана',
        description: 'Из-за бархана появляются всадники.',
        type: CardType.event,
        rarity: Rarity.common,
        weight: 1,
        choices: [
          CardChoice(
            label: 'Протянуть флягу',
            conditions: [CurrentPlayerHasItemCondition(itemId: 'item_flask')],
          ),
          CardChoice(label: 'Сражаться'),
        ],
      );

      await _openDialog(tester, card);

      expect(find.text('Протянуть флягу'), findsOneWidget);
      expect(find.text('Сражаться'), findsOneWidget);
      expect(find.text('Предмет'), findsOneWidget);
    });

    testWidgets('a whole event gated by world memory says so', (tester) async {
      const card = GameCard(
        id: 'c',
        title: 'Слухи среди торговцев',
        description: 'Лоточник косится на тебя и вдруг узнаёт.',
        type: CardType.curse,
        rarity: Rarity.uncommon,
        weight: 1,
        conditions: [WorldFlagSetCondition(flag: 'caught_merchant_scam')],
      );

      await _openDialog(tester, card);

      expect(find.text('Мир'), findsOneWidget);
    });

    testWidgets('an ordinary biome-gated card carries no badge at all', (
      tester,
    ) async {
      const card = GameCard(
        id: 'c',
        title: 'Вой в чаще',
        description: 'Из глубины леса доносится вой.',
        type: CardType.trap,
        rarity: Rarity.common,
        weight: 1,
        conditions: [InBiomeCondition(biomeId: 'forest')],
        choices: [CardChoice(label: 'Отбиваться')],
      );

      await _openDialog(tester, card);

      expect(find.byType(InfluenceBadge), findsNothing);
    });

    testWidgets(
      'the longest origin name fits a narrow phone without overflowing',
      (tester) async {
        // 320x568 — narrower than any phone the game realistically runs on,
        // and narrower than the 360dp Android baseline.
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        const card = GameCard(
          id: 'c',
          title: 'Стража у городских ворот',
          description: 'Стражники разглядывают вашу компанию.',
          type: CardType.event,
          rarity: Rarity.common,
          weight: 1,
          choices: [
            CardChoice(
              // A long label as well, so the badge is squeezed from both
              // sides at once.
              label: 'Назвать своё имя и потребовать пропустить',
              conditions: [
                CurrentPlayerHasOriginCondition(
                  originId: 'origin_ancient_kings_heir',
                ),
              ],
            ),
            CardChoice(label: 'Уйти'),
          ],
        );

        await _openDialog(tester, card, origins: _catalog);

        // A RenderFlex overflow is reported through FlutterError, which
        // `testWidgets` turns into a failure on its own — so reaching this
        // line already proves the layout holds. What the assertions add is
        // that it holds *without truncating the name*.
        //
        // Note this is a deliberately pessimistic measurement: widget tests
        // render in the test font, where every glyph is a full square em, so
        // this 27-character name is ~310 logical px wide here against ~187
        // available. A real proportional font is far narrower — so passing
        // under the test font is an upper bound, not a realistic one.
        final badge = tester.widget<InfluenceBadge>(
          find.byType(InfluenceBadge),
        );
        expect(badge.tag.text, '👑 Наследник древних королей');

        final text = tester.renderObject<RenderParagraph>(
          find.text('👑 Наследник древних королей'),
        );
        expect(text.didExceedMaxLines, isFalse);
      },
    );
  });
}
