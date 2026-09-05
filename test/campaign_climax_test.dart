import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

/// The climax scenes are the campaign summing itself up: a trial, a feast, a
/// funeral, a fair, a village council. Their rule, from the design brief, is
/// absolute — **не должно существовать реплики, которая не опирается на
/// реально произошедшее событие**. These tests hold that line, because it is
/// the one thing that cannot be checked by playing (a missing gate just looks
/// like a line that always shows up).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const climaxes = {
    'climax_trial',
    'climax_feast',
    'climax_funeral',
    'climax_fair',
    'climax_village_council',
  };

  List<Map<String, dynamic>> loadClimaxAdventures() {
    final raw = File('assets/data/adventures/campaign_climaxes.json')
        .readAsStringSync();
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  /// Conditions that name a specific thing the party did, owns or became.
  /// Ambient gates (biome, weather, step count) do not count: they say
  /// nothing about *this* campaign's history.
  bool isMemory(Map<String, dynamic> condition) => const {
    'worldFlagSet',
    'worldFlagUnset',
    'minimumStepsSinceFlag',
    'globalModifierAtLeast',
    'currentPlayerHasOrigin',
    'anyPlayerHasOrigin',
    'currentPlayerHasItem',
    'partyHasItem',
    'currentPlayerHasEffect',
    'anyPlayerHasEffect',
    'adventureCompleted',
  }.contains(condition['condition']);

  test('every witness in a climax speaks only about something that happened', () {
    for (final adventure in loadClimaxAdventures()) {
      for (final node in (adventure['nodes'] as List).cast<Map>()) {
        for (final choice in (node['choices'] as List).cast<Map>()) {
          final conditions = (choice['conditions'] as List? ?? const [])
              .cast<Map<String, dynamic>>();
          // An *unconditioned* choice is not a witness — it is the party
          // speaking for itself, and every node needs at least one of those
          // (asserted separately). But the moment a choice is gated at all,
          // the gate has to be a real memory: gating a line on the biome or
          // the weather would put words in a stranger's mouth about events
          // that never happened.
          if (conditions.isEmpty) continue;
          expect(
            conditions.any(isMemory),
            isTrue,
            reason:
                '${adventure['id']} / ${node['id']}: "${choice['label']}" '
                'is gated, but not on anything the party actually did',
          );
        }
      }
    }
  });

  test('every climax node still resolves for a party with no history', () {
    for (final adventure in loadClimaxAdventures()) {
      for (final node in (adventure['nodes'] as List).cast<Map>()) {
        final choices = (node['choices'] as List).cast<Map>();
        expect(
          choices.where((c) => (c['conditions'] as List? ?? const []).isEmpty),
          isNotEmpty,
          reason:
              '${adventure['id']} / ${node['id']} has no unconditioned way out '
              '— a party the world does not know would be stuck',
        );
      }
    }
  });

  test('a climax cannot fire early or repeat', () async {
    final cards = await const CardRepository().loadCards();
    final triggers = cards.where(
      (c) => c.actions
          .whereType<StartAdventureAction>()
          .any((a) => climaxes.contains(a.adventureId)),
    );

    expect(triggers, isNotEmpty);
    for (final trigger in triggers) {
      // Once per campaign: a summing-up that repeats stops being one.
      expect(
        trigger.conditions.whereType<AdventureNotCompletedCondition>(),
        isNotEmpty,
        reason: '${trigger.id} can fire twice',
      );
      // And it must be *earned*: either late in the journey, or triggered by
      // a memory that has had time to travel.
      final lateEnough = trigger.conditions
          .whereType<MinimumStepCondition>()
          .any((c) => c.steps >= 10);
      final oldEnough =
          trigger.conditions.whereType<MinimumStepsSinceFlagCondition>().isNotEmpty;
      expect(
        lateEnough || oldEnough,
        isTrue,
        reason: '${trigger.id} can happen before there is a story to sum up',
      );
    }
  });

  test('the climaxes between them read a wide slice of the campaign', () {
    final flags = <String>{};
    void walk(Object? node) {
      if (node is Map<String, dynamic>) {
        if (isMemory(node)) {
          flags.add(
            (node['flag'] ?? node['key'] ?? node['originId'] ?? node['itemId'] ??
                    node['effectId'] ?? node['adventureId'])
                .toString(),
          );
        }
        node.values.forEach(walk);
      } else if (node is List) {
        node.forEach(walk);
      }
    }

    loadClimaxAdventures().forEach(walk);
    walk(jsonDecode(
      File('assets/data/cards/campaign_climaxes.json').readAsStringSync(),
    ));

    // A summing-up that listens to only a handful of things is not a
    // summing-up. Floor, not target — raise it when a wave widens the net.
    expect(flags.length, greaterThanOrEqualTo(20), reason: 'reads: $flags');
  });
}
