/// Which time of year this journey takes place in — a third, independent
/// world modifier alongside [Biome] (where) and `Weather` (what's happening
/// right now). Unlike weather, a season never changes mid-match: it's
/// rolled once when the game starts (see `GameController`'s constructor)
/// and stays fixed for the whole journey, so unlike `Weather` there is no
/// "how long has it held" dwell counter and no action to change it —
/// nothing in the engine ever sets this after the initial roll. Plain enum
/// with no catalog of its own, same reasoning as `Weather`/`JourneyPhase`:
/// four fixed states are enough, and every one of them is just another
/// filter content already knows how to react to.
enum Season {
  spring,
  summer,
  autumn,
  winter;

  static Season fromJson(String value) => Season.values.byName(value);

  String toJson() => name;
}
