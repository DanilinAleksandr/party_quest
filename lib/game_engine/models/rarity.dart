/// Shared rarity scale. The design doc lists "CardRarity" and item rarity
/// separately, but they are the same concept applied to two entities, so a
/// single enum is reused for both [GameCard] and [InventoryItem] rather than
/// keeping two identical enums in sync by hand.
enum Rarity {
  common,
  uncommon,
  rare,
  epic,
  legendary;

  static Rarity fromJson(String value) => Rarity.values.byName(value);

  String toJson() => name;
}
