/// Player characteristics. Nothing in the MVP reads these yet, but cards can
/// already modify them, so future features (skill checks, item requirements,
/// duel odds) can build on live data instead of a migration.
///
/// Adding a new stat is a one-line enum change — [PlayerStats] stores values
/// in a map, so no model or serialization code needs to change alongside it.
enum StatType {
  strength,
  luck,
  charisma,
  endurance,
  attentiveness,
  cunning;

  static StatType fromJson(String value) => StatType.values.byName(value);

  String toJson() => name;
}
