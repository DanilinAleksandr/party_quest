import '../../core/constants/asset_paths.dart';
import '../logic/biome_catalog.dart';
import '../models/models.dart';
import '../unique_by_id.dart';
import 'json_asset_loader.dart';

/// Loads every biome pack under `assets/data/biomes/` into a [BiomeCatalog].
final class BiomeRepository {
  final JsonAssetLoader _loader;

  const BiomeRepository([this._loader = const JsonAssetLoader()]);

  Future<BiomeCatalog> loadCatalog() async {
    final raw = await _loader.loadArraysUnder(AssetPaths.biomesDirectory);
    final biomes = raw.map((e) => Biome.fromJson(e as Map<String, dynamic>));
    return BiomeCatalog(uniqueById(biomes, (b) => b.id, 'biome'));
  }
}
