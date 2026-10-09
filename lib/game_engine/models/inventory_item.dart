import 'game_action.dart';
import 'item_aura.dart';
import 'item_ownership.dart';
import 'item_usage_type.dart';
import 'rarity.dart';

/// A definition of an item that can be granted to a player. Instances held
/// by a [Player] currently reference this same immutable definition — items
/// carry no per-instance state in the MVP, so no separate "item instance"
/// wrapper is needed yet.
final class InventoryItem {
  final String id;
  final String name;
  final String description;
  final Rarity rarity;
  final ItemUsageType usageType;

  /// One-time (consumed on use) vs. a permanent item that stays in the
  /// inventory.
  final bool isConsumable;

  /// Whether granting this item adds it to one player's inventory or to
  /// `GameState.partyInventory` — see [ItemOwnership]. Defaults to
  /// [ItemOwnership.personal], so every item authored before this field
  /// existed keeps behaving exactly as before.
  final ItemOwnership ownership;

  /// What happens when the item is used (manually by the player, or
  /// automatically by the engine, per [usageType]).
  final List<GameAction> useActions;

  /// A curse or a blessing this particular thing carries, unseen — see
  /// [ItemAura]. Null for nearly everything.
  final ItemAura? aura;

  /// Picked up on the road from a find — what a shaman wants to hold.
  final bool found;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.description,
    required this.rarity,
    required this.usageType,
    required this.isConsumable,
    this.ownership = ItemOwnership.personal,
    this.useActions = const [],
    this.aura,
    this.found = false,
  });

  /// This thing, picked up from a find.
  InventoryItem asFound() => InventoryItem(
    id: id,
    name: name,
    description: description,
    rarity: rarity,
    usageType: usageType,
    isConsumable: isConsumable,
    ownership: ownership,
    useActions: useActions,
    aura: aura,
    found: true,
  );

  /// This thing, carrying [aura] — or none.
  InventoryItem withAura(ItemAura? aura) => InventoryItem(
    id: id,
    name: name,
    description: description,
    rarity: rarity,
    usageType: usageType,
    isConsumable: isConsumable,
    ownership: ownership,
    useActions: useActions,
    aura: aura,
    found: found,
  );

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    rarity: Rarity.fromJson(json['rarity'] as String),
    usageType: ItemUsageType.fromJson(json['usageType'] as String),
    isConsumable: json['isConsumable'] as bool,
    ownership: json['ownership'] == null
        ? ItemOwnership.personal
        : ItemOwnership.fromJson(json['ownership'] as String),
    useActions: GameAction.listFromJson(json['useActions'] as List<dynamic>?),
    aura: json['aura'] == null
        ? null
        : ItemAura.fromJson(json['aura'] as Map<String, dynamic>),
    found: json['found'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'rarity': rarity.toJson(),
    'usageType': usageType.toJson(),
    'isConsumable': isConsumable,
    'ownership': ownership.toJson(),
    'useActions': GameAction.listToJson(useActions),
    if (aura != null) 'aura': aura!.toJson(),
    if (found) 'found': true,
  };
}
