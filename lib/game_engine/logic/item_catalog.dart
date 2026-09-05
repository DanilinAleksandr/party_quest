import '../models/models.dart';

/// Lookup table of every [InventoryItem] definition, keyed by id, resolved
/// once from `assets/data/items/` at startup.
final class ItemCatalog {
  final Map<String, InventoryItem> _byId;

  const ItemCatalog(this._byId);

  bool contains(String id) => _byId.containsKey(id);

  Iterable<InventoryItem> get all => _byId.values;

  InventoryItem byId(String id) {
    final item = _byId[id];
    if (item == null) {
      throw StateError('Unknown item id referenced by a card: $id');
    }
    return item;
  }
}
