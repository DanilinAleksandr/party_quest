import '../models/models.dart';

/// Lookup table of every [Biome] definition, keyed by id, resolved once
/// from `assets/data/biomes/` at startup. Mirrors [ItemCatalog]/
/// [EffectCatalog]/[AdventureCatalog] — same "define once, reference by id"
/// pattern.
final class BiomeCatalog {
  final Map<String, Biome> _byId;

  const BiomeCatalog(this._byId);

  bool contains(String id) => _byId.containsKey(id);

  Iterable<Biome> get all => _byId.values;

  Biome byId(String id) {
    final biome = _byId[id];
    if (biome == null) {
      throw StateError('Unknown biome id: $id');
    }
    return biome;
  }
}
