import '../../core/constants/asset_paths.dart';
import '../logic/adventure_catalog.dart';
import '../models/models.dart';
import '../unique_by_id.dart';
import 'json_asset_loader.dart';

/// Loads every adventure pack under `assets/data/adventures/` into an
/// [AdventureCatalog].
final class AdventureRepository {
  final JsonAssetLoader _loader;

  const AdventureRepository([this._loader = const JsonAssetLoader()]);

  Future<AdventureCatalog> loadCatalog() async {
    final raw = await _loader.loadArraysUnder(AssetPaths.adventuresDirectory);
    final adventures = raw.map(
      (e) => Adventure.fromJson(e as Map<String, dynamic>),
    );
    return AdventureCatalog(uniqueById(adventures, (a) => a.id, 'adventure'));
  }
}
