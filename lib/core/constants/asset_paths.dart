/// Paths to bundled data asset *directories*. Game content lives as data
/// files, not Dart code, and each directory can hold as many JSON packs as
/// needed — `JsonAssetLoader` discovers and merges every file under a
/// directory automatically, so shipping a new content pack (a themed set of
/// cards, a new batch of items, a daily-event pack) is "add a file", not
/// "edit a manifest".
abstract final class AssetPaths {
  static const String cardsDirectory = 'assets/data/cards/';
  static const String itemsDirectory = 'assets/data/items/';
  static const String effectsDirectory = 'assets/data/effects/';
  static const String adventuresDirectory = 'assets/data/adventures/';
  static const String biomesDirectory = 'assets/data/biomes/';
  static const String originsDirectory = 'assets/data/origins/';
}
