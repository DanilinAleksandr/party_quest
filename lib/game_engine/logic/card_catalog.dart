import '../context/game_context.dart';
import '../models/models.dart';

/// How often the party stops to rest, in `GameState.partySteps`.
///
/// The halt is derived from the step count rather than stored: every tenth
/// step *is* a rest, so there is nothing to keep in sync and nothing that
/// can drift out of it.
const int kRestInterval = 10;

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
  ///
  /// The rest halt is the same shape once more, keyed off the step count:
  /// every `kRestInterval`th step the party sits down, and only
  /// `CardTag.rest` content is eligible. It differs from the other two in
  /// running *both* ways — a rest card is also excluded from every ordinary
  /// step, because a campfire is not something that befalls a party on the
  /// road. That symmetry is what lets the halt be scheduled without a
  /// condition on either side of it.
  ///
  /// The prologue and the tavern take precedence over it. A campfire on the
  /// road is the wrong picture inside a tavern, and the halt is not
  /// something the player was ever promised — a missed one is invisible,
  /// where a rest card in the wrong place is not.
  ///
  /// And the halt only happens when there is something to halt for: if no
  /// rest card comes through the filter, the step falls back to the
  /// ordinary pool. Otherwise any card set without rest content — a test
  /// fixture, a themed pack, a mode whose rarity pool happens to exclude
  /// them — would hit an empty pool on its tenth step and take the step
  /// down with it. A scheduled event that can empty the deck is worse than
  /// no scheduled event.
  List<GameCard> eligibleCards(
    GameContext context, {
    bool Function(GameCard card)? extraFilter,
  }) {
    final inPrologue = context.state.phase == JourneyPhase.prologue;
    final inTavern = context.state.worldState.flag('in_tavern');
    final steps = context.state.partySteps;
    final atHalt =
        !inPrologue && !inTavern && steps > 0 && steps % kRestInterval == 0;

    List<GameCard> pool({required bool resting}) => allCards
        .where((card) {
          if (!context.mode.allowedRarities.contains(card.rarity)) return false;
          if (inPrologue && !card.hasTag(CardTag.prologue)) return false;
          if (inTavern && !card.hasTag(CardTag.tavern)) return false;
          if (resting != card.hasTag(CardTag.rest)) return false;
          final conditionsMet = card.conditions.every(
            (condition) => condition.isSatisfied(context),
          );
          return conditionsMet && (extraFilter?.call(card) ?? true);
        })
        .toList(growable: false);

    if (!atHalt) return pool(resting: false);
    final resting = pool(resting: true);
    return resting.isEmpty ? pool(resting: false) : resting;
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
