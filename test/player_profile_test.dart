import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/core/constants/ally_flags.dart';
import 'package:drinking_quest/core/constants/world_state_labels.dart';
import 'package:drinking_quest/features/game/presentation/widgets/player_profile_sheet.dart';
import 'package:drinking_quest/features/game/presentation/widgets/player_status_panel.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

const _hunter = Origin(
  id: 'origin_hunter',
  name: '🏹 Охотник',
  description: 'Ты читаешь следы там, где другие видят просто грязь.',
  category: OriginCategory.lifePath,
  rarity: Rarity.common,
  statModifiers: {StatType.attentiveness: 1, StatType.charisma: -1},
);

const _flask = InventoryItem(
  id: 'item_flask',
  name: 'Фляга',
  description: 'Личная фляга — то, чем платят, когда платить больше нечем.',
  rarity: Rarity.common,
  usageType: ItemUsageType.manual,
  isConsumable: true,
);

const _keg = InventoryItem(
  id: 'item_beer_keg',
  name: 'Бочонок пива',
  description: 'Хватит на всю компанию — и на один хороший откуп.',
  rarity: Rarity.uncommon,
  usageType: ItemUsageType.manual,
  isConsumable: true,
  ownership: ItemOwnership.shared,
);

const _blessing = GameEffect(
  id: 'effect_lucky_streak',
  name: 'Полоса удачи',
  description: 'Удача держится за тебя крепче обычного.',
  polarity: EffectPolarity.positive,
  duration: 3,
  remainingTurns: 2,
);

const _curse = GameEffect(
  id: 'effect_marked',
  name: 'Меченый',
  description: 'Тебя запомнили, и это ещё вернётся.',
  polarity: EffectPolarity.negative,
  duration: -1,
  remainingTurns: -1,
);

Player _player({
  String? originId,
  List<InventoryItem> inventory = const [],
  List<GameEffect> effects = const [],
}) => Player(
  id: 'p1',
  name: 'Александр',
  originId: originId,
  inventory: inventory,
  activeEffects: effects,
  stats: const PlayerStats({StatType.strength: 2, StatType.luck: 1}),
);

