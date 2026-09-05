import '../context/game_context.dart';
import '../models/models.dart';
import 'action_executor.dart';

/// Runs effect reactions for a game-flow event, then notifies the event
/// bus.
///
/// Only the six flow/milestone events — [OnGameStarted], [OnTurnStarted],
/// [OnTurnFinished], [OnCardDrawn], [OnCardResolved], [OnJourneyCompleted] —
/// are dispatched through here and can trigger [GameEffect.reactions]. The four
/// signal events ([OnItemReceived], [OnItemUsed], [OnEffectApplied],
/// [OnEffectExpired]) are emitted directly onto `GameContext.eventBus` by
/// [ActionExecutor]/`EffectLifecycle` as plain observer notifications and
/// are never re-dispatched here.
///
/// That split is deliberate: it keeps the reaction graph acyclic by
/// construction. If signal events could also trigger reactions, a reaction
/// that grants an item could trigger another reaction on `itemReceived`,
/// which could apply an effect, which could trigger a reaction on
/// `effectApplied`, and so on — a chain with no structural bound. Flow
/// events are each dispatched at most once per party step by
/// `GameController`, so there's no such chain to guard against.
final class EventDispatcher {
  final ActionExecutor _executor;

  const EventDispatcher(this._executor);

  GameContext dispatch(GameEvent event, GameContext context) {
    var next = context;

    for (final playerId
        in context.players.map((p) => p.id).toList(growable: false)) {
      final index = next.players.indexWhere((p) => p.id == playerId);
      if (index == -1) continue;

      final reactionActions = next.players[index].activeEffects
          .expand(
            (effect) => effect.reactions[event.kind] ?? const <GameAction>[],
          )
          .toList();
      if (reactionActions.isNotEmpty) {
        next = _executor.executeAsPlayer(reactionActions, playerId, next);
      }
    }

    next.eventBus.emit(event, next);
    return next;
  }
}
