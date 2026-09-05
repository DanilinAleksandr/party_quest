/// Tunable game rules. Kept in one place so balancing the game never
/// requires touching engine or UI code.
abstract final class GameConstants {
  static const int minPlayers = 2;
  static const int maxPlayers = 8;

  /// A player wins immediately once their step count reaches this value.
  static const int stepsToWin = 20;

  /// Every match starts in this biome — see `Biome`/`WorldState`. A journey
  /// needs a first chapter; the forest is it. (Also the placeholder value
  /// `WorldState.currentBiomeId` holds during `JourneyPhase.prologue`,
  /// before the first real biome is chosen — never displayed, since
  /// `game_screen.dart` shows a dedicated prologue banner instead.)
  static const String startingBiomeId = 'forest';
}
