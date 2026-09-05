import '../context/game_context.dart';
import '../models/game_event.dart';

typedef GameEventListener = void Function(GameEvent event, GameContext context);

/// A plain synchronous observer registry — not a `Stream`. Turn resolution
/// must stay deterministic within a single method call (increment steps,
/// react, draw a card, all before `takeStep()` returns), and a `Stream`
/// delivers on a microtask, which would tear that apart. Listeners are
/// called immediately, in subscription order, once per [emit].
///
/// This bus is purely for *observation* — analytics, achievements, a future
/// "show a toast on OnPlayerWon" — and cannot itself mutate game state.
/// State-mutating reactions (an effect granting +1 luck on turn start) go
/// through `EventDispatcher` instead, which runs *before* the bus notifies
/// observers, so observers always see the final state for that event.
final class GameEventBus {
  final List<GameEventListener> _listeners = [];

  void subscribe(GameEventListener listener) => _listeners.add(listener);

  void unsubscribe(GameEventListener listener) => _listeners.remove(listener);

  void emit(GameEvent event, GameContext context) {
    for (final listener in List<GameEventListener>.of(_listeners)) {
      listener(event, context);
    }
  }
}
