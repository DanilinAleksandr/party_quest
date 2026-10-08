/// The mark each adventure carries on its dialogs instead of the generic
/// book: what the adventure is *about* — the Order's helm at its outpost,
/// the circle's pentagram over the great witch, the crowned skull in the
/// mausoleum.
///
/// The marks come from game-icons.net (Lorc, Delapouite; CC BY 3.0), the
/// library the origins and the coin already use, so they share a line.
/// An adventure missing here keeps the book.
const Map<String, String> kAdventureIcons = {
  'abandoned_tavern': 'tavern-sign',
  'ancient_forest_spirit': 'beech',
  'ancient_tomb': 'crypt-entrance',
  'bandit_camp': 'hood',
  'climax_fair': 'juggler',
  'climax_feast': 'hot-meal',
  'climax_funeral': 'coffin',
  'climax_trial': 'scales',
  'climax_village_council': 'village',
  'coast_shipwreck': 'ship-wreck',
  'desert_warlord': 'scorpion',
  'dragon': 'dragon-head',
  'drunkard_temptation': 'brandy-bottle',
  'forest_altar': 'star-altar',
  'graveyard_will_o_wisp': 'spark-spirit',
  'great_witch': 'pentagram-rose',
  'king_of_the_dead': 'crowned-skull',
  'legendary_cardsharp': 'poker-hand',
  'mountains_cave': 'cave-entrance',
  'paladin_outpost': 'visored-helm',
  'pharaoh': 'pharoah',
  'pirate_captain': 'pirate-captain',
  'tavern_keeper': 'beer-stein',
  'traveling_merchant': 'swap-bag',
  'witch_circle': 'tree-roots',
  'witch_hut': 'cauldron',
};

/// The asset path of [adventureId]'s mark, or null for the book.
String? adventureIconAsset(String? adventureId) {
  final name = kAdventureIcons[adventureId];
  return name == null ? null : 'assets/icons/adventures/$name.svg';
}
