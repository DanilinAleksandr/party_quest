/// Bounds and calibration hints for the free-form journey-length picker on
/// `game_setup_screen.dart`. The actual chosen length is just a plain
/// `int?` from there on (`null` = infinite, no automatic finish — see
/// `GameController.stepsToWin`/`endJourneyManually`) — this class only
/// exists to give the setup UI's slider/markers/warning a single tuning
/// point instead of scattered magic numbers.
abstract final class JourneyLengthConfig {
  static const int minSteps = 10;

  /// The largest *finite* step count the slider can express. One further
  /// slider position past this represents infinite — see
  /// [sliderMaxPosition].
  static const int maxFiniteSteps = 200;

  /// The slider's technical maximum — one more than [maxFiniteSteps], so
  /// dragging all the way to the end is a distinct, reachable position
  /// meaning "infinite," not just an extreme finite value.
  static const int sliderMaxPosition = maxFiniteSteps + 1;

  static const int defaultSteps = 20;

  /// Rough scale markers shown under the slider — calibration hints for a
  /// first-time player, not hard limits.
  static const List<int> scaleMarkers = [10, 20, 40, 80];

  /// Past this many steps, the picker shows a soft "very long journey" hint
  /// instead of blocking the choice.
  static const int longJourneyWarningThreshold = 100;
}
