import '../models/models.dart';

/// Lookup table of every [Adventure] definition, keyed by id, resolved once
/// from `assets/data/adventures/` at startup. Mirrors [ItemCatalog] and
/// [EffectCatalog] — the same "define once, reference by id" pattern.
final class AdventureCatalog {
  final Map<String, Adventure> _byId;

  const AdventureCatalog(this._byId);

  bool contains(String id) => _byId.containsKey(id);

  Iterable<Adventure> get all => _byId.values;

  Adventure byId(String id) {
    final adventure = _byId[id];
    if (adventure == null) {
      throw StateError('Unknown adventure id referenced by a card: $id');
    }
    return adventure;
  }
}
