import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

/// Guards the design doc's target content mix (60–70% quick / 20–30% choice
/// / 10–15% full adventures / 1–3% legendary, all by draw-weight share) so
/// future content additions don't quietly drift the game's pacing — e.g.
/// dumping in twenty more quick filler cards without weighing choices and
/// adventures up to match would make most turns predictable again, which is
/// exactly what the design doc says to avoid.
///
/// Legendary must stay genuinely rare even as the roster of legendary NPCs
/// grows (6 biomes x 2 NPCs each): a player should not be guaranteed to see
/// a legendary event even once in a full game. New legendary cards are kept
/// low-weight (1, vs. 2 for the original pre-biome legendary cards) so
/// adding more of them doesn't inflate the overall share.
///
/// Bounds are intentionally wider than the doc's own range: this is a
/// regression guard against gross imbalance, not a precise tuning target —
/// hand-tuning exact percentages belongs in a design review, not a unit
/// test assertion.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'draw-weight distribution stays within the target content mix',
    () async {
      final cards = await const CardRepository().loadCards();
      final totalWeight = cards.fold<int>(0, (sum, c) => sum + c.weight);

      int weightWhere(bool Function(GameCard) test) =>
          cards.where(test).fold<int>(0, (sum, c) => sum + c.weight);

      bool isAdventure(GameCard c) =>
          c.actions.any((a) => a is StartAdventureAction);
      bool isChoice(GameCard c) => c.hasChoices;
      bool isQuick(GameCard c) => !isChoice(c) && !isAdventure(c);

      double pct(int w) => w * 100 / totalWeight;

      final quickPct = pct(weightWhere(isQuick));
      final choicePct = pct(weightWhere(isChoice));
      final adventurePct = pct(weightWhere(isAdventure));
      final legendaryPct = pct(
        weightWhere((c) => c.rarity == Rarity.legendary),
      );

      expect(
        quickPct,
        inInclusiveRange(55, 75),
        reason: 'quick-event share drifted out of range',
      );
      expect(
        choicePct,
        inInclusiveRange(15, 35),
        reason: 'choice-card share drifted out of range',
      );
      expect(
        adventurePct,
        inInclusiveRange(7, 20),
        reason: 'adventure share drifted out of range',
      );
      expect(
        legendaryPct,
        inInclusiveRange(0.5, 4),
        reason: 'legendary share drifted out of range',
      );
    },
  );
}
