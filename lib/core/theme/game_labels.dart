import '../../game_engine/models/models.dart';

/// Russian display names for engine enums that the player sees spelled out
/// rather than only as a color or an icon.
///
/// Everywhere else in the app a rarity is *shown* (a tinted frame, a glow
/// ramp — see `AppColors`) rather than named, which is right for a card
/// flying past mid-game. The player profile is the one place that explains
/// instead of signalling, so it needs the words. Same reasoning for
/// [OriginCategory], which until now existed only as content-authoring
/// metadata and was never surfaced at all.
String rarityLabel(Rarity rarity) => switch (rarity) {
  Rarity.common => 'Обычное',
  Rarity.uncommon => 'Необычное',
  Rarity.rare => 'Редкое',
  Rarity.epic => 'Эпическое',
  Rarity.legendary => 'Легендарное',
};

/// Phrased as the *kind of thing* an origin is, in the same voice the design
/// doc uses for the three categories — a life path is something you did, a
/// true nature is something you are, a hard past is something that happened
/// to you.
String originCategoryLabel(OriginCategory category) => switch (category) {
  OriginCategory.lifePath => 'жизненный путь',
  OriginCategory.trueNature => 'истинная природа',
  OriginCategory.hardPast => 'тяжёлое прошлое',
};

/// Origin names carry a leading emoji in content (`🐉 Драконорождённый`) —
/// it was the icon, back when nothing else stood in for one. Screens that
/// draw a real mark for the origin strip it here, so a glyph is not doubled
/// by a tiny cartoon of itself; the roster badge, which has no mark of its
/// own, still shows the name exactly as authored. The data is untouched
/// either way.
String originDisplayName(String name) {
  final firstSpace = name.indexOf(' ');
  if (firstSpace <= 0) return name;
  final head = name.substring(0, firstSpace);
  final isEmoji = head.runes.every((rune) => rune > 0x2000);
  return isEmoji ? name.substring(firstSpace + 1) : name;
}
