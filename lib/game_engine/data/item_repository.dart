import '../../core/constants/asset_paths.dart';
import '../logic/item_catalog.dart';
import '../models/models.dart';
import '../unique_by_id.dart';
import 'json_asset_loader.dart';

/// Loads every item pack under `assets/data/items/` into an [ItemCatalog].
final class ItemRepository {
  final JsonAssetLoader _loader;

  const ItemRepository([this._loader = const JsonAssetLoader()]);

  Future<ItemCatalog> loadCatalog() async {
    final raw = await _loader.loadArraysUnder(AssetPaths.itemsDirectory);
    final items = raw.map(
      (e) => InventoryItem.fromJson(e as Map<String, dynamic>),
    );
    return ItemCatalog(uniqueById(items, (item) => item.id, 'item'));
  }
}
