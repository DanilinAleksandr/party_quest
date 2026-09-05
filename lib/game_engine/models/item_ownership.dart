/// Whether an [InventoryItem], once granted, belongs to one player or to
/// the whole party — see `GameState.partyInventory`. A talisman is carried
/// by whoever received it; a map is spread out on the table for everyone.
enum ItemOwnership {
  personal,
  shared;

  static ItemOwnership fromJson(String value) =>
      ItemOwnership.values.byName(value);

  String toJson() => name;
}
