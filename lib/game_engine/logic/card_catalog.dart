import '../context/game_context.dart';
import '../models/models.dart';

/// How often the party stops to rest, in `GameState.partySteps`, unless the
/// table chose otherwise — this is the default for
/// `GameContext.restInterval`, which is what the catalog actually reads.
///
/// The schedule is derived from the step count rather than stored: every
/// tenth step the party sits down, so there is nothing to keep in sync and
/// nothing that can drift out of it. How long the halt then lasts is not
/// scheduled at all — that is the `in_rest` flag's business, exactly as the
/// tavern's length is `in_tavern`'s.
const int kRestInterval = 10;

/// The most village cards a stay in a village holds; after that, only the
/// ways out are drawn. The ways out are weighted for three to five, but a
/// weight is a likelihood, and this is a promise.
const int kVillageMostCards = 7;

/// How many cards must pass before the same card can be drawn again —
/// unless it [GameCard.recurs]. A pool too narrow to keep to it (the
/// prologue's, or a themed pack's) narrows the window rather than drawing
/// from nothing: see [CardCatalog.eligibleCards].
const int kNoRepeatWindow = 25;

/// The narrower windows tried, in order, when the full one leaves nothing
/// to draw. The last is no window at all.
const List<int> _fallbackWindows = [kNoRepeatWindow, 10, 3, 0];

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
  /// The rest halt is the tavern's pattern again, `in_rest` for `in_tavern`
  /// — while the flag is set only `CardTag.rest` content is eligible, the
  /// party's `partySteps` is frozen, and a departure card carrying the
  /// `in_rest = false` action is what ends it. The one difference is how it
  /// *starts*: the tavern is entered by chance, on a weighted card that
  /// merely becomes eligible after seven turns in a biome, while the halt
  /// is due on a fixed schedule and has to actually happen.
  ///
  /// So on a due step the pool narrows to the cards that begin a halt —
  /// identified by the action they carry rather than by id or a tag of
  /// their own, so a second arrival variant (the tavern has two) drops into
  /// the content with no engine change. That test runs both ways as well:
  /// an arrival card is *only* drawable on a due step. Being forced when due
  /// and carrying no conditions of its own, it would otherwise be eligible
  /// on every ordinary step too, and the party would pitch camp whenever the
  /// weighting felt like it.
  ///
  /// The rest tag runs both ways, unlike the tavern's: rest content is also
  /// kept off every ordinary step. The tavern does not need that because
  /// each of its 84 cards carries a `worldFlagSet: in_tavern` condition of
  /// its own; doing it here in one line keeps eight campfire cards from
  /// needing eight copies of the same condition.
  ///
  /// A village is the halt's pattern once more, `in_village`, both ways:
  /// inside, only `CardTag.village` content; outside, none of it. A halt
  /// never begins in one, and none is lost to one: the steps stand still in
  /// a village, so the schedule cannot come due there, and a due step is
  /// the halt's own, so no village can begin on one. The halt simply comes
  /// after, on the road.
  ///
  /// The prologue and the tavern take precedence, and the schedule waits.
  /// A halt cannot begin inside another detour, and a due step that lands
  /// there simply passes — the player is never told the halt comes every
  /// tenth step, so a late one is invisible, where a campfire pitched in a
  /// tavern is not.
  ///
  /// And the halt only happens when there is something to halt with: with
  /// no arrival card through the filter, the step falls back to the ordinary
  /// pool. Any card set without rest content — a test fixture, a themed
  /// pack, a mode whose rarity pool excludes them — would otherwise hit an
  /// empty pool on its tenth step and take the step down with it.
  ///
  /// And a card drawn within the last [kNoRepeatWindow] cards waits, unless
  /// it [GameCard.recurs]. Where that would leave nothing to draw, the
  /// window narrows step by step down to none, so a repeat happens only
  /// when the pool truly has nothing else — and then the least recent one.
  List<GameCard> eligibleCards(
    GameContext context, {
    bool Function(GameCard card)? extraFilter,
  }) {
    final recent = context.state.recentCards;
    for (final window in _fallbackWindows) {
      final skip = recent
          .skip(recent.length > window ? recent.length - window : 0)
          .toSet();
      final eligible = _eligible(
        context,
        extraFilter: (card) =>
            (card.recurs || !skip.contains(card.id)) &&
            (extraFilter?.call(card) ?? true),
      );
      if (eligible.isNotEmpty || window == 0) return eligible;
    }
    return const [];
  }

  List<GameCard> _eligible(
    GameContext context, {
    required bool Function(GameCard card) extraFilter,
  }) {
    final inPrologue = context.state.phase == JourneyPhase.prologue;
    final inTavern = context.state.worldState.flag('in_tavern');
    final inRest = context.state.worldState.flag('in_rest');
    final inVillage = context.state.worldState.flag('in_village');
    final villageOver =
        inVillage &&
        context.state.worldState.turnsInVillage > kVillageMostCards;
    final steps = context.state.partySteps;
    final restDue =
        !inPrologue &&
        !inTavern &&
        !inRest &&
        !inVillage &&
        steps > 0 &&
        steps % context.restInterval == 0;

    List<GameCard> pool({required bool arrivals, bool capped = true}) =>
        allCards
            .where((card) {
              if (!context.mode.allowedRarities.contains(card.rarity)) {
                return false;
              }
              if (inPrologue && !card.hasTag(CardTag.prologue)) return false;
              if (inTavern && !card.hasTag(CardTag.tavern)) return false;
              if (inRest != card.hasTag(CardTag.rest)) return false;
              if (inVillage != card.hasTag(CardTag.village)) return false;
              // No town to be in yet — see [CardTag.town].
              if (card.hasTag(CardTag.town)) return false;
              if (capped && villageOver && !card.endsVillage) return false;
              if (arrivals != card.beginsRest) return false;
              final conditionsMet = card.conditions.every(
                (condition) => condition.isSatisfied(context),
              );
              return conditionsMet && extraFilter(card);
            })
            .toList(growable: false);

    // A village that has had its fill with no way out through the filter
    // (a card set without exits) keeps to its own content rather than
    // drawing from an empty pool.
    List<GameCard> ordinary() {
      final pooled = pool(arrivals: false);
      return pooled.isEmpty && villageOver
          ? pool(arrivals: false, capped: false)
          : pooled;
    }

    if (!restDue) return ordinary();
    final due = pool(arrivals: true);
    return due.isEmpty ? ordinary() : due;
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
