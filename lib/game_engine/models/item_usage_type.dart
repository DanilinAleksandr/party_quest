/// Whether an [InventoryItem] is triggered by the player or by the engine.
enum ItemUsageType {
  /// The player chooses when to use it (future "use item" UI).
  manual,

  /// The engine applies its effect automatically once granted.
  automatic;

  static ItemUsageType fromJson(String value) =>
      ItemUsageType.values.byName(value);

  String toJson() => name;
}
