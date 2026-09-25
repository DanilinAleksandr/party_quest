import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Who moves the party along the road between cards.
enum WalkMode {
  /// The heroes walk on their own, and a card turns up after a random pause.
  auto,

  /// A step happens only when somebody presses for it — the game as it was.
  manual,
}

/// The walking preferences, as the settings screen edits them and the game
/// screen reads them.
///
/// The delay is a range of whole seconds, not one value: a card that arrives
/// on a metronome stops feeling like something that happened on the road.
final class WalkSettings {
  final WalkMode mode;
  final int minDelay;
  final int maxDelay;

  const WalkSettings({
    this.mode = WalkMode.auto,
    this.minDelay = 4,
    this.maxDelay = 10,
  }) : assert(minDelay >= kMinWalkDelay && minDelay <= maxDelay),
       assert(maxDelay <= kMaxWalkDelay);

  WalkSettings copyWith({WalkMode? mode, int? minDelay, int? maxDelay}) =>
      WalkSettings(
        mode: mode ?? this.mode,
        minDelay: minDelay ?? this.minDelay,
        maxDelay: maxDelay ?? this.maxDelay,
      );

  @override
  bool operator ==(Object other) =>
      other is WalkSettings &&
      other.mode == mode &&
      other.minDelay == minDelay &&
      other.maxDelay == maxDelay;

  @override
  int get hashCode => Object.hash(mode, minDelay, maxDelay);
}

/// The bounds the settings screen offers for the delay, in seconds.
const int kMinWalkDelay = 1;
const int kMaxWalkDelay = 30;

/// Holds [WalkSettings] and keeps them across launches.
///
/// Starts on the defaults and replaces them with the stored values once
/// those have been read. The read takes a few milliseconds at launch, long
/// before anybody has set up a match, so there is nothing to wait for — and
/// nothing to break where the platform store is missing, as it is under
/// tests: a failed read simply leaves the defaults in place.
///
/// [initial] pins the settings and skips the read altogether — for tests,
/// which need to know which mode a screen will be built in.
class WalkSettingsNotifier extends StateNotifier<WalkSettings> {
  WalkSettingsNotifier({WalkSettings? initial})
    : super(initial ?? const WalkSettings()) {
    if (initial == null) _load();
  }

  static const _modeKey = 'walk_mode';
  static const _minKey = 'walk_min_delay';
  static const _maxKey = 'walk_max_delay';

  /// Set once somebody changes a setting, so a slow first read cannot land
  /// afterwards and quietly undo them.
  bool _touched = false;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_touched || !mounted) return;
      final mode = WalkMode.values.asNameMap()[prefs.getString(_modeKey)];
      final min = prefs.getInt(_minKey);
      final max = prefs.getInt(_maxKey);
      final delaysValid =
          min != null &&
          max != null &&
          min >= kMinWalkDelay &&
          min <= max &&
          max <= kMaxWalkDelay;
      state = WalkSettings(
        mode: mode ?? state.mode,
        minDelay: delaysValid ? min : state.minDelay,
        maxDelay: delaysValid ? max : state.maxDelay,
      );
    } catch (_) {
      // No store to read from: the defaults are a perfectly good answer.
    }
  }

  void setMode(WalkMode mode) {
    _touched = true;
    state = state.copyWith(mode: mode);
    _save((prefs) => prefs.setString(_modeKey, mode.name));
  }

  void setDelay({required int min, required int max}) {
    _touched = true;
    state = state.copyWith(minDelay: min, maxDelay: max);
    _save((prefs) async {
      await prefs.setInt(_minKey, min);
      await prefs.setInt(_maxKey, max);
    });
  }

  Future<void> _save(
    Future<void> Function(SharedPreferences prefs) write,
  ) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {
      // The setting still holds for this launch; only remembering it failed.
    }
  }
}

final walkSettingsProvider =
    StateNotifierProvider<WalkSettingsNotifier, WalkSettings>(
      (ref) => WalkSettingsNotifier(),
    );
