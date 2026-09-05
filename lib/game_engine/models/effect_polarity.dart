/// Whether an active effect helps or hurts the player it is attached to.
/// Drives how [Player.blessings] / [Player.curses] are derived and how the
/// UI could style an effect chip in the future.
enum EffectPolarity {
  positive,
  negative;

  static EffectPolarity fromJson(String value) =>
      EffectPolarity.values.byName(value);

  String toJson() => name;
}
