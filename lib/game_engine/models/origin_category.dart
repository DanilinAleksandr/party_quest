/// Which of the three broad senses an [Origin] belongs to. Originally
/// `Origin.rarity` alone stood in for this (common/uncommon = life path,
/// rare and up = true nature) — that stopped working once a third category,
/// [hardPast], needed to sit at the same rarity tier as some true-nature
/// origins without being one, so this is now its own explicit field.
enum OriginCategory {
  /// Who the character was before the journey — an ordinary profession
  /// (merchant, hunter, alchemist). Small stat nudge, mostly flavor.
  lifePath,

  /// Not a profession — heritage, old blood, or something mystical about
  /// who the character *is*. Higher rarity within this category means a
  /// deeper, more exclusive world reaction, not a bigger stat nudge.
  trueNature,

  /// A difficult life before the journey that left real, mechanical scars —
  /// see the design doc's "Тяжёлое прошлое" origins. Unlike the other two
  /// categories, these don't balance to a neutral +1/+1/-1: the drawbacks
  /// are real, but so are the unique doors they open. Never "bad" origins,
  /// just origins whose cost is paid in stats instead of narrative weight.
  hardPast;

  static OriginCategory fromJson(String value) => OriginCategory.values.byName(value);

  String toJson() => name;
}
