import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../game_engine/logic/card_catalog.dart';

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
///
/// [restInterval] is how many steps apart the halts fall. It is read once,
/// when a match is set up, and handed to the engine with the rest of the
/// match's setup — changing it mid-match would move a halt the party was
/// already walking towards.
final class WalkSettings {
  final WalkMode mode;
  final int minDelay;
  final int maxDelay;
  final int restInterval;

  const WalkSettings({
    this.mode = WalkMode.auto,
    this.minDelay = 4,
    this.maxDelay = 10,
    this.restInterval = kRestInterval,
  }) : assert(minDelay >= kMinWalkDelay && minDelay <= maxDelay),
       assert(maxDelay <= kMaxWalkDelay),
       assert(
         restInterval >= kMinRestInterval && restInterval <= kMaxRestInterval,
       );

  WalkSettings copyWith({
    WalkMode? mode,
    int? minDelay,
    int? maxDelay,
    int? restInterval,
  }) => WalkSettings(
    mode: mode ?? this.mode,
    minDelay: minDelay ?? this.minDelay,
    maxDelay: maxDelay ?? this.maxDelay,
    restInterval: restInterval ?? this.restInterval,
  );

  @override
  bool operator ==(Object other) =>
      other is WalkSettings &&
      other.mode == mode &&
      other.minDelay == minDelay &&
      other.maxDelay == maxDelay &&
      other.restInterval == restInterval;

  @override
  int get hashCode => Object.hash(mode, minDelay, maxDelay, restInterval);
}

/// The bounds the settings screen offers for the delay, in seconds.
const int kMinWalkDelay = 1;
const int kMaxWalkDelay = 30;

/// The bounds the settings screen offers for the halt, in steps.
const int kMinRestInterval = 5;
const int kMaxRestInterval = 20;

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
  static const _restKey = 'rest_interval';

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
      final rest = prefs.getInt(_restKey);
      final restValid =
          rest != null && rest >= kMinRestInterval && rest <= kMaxRestInterval;
      state = WalkSettings(
        mode: mode ?? state.mode,
        minDelay: delaysValid ? min : state.minDelay,
        maxDelay: delaysValid ? max : state.maxDelay,
        restInterval: restValid ? rest : state.restInterval,
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

  void setRestInterval(int steps) {
    _touched = true;
    state = state.copyWith(restInterval: steps);
    _save((prefs) => prefs.setInt(_restKey, steps));
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
