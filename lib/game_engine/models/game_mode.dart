import 'rarity.dart';

/// A named ruleset a match is played under. The MVP only ships [classic],
/// but the type exists now so "режимы игры" (speed mode, no-curses mode, a
/// daily-challenge mode with a restricted rarity pool, ...) are a matter of
/// defining another [GameMode] value and wiring a mode picker into game
/// setup — no engine change required, since [GameModeCondition] and
/// `CardCatalog`'s rarity-pool check already read from whatever mode is
/// active.
final class GameMode {
  final String id;
  final String name;
  final Set<Rarity> allowedRarities;

  const GameMode({
    required this.id,
    required this.name,
    this.allowedRarities = const {
      Rarity.common,
      Rarity.uncommon,
      Rarity.rare,
      Rarity.epic,
      Rarity.legendary,
    },
  });

  static const classic = GameMode(id: 'classic', name: 'Классический');
}
