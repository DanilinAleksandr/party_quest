import '../context/game_context.dart';
import '../models/models.dart';

/// Advances every player's active effects by one party step: decrements
/// each one's remaining duration and drops any that have expired, emitting
/// [OnEffectExpired] for each one removed.
///
/// This runs for the whole party, not just whoever the step's event turned
/// out to be about — "a curse lasts 3 events" means 3 party steps to every
/// player, not 3 turns of whoever happens to be cursed. Reactions are a
/// separate thing (`EventDispatcher` already loops every player's own
/// effects on every flow event); this is purely the clock ticking down.
final class EffectLifecycle {
  const EffectLifecycle();

  /// [ticks], when given, says which effects count this step; the rest are
  /// carried over untouched. The controller uses it so an effect put on
  /// during a card is not counted down before the next card has even seen
  /// it — a duration is the number of cards drawn while it is on.
  GameContext expireForAllPlayers(
    GameContext context, {
    bool Function(Player player, GameEffect effect)? ticks,
  }) {
    var next = context;

    for (final player in context.players) {
      final kept = <GameEffect>[];
      final expired = <GameEffect>[];

      for (final effect in player.activeEffects) {
        if (ticks != null && !ticks(player, effect)) {
          kept.add(effect);
          continue;
        }
        final ticked = effect.tick();
        if (ticked.isExpired) {
          expired.add(ticked);
        } else {
          kept.add(ticked);
        }
      }

      // Saved whenever there was anything to tick, not only when something
      // ran out — otherwise a count never gets below where it started.
      if (player.activeEffects.isEmpty) continue;

      final updatedPlayer = player.copyWith(activeEffects: kept);
      final updatedPlayers = next.players
          .map((p) => p.id == updatedPlayer.id ? updatedPlayer : p)
          .toList();
      next = next.withState(next.state.copyWith(players: updatedPlayers));

      for (final effect in expired) {
        next.eventBus.emit(
          OnEffectExpired(player: updatedPlayer, effect: effect),
          next,
        );
      }
    }

    return next;
  }
}
