import '../context/game_context.dart';
import '../models/models.dart';

/// The full pool of cards a match can draw from, plus condition-aware,
/// weighted selection.
///
/// Filtering happens fresh on every draw rather than once at game start:
/// eligibility depends on live state (current step count, who holds what
/// item, which effects are active), so a fixed "deck" pre-filtered at
/// setup would go stale the moment the game state changes. With a few
/// thousand cards this is a single O(n) scan per turn — cheap at
/// human-paced, turn-by-turn draw rates; if that ever stops being true,
/// pre-indexing cards by tag/type is a change local to this class.
final class CardCatalog {
  final List<GameCard> allCards;

  const CardCatalog(this.allCards);

  /// Cards whose [GameCard.conditions] all currently hold and whose rarity
  /// is in the active [GameMode]'s allowed pool. [extraFilter], if given, is
  /// applied on top — e.g. a future daily-challenge draw that only wants
  /// `CardTag.luck`-tagged cards.
  ///
  /// Rarity gating is unconditional (not one more opt-in [GameCondition])
  /// because it is a property of the *mode*, not of individual content — a
  /// mode that disables legendary drops should disable them for every
  /// legendary card, not only the ones an author remembered to mark.
  ///
  /// Phase gating is the same kind of unconditional, mode-like filter:
  /// while `GameState.phase` is `JourneyPhase.prologue`, only
  /// `CardTag.prologue`-tagged cards are eligible — a content author who
  /// wants their card to appear during prologue tags it, but doesn't need
  /// to remember a `notInPhase` condition on every other card to keep it
  /// *out*. Outside prologue this filter is a no-op — every card stays
  /// eligible exactly as before phases existed.
  ///
  /// Tavern gating is the same shape again, keyed off
  /// `WorldState.flag('in_tavern')` instead of `JourneyPhase`: the tavern
  /// is a detour inside whatever real biome the party is already in, not a
  /// rotation biome of its own, so while the party is "inside" it, only
  /// `CardTag.tavern`-tagged content is eligible — road events, the
  /// traveling merchant, and real biome-transition cards are excluded for
  /// free, without needing an exclusion condition added to any of them.
  List<GameCard> eligibleCards(
    GameContext context, {
    bool Function(GameCard card)? extraFilter,
  }) {
    final inPrologue = context.state.phase == JourneyPhase.prologue;
    final inTavern = context.state.worldState.flag('in_tavern');
    return allCards
        .where((card) {
          if (!context.mode.allowedRarities.contains(card.rarity)) return false;
          if (inPrologue && !card.hasTag(CardTag.prologue)) return false;
          if (inTavern && !card.hasTag(CardTag.tavern)) return false;
          final conditionsMet = card.conditions.every(
            (condition) => condition.isSatisfied(context),
          );
          return conditionsMet && (extraFilter?.call(card) ?? true);
        })
        .toList(growable: false);
  }

  /// Draws one eligible card, weighted by [GameCard.weight].
  ///
  /// Throws if nothing is eligible — that is a content authoring bug (a
  /// pack with no unconditional fallback cards), not a state the game
  /// should silently paper over.
  GameCard drawEligibleCard(
    GameContext context, {
    bool Function(GameCard card)? extraFilter,
  }) {
    final eligible = eligibleCards(context, extraFilter: extraFilter);
    if (eligible.isEmpty) {
      throw StateError('No eligible cards to draw for the current game state.');
    }
    return _weightedPick(eligible, context.random.nextInt);
  }

  GameCard _weightedPick(List<GameCard> cards, int Function(int max) nextInt) {
    final totalWeight = cards.fold<int>(0, (sum, card) => sum + card.weight);
    var roll = nextInt(totalWeight);
    for (final card in cards) {
      if (roll < card.weight) return card;
      roll -= card.weight;
    }
    return cards.last;
  }
}