Future<void> _openProfile(
  WidgetTester tester, {
  required Player player,
  Origin? origin,
  List<InventoryItem> partyInventory = const [],
  WorldState worldState = const WorldState(),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showPlayerProfileSheet(
            context: context,
            player: player,
            origin: origin,
            partyInventory: partyInventory,
            worldState: worldState,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Every `setWorldFlag` flag any bundled content sets — read straight from
/// the JSON rather than through the typed models, so the walk survives
/// structural changes to cards/adventures.
Set<String> _flagsSetByContent() {
  final flags = <String>{};
  void walk(Object? node) {
    if (node is Map<String, dynamic>) {
      if (node['action'] == 'setWorldFlag' && node['flag'] is String) {
        flags.add(node['flag'] as String);
      }
      node.values.forEach(walk);
    } else if (node is List) {
      node.forEach(walk);
    }
  }

  for (final file in Directory('assets/data').listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.json')) {
      walk(jsonDecode(file.readAsStringSync()));
    }
  }
  return flags;
}

void main() {
  group('world-state registry', () {
    test('every named state is a flag some content actually sets', () {
      final actual = _flagsSetByContent();
      final unknown = {
        ...worldStateLabels.keys,
        ...allyFlags.keys,
      }.where((flag) => !actual.contains(flag)).toList();

      // Catches both a typo in an id and an entry left behind after the
      // content that set it was rewritten — either way the profile would
      // silently never show that line.
      expect(unknown, isEmpty, reason: 'named but never set: $unknown');
    });

    test('allies are not duplicated as ordinary world states', () {
      // The two registries feed two different sections of the profile, so a
      // flag in both would print twice.
      expect(
        worldStateLabels.keys.where(allyFlags.containsKey),
        isEmpty,
      );
    });

    test('chain progress and bookkeeping flags stay unnamed', () {
      // Locks in the deliberate exclusions: naming `dragon_trail_*` would
      // turn the profile into the quest tracker the design doc rules out,
      // and `in_tavern`/`met_*`/`visited_*` say nothing about the party.
      final named = worldStateLabels.keys;
      expect(named.where((f) => f.startsWith('dragon_trail')), isEmpty);
      expect(named.where((f) => f.startsWith('met_')), isEmpty);
      expect(named.where((f) => f.startsWith('visited_')), isEmpty);
      expect(named, isNot(contains('dragon_lair_known')));
      expect(named, isNot(contains('in_tavern')));
    });
  });

  group('compact roster card', () {
    testWidgets('summarises items and effects as counts, with no prose', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerStatusPanel(
              player: _player(
                originId: _hunter.id,
                inventory: const [_flask],
                effects: const [_blessing, _curse],
              ),
              origin: _hunter,
              onTap: () {},
            ),
          ),
        ),
      );

      // Counts, not contents: one item, one blessing, one curse — found by
      // their tooltips rather than by the digit, since a stat value of 1 is
      // also on the card.
      expect(find.byTooltip('Предметы'), findsOneWidget);
      expect(find.byTooltip('Благословения'), findsOneWidget);
      expect(find.byTooltip('Проклятия'), findsOneWidget);
      // The origin keeps its name — it's the character's identity.
      expect(find.text('🏹 Охотник'), findsOneWidget);
      // Nothing on the card explains anything: no descriptions, no effect or
      // item names, no spelled-out stats.
      expect(find.text('Фляга'), findsNothing);
      expect(find.text('Полоса удачи'), findsNothing);
      expect(find.textContaining('Удача держится'), findsNothing);
      expect(find.text('Сила 2'), findsNothing);
      // Compact stats are still readable as numbers.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Подробнее ›'), findsOneWidget);
    });

    testWidgets('tapping the card opens the profile', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: PlayerStatusPanel(
                player: _player(originId: _hunter.id),
                origin: _hunter,
                onTap: () => showPlayerProfileSheet(
                  context: context,
                  player: _player(originId: _hunter.id),
                  origin: _hunter,
                  partyInventory: const [],
                  worldState: const WorldState(),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('ХАРАКТЕРИСТИКИ'), findsNothing);
      await tester.tap(find.byType(PlayerStatusPanel));
      await tester.pumpAndSettle();
      expect(find.text('ХАРАКТЕРИСТИКИ'), findsOneWidget);
    });

    testWidgets('without onTap there is no tap affordance', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerStatusPanel(player: _player(), origin: null),
          ),
        ),
      );
      expect(find.text('Подробнее ›'), findsNothing);
    });
  });

  group('player profile', () {
    testWidgets('the origin section explains what the origin is', (
      tester,
    ) async {
      await _openProfile(
        tester,
        player: _player(originId: _hunter.id),
        origin: _hunter,
      );

      expect(find.text('🏹 Охотник'), findsOneWidget);
      expect(find.text('Обычное · жизненный путь'), findsOneWidget);
      expect(find.textContaining('читаешь следы'), findsOneWidget);
      // Stat modifiers spelled out, with the minus shown as a real minus.
      expect(
        find.text('Оставило свой след: +1 Внимательность, −1 Харизма.'),
        findsOneWidget,
      );
    });

    testWidgets('an unrevealed origin reads as a narrative state', (
      tester,
    ) async {
      await _openProfile(tester, player: _player(), origin: null);

      expect(find.textContaining('пока неизвестно'), findsOneWidget);
      // The sheet's own header stays name-only, so the unknown state is told
      // in words here rather than repeated as a muted "?" badge.
      expect(find.text('ПРОИСХОЖДЕНИЕ'), findsOneWidget);
    });

    testWidgets('every stat is listed, including the zeroes', (tester) async {
      await _openProfile(tester, player: _player(), origin: null);

      expect(find.text('Сила 2'), findsOneWidget);
      expect(find.text('Удача 1'), findsOneWidget);
      // The roster card hides zeroes; a dossier shows them, because
      // "Хитрость 0" answers why a cunning option never appears.
      expect(find.text('Хитрость 0'), findsOneWidget);
    });

    testWidgets('effects show their description and how long they last', (
      tester,
    ) async {
      await _openProfile(
        tester,
        player: _player(effects: const [_blessing, _curse]),
        origin: null,
      );

      expect(find.text('БЛАГОСЛОВЕНИЯ'), findsOneWidget);
      expect(find.text('Полоса удачи'), findsOneWidget);
      expect(find.textContaining('Удача держится'), findsOneWidget);
      expect(find.text('ещё 2 хода'), findsOneWidget);

      expect(find.text('ПРОКЛЯТИЯ'), findsOneWidget);
      expect(find.text('Меченый'), findsOneWidget);
      // An indefinite effect must not render as "ещё -1 ходов".
      expect(find.text('до конца путешествия'), findsOneWidget);
    });

    testWidgets('party gear is listed alongside personal items, marked', (
      tester,
    ) async {
      await _openProfile(
        tester,
        player: _player(inventory: const [_flask]),
        origin: null,
        partyInventory: const [_keg],
      );

      expect(find.text('Фляга'), findsOneWidget);
      expect(find.text('обычное · одноразовый'), findsOneWidget);
      expect(find.text('Бочонок пива'), findsOneWidget);
      expect(find.text('необычное · общее · одноразовый'), findsOneWidget);
      expect(find.textContaining('Хватит на всю компанию'), findsOneWidget);
    });

    testWidgets('allies and world memory are shown as facts about the party', (
      tester,
    ) async {
      await _openProfile(
        tester,
        player: _player(),
        origin: null,
        worldState: const WorldState(
          flags: {
            'captain_ally': true,
            'warlord_enemy': true,
            // Set, but deliberately unnamed — must not appear.
            'in_tavern': true,
            'dragon_trail_rumors': true,
          },
        ),
      );

      expect(find.text('СОЮЗНИКИ КОМПАНИИ'), findsOneWidget);
      expect(find.text('Капитан пиратов'), findsOneWidget);
      expect(find.textContaining('как к друзьям'), findsOneWidget);

      expect(find.text('МИР ПОМНИТ'), findsOneWidget);
      expect(find.text('Враг военачальника'), findsOneWidget);
      expect(find.textContaining('память о всей компании'), findsOneWidget);
    });

    testWidgets('empty sections are omitted entirely', (tester) async {
      await _openProfile(tester, player: _player(), origin: null);

      expect(find.text('ПРЕДМЕТЫ'), findsNothing);
      expect(find.text('БЛАГОСЛОВЕНИЯ'), findsNothing);
      expect(find.text('ПРОКЛЯТИЯ'), findsNothing);
      expect(find.text('СОЮЗНИКИ КОМПАНИИ'), findsNothing);
      expect(find.text('МИР ПОМНИТ'), findsNothing);
    });
  });
}
