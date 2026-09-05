import '../../core/constants/asset_paths.dart';
import '../logic/origin_catalog.dart';
import '../models/models.dart';
import '../unique_by_id.dart';
import 'json_asset_loader.dart';

/// Loads every origin pack under `assets/data/origins/` into an
/// [OriginCatalog].
final class OriginRepository {
  final JsonAssetLoader _loader;

  const OriginRepository([this._loader = const JsonAssetLoader()]);

  Future<OriginCatalog> loadCatalog() async {
    final raw = await _loader.loadArraysUnder(AssetPaths.originsDirectory);
    final origins = raw.map((e) => Origin.fromJson(e as Map<String, dynamic>));
    return OriginCatalog(uniqueById(origins, (o) => o.id, 'origin'));
  }
}
