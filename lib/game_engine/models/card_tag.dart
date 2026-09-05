/// Free-form-ish classification for filtering, independent of [CardType].
///
/// Where [CardType] says what a card fundamentally *is* (a duel, a curse, a
/// piece of lore text), tags describe *facets* a card can have regardless of
/// its type — a [CardType.event] card can be tagged both `social` and
/// `risk`; a [CardType.legendary] card is usually also tagged `legendary`.
/// Content packs (daily events, themed packs, a "party mode" that only
/// draws `group`-tagged cards) filter on tags without needing a new
/// [CardType] or engine change.
enum CardTag {
  social,
  drink,
  risk,
  curse,
  blessing,
  duel,
  party,
  strategy,
  luck,
  item,
  group,
  solo,
  legendary,
  epic,

  /// Marks content eligible during `JourneyPhase.prologue` — see
  /// `CardCatalog.eligibleCards`. One of two tags the draw itself actually
  /// consults today; every other tag stays pure classification.
  prologue,

  /// Marks content eligible while `WorldState.flag('in_tavern')` is set —
  /// see `CardCatalog.eligibleCards`. The tavern is a detour inside
  /// whatever real biome the party is already in (not a rotation biome of
  /// its own), so this restricts the draw the same way `prologue` does,
  /// keyed off a `WorldState` flag instead of `JourneyPhase`.
  tavern;

  static CardTag fromJson(String value) => CardTag.values.byName(value);

  String toJson() => name;

  static List<CardTag> listFromJson(List<dynamic>? json) => (json ?? const [])
      .map((e) => CardTag.fromJson(e as String))
      .toList(growable: false);

  static List<String> listToJson(List<CardTag> tags) =>
      tags.map((t) => t.toJson()).toList(growable: false);
}
