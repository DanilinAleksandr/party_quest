import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

GameContext _at({
  required int steps,
  required List<GameCard> cards,
  JourneyPhase phase = JourneyPhase.journey,
  bool inTavern = false,
}) {
  return GameContext(
    state: GameState(
      players: const [
        Player(id: 'p1', name: 'A'),
        Player(id: 'p2', name: 'B'),
      ],
      currentPlayerIndex: 0,
      status: GameStatus.inProgress,
      partySteps: steps,
      phase: phase,
      worldState: inTavern
          ? const WorldState(flags: {'in_tavern': true})
          : const WorldState(),
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
}

GameCard _card(String id, List<CardTag> tags) => GameCard(
  id: id,
  title: 't',
  description: 'd',
  type: CardType.event,
  rarity: Rarity.common,
  weight: 1,
  tags: tags,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final rest = _card('rest', const [CardTag.rest]);
  final road = _card('road', const []);
  final prologue = _card('prologue', const [CardTag.prologue]);
  final tavern = _card('tavern', const [CardTag.tavern]);
  final all = [rest, road, prologue, tavern];

  group('the rest halt', () {
    test('every ${kRestInterval}th step draws from rest content only', () {
      for (final step in [
        kRestInterval,
        kRestInterval * 2,
        kRestInterval * 7,
      ]) {
        final pool = CardCatalog(
          all,
        ).eligibleCards(_at(steps: step, cards: all));
        expect(pool.map((c) => c.id), ['rest'], reason: 'step $step');
      }
    });

    test('rest content is kept out of every other step', () {
      // The half that is easy to forget: a campfire must not befall a party
      // on the road, or the halt stops being an event and becomes a card
      // like any other.
      for (var step = 1; step <= kRestInterval * 3; step++) {
        if (step % kRestInterval == 0) continue;
        final pool = CardCatalog(
          all,
        ).eligibleCards(_at(steps: step, cards: all));
        expect(
          pool.map((c) => c.id),
          isNot(contains('rest')),
          reason: 'step $step',
        );
        expect(pool.map((c) => c.id), contains('road'), reason: 'step $step');
      }
    });

    test('step zero is not a halt', () {
      final pool = CardCatalog(all).eligibleCards(_at(steps: 0, cards: all));
      expect(pool.map((c) => c.id), isNot(contains('rest')));
      expect(pool.map((c) => c.id), contains('road'));
    });

    test('the prologue and the tavern outrank it', () {
      // Neither has rest content, so a halt inside one would leave nothing
      // eligible at all — `drawEligibleCard` throws on an empty pool.
      final inPrologue = CardCatalog(all).eligibleCards(
        _at(steps: kRestInterval, cards: all, phase: JourneyPhase.prologue),
      );
      expect(inPrologue.map((c) => c.id), ['prologue']);

      final inTavern = CardCatalog(
        all,
      ).eligibleCards(_at(steps: kRestInterval, cards: all, inTavern: true));
      expect(inTavern.map((c) => c.id), ['tavern']);
    });
  });

  group('the shipped rest pack', () {
    test('every rest card carries the tag, and only rest cards do', () async {
      final cards = await const CardRepository().loadCards();
      final tagged = cards.where((c) => c.hasTag(CardTag.rest)).toList();

      expect(tagged, hasLength(8));
      expect(tagged.every((c) => c.id.startsWith('rest_')), isTrue);
      expect(
        cards.where((c) => c.id.startsWith('rest_') && !c.hasTag(CardTag.rest)),
        isEmpty,
      );
    });

    test('the halt always has something to draw', () async {
      // A rest step with an empty pool is a crash, not a quiet miss, so the
      // pack has to hold at least one card with no conditions on it.
      final cards = await const CardRepository().loadCards();
      final unconditional = cards.where(
        (c) => c.hasTag(CardTag.rest) && c.conditions.isEmpty,
      );
      expect(unconditional, isNotEmpty);
    });
  });
}
