/// Builds an id-keyed map, failing fast on a duplicate id instead of
/// silently letting the later entry clobber the earlier one.
///
/// With content split across many independently-authored JSON packs, a
/// copy-pasted item/effect/node definition that keeps its source's id is a
/// realistic mistake — and a silent overwrite means whichever pack happened
/// to load last quietly wins, which is a much harder bug to track down than
/// a startup crash naming the exact duplicate id.
///
/// Lives at the top of `game_engine/` (not under `data/`) because both the
/// data layer (repositories deduping across content packs) and the model
/// layer (`Adventure` deduping node ids within itself) need it.
Map<String, T> uniqueById<T>(
  Iterable<T> items,
  String Function(T item) idOf,
  String entityName,
) {
  final map = <String, T>{};
  for (final item in items) {
    final id = idOf(item);
    if (map.containsKey(id)) {
      throw StateError(
        'Duplicate $entityName id "$id" — every $entityName must have a unique id across all content packs.',
      );
    }
    map[id] = item;
  }
  return map;
}
