import '../../core/constants/asset_paths.dart';
import '../logic/effect_catalog.dart';
import '../models/models.dart';
import '../unique_by_id.dart';
import 'json_asset_loader.dart';

/// Loads every effect pack under `assets/data/effects/` into an
/// [EffectCatalog].
final class EffectRepository {
  final JsonAssetLoader _loader;

  const EffectRepository([this._loader = const JsonAssetLoader()]);

  Future<EffectCatalog> loadCatalog() async {
    final raw = await _loader.loadArraysUnder(AssetPaths.effectsDirectory);
    final effects = raw.map(
      (e) => GameEffect.fromJson(e as Map<String, dynamic>),
    );
    return EffectCatalog(uniqueById(effects, (effect) => effect.id, 'effect'));
  }
}
