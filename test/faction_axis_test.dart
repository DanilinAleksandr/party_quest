import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/core/constants/ally_flags.dart';
import 'package:drinking_quest/core/constants/world_state_labels.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

/// The Order and the Circle are the world's first pair of opposed powers.
/// These tests guard the three things that make an axis an axis rather than
/// two unrelated storylines — see «Ось фракций» in the design doc.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const order = {'paladin_ally', 'declared_heretic', 'paladin_debt'};
  const circle = {'circle_ally', 'circle_enemy'};

  /// Every condition attached to a card or any of its choices.
  List<GameCondition> allConditions(GameCard card) => [
    ...card.conditions,
    for (final choice in card.choices) ...choice.conditions,
  ];

  Set<String> flagsRead(GameCard card) => allConditions(card)
      .whereType<WorldFlagSetCondition>()
      .map((c) => c.flag)
      .toSet();

  test('both standings are readable, and named for the player', () {
    for (final flag in {...order, ...circle}) {
      final named =
          allyFlags.containsKey(flag) || worldStateLabels.containsKey(flag);
      expect(named, isTrue, reason: '$flag has no player-facing name');
    }
    // The friendly end of each faction is an ally (so it inherits the 🤝
    // result card and the 🔵 badge); the hostile end is world memory.
    expect(allyFlags.keys, containsAll(['paladin_ally', 'circle_ally']));
    expect(
      worldStateLabels.keys,
      containsAll(['declared_heretic', 'circle_enemy']),
    );
  });

  test(
    'each faction is felt in at least three different content packs — a '
    'faction confined to its own scenes is scenery, not a power',
    () async {
      final files = <String, Set<String>>{};
      for (final file in Directory('assets/data').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.json')) continue;
        final flags = <String>{};
        void walk(Object? node) {
          if (node is Map<String, dynamic>) {
            if (node['condition'] == 'worldFlagSet' && node['flag'] is String) {
              flags.add(node['flag'] as String);
            }
            node.values.forEach(walk);
          } else if (node is List) {
            node.forEach(walk);
          }
        }

        walk(jsonDecode(file.readAsStringSync()));
        files[file.path] = flags;
      }

      int packsReading(Set<String> faction) => files.values
          .where((flags) => flags.intersection(faction).isNotEmpty)
          .length;

      expect(packsReading(order), greaterThanOrEqualTo(3));
      expect(packsReading(circle), greaterThanOrEqualTo(3));
    },
  );

  test('no single choice demands loyalty to both sides at once', () async {
    final cards = await const CardRepository().loadCards();

    for (final card in cards) {
      for (final choice in card.choices) {
        final flags = choice.conditions
            .whereType<WorldFlagSetCondition>()
            .map((c) => c.flag)
            .toSet();
        expect(
          flags.contains('paladin_ally') && flags.contains('circle_ally'),
          isFalse,
          reason:
              '${card.id}: "${choice.label}" requires both alliances, which '
              'the Circle scene makes mutually exclusive',
        );
      }
    }
  });

  test('a party with no standing at all can still resolve every faction-aware '
      'card', () async {
    final cards = await const CardRepository().loadCards();
    final factionFlags = {...order, ...circle};

    for (final card in cards) {
      final reactsToFactions = flagsRead(card).intersection(factionFlags);
      if (reactsToFactions.isEmpty) continue;

      // Cards that exist *because* of a standing (the herbwoman, the crows)
      // are gated at card level and simply won't be drawn otherwise — those
      // are fine. What must never happen is a drawable card whose every
      // choice needs a standing.
      final gatedAtCardLevel = card.conditions
          .whereType<WorldFlagSetCondition>()
          .any((c) => factionFlags.contains(c.flag));
      if (gatedAtCardLevel || card.choices.isEmpty) continue;

      expect(
        card.choices.where((c) => c.conditions.isEmpty),
        isNotEmpty,
        reason: '${card.id} leaves a standing-less party with no way through',
      );
    }
  });

  test('siding with the Circle actually costs the Order alliance', () {
    // The one place where an alliance is traded rather than collected. Read
    // straight from the adventure JSON: the choice must clear paladin_ally
    // in the same breath as it sets circle_ally.
    final raw = File('assets/data/adventures/witch_circle.json')
        .readAsStringSync();
    final adventure = (jsonDecode(raw) as List).first as Map<String, dynamic>;
    final nodes = adventure['nodes'] as List;
    final wary = nodes.firstWhere((n) => n['id'] == 'circle_wary') as Map;

    final trade = (wary['choices'] as List).firstWhere((choice) {
      final actions = ((choice as Map)['onSuccess'] as Map)['actions'] as List;
      return actions.any(
        (a) => a['action'] == 'setWorldFlag' && a['flag'] == 'paladin_ally' && a['value'] == false,
      );
    });

    final actions = (trade['onSuccess'] as Map)['actions'] as List;
    expect(
      actions.any(
        (a) => a['action'] == 'setWorldFlag' && a['flag'] == 'circle_ally' && a['value'] == true,
      ),
      isTrue,
    );
  });
}
