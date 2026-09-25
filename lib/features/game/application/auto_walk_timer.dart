import 'dart:async';
import 'dart:math';

/// Takes the party's next step on its own after a random pause.
///
/// Knows nothing about the game: it is told, every time anything changes,
/// whether the party is free to walk right now, and it keeps exactly one
/// countdown alive for as long as the answer stays yes. The moment the answer
/// is no — a card opened, the party sat down, the match ended — the countdown
/// is dropped, and the next yes starts a fresh one with a fresh delay rather
/// than resuming the old one. A card should never turn up half a second after
/// the previous one was closed just because its countdown was nearly spent
/// before that card was drawn.
///
/// The randomness is the UI's own, not the engine's seeded [Random]: when a
/// card arrives is not part of the match, and drawing from the engine's
/// generator would shift every card after it.
class AutoWalkTimer {
  final void Function() onStep;
  final Random _random;
  Timer? _timer;

  AutoWalkTimer({required this.onStep, Random? random})
    : _random = random ?? Random();

  /// The pause the running countdown was scheduled with, for tests and
  /// nothing else.
  Duration? get scheduledDelay => isScheduled ? _scheduledDelay : null;
  Duration? _scheduledDelay;

  bool get isScheduled => _timer?.isActive ?? false;

  /// Brings the countdown in line with [canWalk]. Cheap and idempotent, so it
  /// can be called on every rebuild: an already-running countdown is left
  /// alone rather than restarted, or it would never get to finish.
  void update({
    required bool canWalk,
    required int minDelaySeconds,
    required int maxDelaySeconds,
  }) {
    if (!canWalk) {
      cancel();
      return;
    }
    if (isScheduled) return;

    // Milliseconds rather than whole seconds, so "4 to 10" means anywhere in
    // between and not one of seven fixed beats.
    final minMs = minDelaySeconds * 1000;
    final spanMs = (maxDelaySeconds - minDelaySeconds) * 1000;
    final delay = Duration(milliseconds: minMs + _random.nextInt(spanMs + 1));
    _scheduledDelay = delay;
    _timer = Timer(delay, () {
      _timer = null;
      onStep();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
