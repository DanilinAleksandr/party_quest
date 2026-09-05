/// Which broad stretch of the match the party is currently in. Exists
/// purely as a content filter (see `CardCatalog.eligibleCards` and
/// `CardTag.prologue`) — nothing else about how a step resolves changes
/// with phase, the same "define once, react via ordinary conditions/tags"
/// pattern every other system in this engine uses.
///
/// [prologue] is the neutral departure stretch before the first biome is
/// chosen — see the design doc's "начало путешествия" note. [epilogue] is
/// reserved, unused for now: the same filtering mechanism this enum
/// enables for [prologue] is meant to cover a future closing stretch too,
/// without inventing a second parallel concept when that's actually
/// designed.
enum JourneyPhase {
  prologue,
  journey,
  epilogue;

  static JourneyPhase fromJson(String value) => JourneyPhase.values.byName(value);

  String toJson() => name;
}
