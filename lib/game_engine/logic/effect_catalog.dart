import '../models/models.dart';

/// Lookup table of every [GameEffect] definition, keyed by id, resolved once
/// from `assets/data/effects/` at startup. Mirrors [ItemCatalog] — blessings
/// and curses are defined once here and referenced by id from card/item
/// actions instead of being duplicated inline on every card that grants
/// them.
final class EffectCatalog {
  final Map<String, GameEffect> _byId;

  const EffectCatalog(this._byId);

  bool contains(String id) => _byId.containsKey(id);

  Iterable<GameEffect> get all => _byId.values;

  GameEffect byId(String id) {
    final effect = _byId[id];
    if (effect == null) {
      throw StateError('Unknown effect id referenced by a card/item: $id');
    }
    return effect;
  }
}
