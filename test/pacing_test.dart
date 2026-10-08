import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/features/settings/application/walk_settings.dart';
import 'package:drinking_quest/game_engine/data/adventure_repository.dart';
import 'package:drinking_quest/game_engine/data/biome_repository.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/data/effect_repository.dart';
import 'package:drinking_quest/game_engine/data/item_repository.dart';
import 'package:drinking_quest/game_engine/data/origin_repository.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

GameCard _card(String id, {List<GameCondition> conditions = const []}) =>
    GameCard(
      id: id,
      title: id,
      description: 'd',
      type: CardType.event,
      rarity: Rarity.common,
      weight: 1,
      conditions: conditions,
    );

GameController _fixture(List<GameCard> cards) => GameController(
  playerNames: const ['A'],
  cards: cards,
  itemCatalog: const ItemCatalog({}),
  effectCatalog: const EffectCatalog({}),
  adventureCatalog: const AdventureCatalog({}),
  biomeCatalog: const BiomeCatalog({}),
  originCatalog: const OriginCatalog({}),
  seed: 3,
  journeySteps: null,
  skipPrologue: true,
);

/// Plays [cards] matches of real content, calling [onDraw] with every card
/// drawn (and how many were drawn before it), before it is resolved, and
/// [onResolved] after.
Future<void> _play({
  required int seeds,
  required int cards,
  int restInterval = kRestInterval,
  required void Function(GameController c, GameCard card, int drawn) onDraw,
  void Function(GameController c, GameCard card, int drawn)? onResolved,
}) async {
  final all = await const CardRepository().loadCards();
  final items = await const ItemRepository().loadCatalog();
  final effects = await const EffectRepository().loadCatalog();
  final adventures = await const AdventureRepository().loadCatalog();
  final biomes = await const BiomeRepository().loadCatalog();
  final origins = await const OriginRepository().loadCatalog();
  for (var seed = 0; seed < seeds; seed++) {
    final pick = Random(seed);
    final c = GameController(
      playerNames: const ['A', 'B', 'C', 'D'],
      cards: all,
      itemCatalog: items,
      effectCatalog: effects,
      adventureCatalog: adventures,
      biomeCatalog: biomes,
      originCatalog: origins,
      seed: seed,
      journeySteps: null,
      restInterval: restInterval,
    );
    for (
      var drawn = 0, guard = 0;
      drawn < cards && guard < 4 * cards;
      guard++
    ) {
      c.takeStep();
      if (c.state.pendingParticipantSelection != null) {
        c.resolveParticipant(c.state.players.first.id);
      }
      final card = c.state.pendingCard;
      if (card == null) continue;
      onDraw(c, card, drawn);
      final n = card.choices.length;
      c.resolveCard(choiceIndex: n > 0 ? pick.nextInt(n) : null);
      for (var k = 0; c.state.pendingAdventureNode != null && k < 30; k++) {
        final m = c.state.pendingAdventureNode!.choices.length;
        c.resolveAdventureChoice(m == 0 ? 0 : pick.nextInt(m));
      }
      onResolved?.call(c, card, drawn);
      drawn++;
      if (c.state.status != GameStatus.inProgress) break;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the no-repeat window', () {
    test('keeps a card out for $kNoRepeatWindow cards', () {
      final c = _fixture([for (var i = 0; i < 40; i++) _card('c$i')]);
      final seen = <String, int>{};
      for (var i = 0; i < 300; i++) {
        c.takeStep();
        final id = c.state.pendingCard!.id;
        final last = seen[id];
        if (last != null) {
          expect(i - last, greaterThan(kNoRepeatWindow), reason: '$id at $i');
        }
        seen[id] = i;
        c.resolveCard();
      }
    });

    test('narrows rather than leaving nothing to draw, oldest first', () {
      final c = _fixture([for (var i = 0; i < 4; i++) _card('c$i')]);
      final order = <String>[];
      for (var i = 0; i < 12; i++) {
        c.takeStep();
        order.add(c.state.pendingCard!.id);
        c.resolveCard();
      }
      // Four cards, a window of three at the narrowest that still leaves one:
      // the same four, round and round.
      for (var i = 4; i < 12; i++) {
        expect(order[i], order[i - 4], reason: '$i');
      }
    });

    test('in play: no card the party met in the last $kNoRepeatWindow, '
        'save the ways in and out of places and the halt', () async {
      final lastSeen = <String, int>{};
      await _play(
        seeds: 120,
        cards: 150,
        onDraw: (c, card, drawn) {
          if (drawn == 0) lastSeen.clear();
          final last = lastSeen[card.id];
          if (last != null && !card.recurs) {
            expect(
              drawn - last,
              greaterThan(kNoRepeatWindow),
              reason: '${card.id} at $drawn',
            );
          }
          lastSeen[card.id] = drawn;
        },
      );
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  for (final interval in [kMinRestInterval, kRestInterval]) {
    test('in play: halts at least $interval steps apart, counted from the '
        'last one\'s end', () async {
      int? leftAt;
      var halts = 0;
      await _play(
        seeds: 80,
        cards: 150,
        restInterval: interval,
        onDraw: (c, card, drawn) {
          if (drawn == 0) leftAt = null;
          if (!card.beginsRest) return;
          halts++;
          if (leftAt != null) {
            expect(
              c.state.partySteps - leftAt!,
              greaterThanOrEqualTo(interval),
              reason: '${card.id} at $drawn',
            );
          }
        },
        onResolved: (c, card, drawn) {
          if (card.hasTag(CardTag.rest) &&
              !c.state.worldState.flag('in_rest')) {
            leftAt = c.state.partySteps;
          }
        },
      );
      expect(halts, greaterThan(200));
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
