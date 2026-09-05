import '../models/models.dart';

/// Lookup table of every [Origin] definition, keyed by id, resolved once
/// from `assets/data/origins/` at startup. Mirrors [BiomeCatalog] — same
/// "define once, reference by id" pattern.
final class OriginCatalog {
  final Map<String, Origin> _byId;

  const OriginCatalog(this._byId);

  bool contains(String id) => _byId.containsKey(id);

  Iterable<Origin> get all => _byId.values;

  Origin byId(String id) {
    final origin = _byId[id];
    if (origin == null) {
      throw StateError('Unknown origin id: $id');
    }
    return origin;
  }
}
