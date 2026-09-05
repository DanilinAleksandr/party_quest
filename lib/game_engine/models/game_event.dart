import 'effect.dart';
import 'game_card.dart';
import 'inventory_item.dart';
import 'player.dart';

/// JSON-friendly discriminator for [GameEvent] subtypes. Kept separate from
/// the sealed class itself so [GameEffect.reactions] can be keyed by a plain
/// enum (serializable, usable as a `Map` key) instead of by Dart `Type`
/// objects or a runtime-only tag.
///
/// Split into two tiers, documented on [EventDispatcher]:
/// - "flow" events (game/step/card/journey milestones) can trigger effect
///   reactions;
/// - "signal" events (item/effect state changes) are observe-only, emitted
///   directly by [ActionExecutor]/[EffectLifecycle] for future systems
///   (achievements, analytics, UI feedback) to listen to.
enum GameEventKind {
  gameStarted,
  turnStarted,
  turnFinished,
  cardDrawn,
  cardResolved,
  itemReceived,
  itemUsed,
  effectApplied,
  effectExpired,
  journeyCompleted;

  static GameEventKind fromJson(String value) =>
      GameEventKind.values.byName(value);

  String toJson() => name;
}

/// Something that happened in a match, broadcast through [GameEventBus].
/// New event types are added here and given a [GameEventKind]; nothing else
/// needs to change for existing listeners to keep working, since listeners
/// pattern-match (or filter by [kind]) rather than enumerate every subtype.
sealed class GameEvent {
  const GameEvent();

  GameEventKind get kind;
}

final class OnGameStarted extends GameEvent {
  const OnGameStarted();

  @override
  GameEventKind get kind => GameEventKind.gameStarted;
}

final class OnTurnStarted extends GameEvent {
  final Player player;

  const OnTurnStarted({required this.player});

  @override
  GameEventKind get kind => GameEventKind.turnStarted;
}

final class OnTurnFinished extends GameEvent {
  final Player player;

  const OnTurnFinished({required this.player});

  @override
  GameEventKind get kind => GameEventKind.turnFinished;
}

final class OnCardDrawn extends GameEvent {
  final GameCard card;
  final Player player;

  const OnCardDrawn({required this.card, required this.player});

  @override
  GameEventKind get kind => GameEventKind.cardDrawn;
}

final class OnCardResolved extends GameEvent {
  final GameCard card;
  final Player player;
  final int? choiceIndex;

  const OnCardResolved({
    required this.card,
    required this.player,
    this.choiceIndex,
  });

  @override
  GameEventKind get kind => GameEventKind.cardResolved;
}

final class OnItemReceived extends GameEvent {
  final Player player;
  final InventoryItem item;

  const OnItemReceived({required this.player, required this.item});

  @override
  GameEventKind get kind => GameEventKind.itemReceived;
}

/// Not yet emitted anywhere — there is no "use item" action in the engine
/// yet (manual item use is still future UI work). The event type exists now
/// so that future action, and anything reacting to it, slot in without
/// another round of plumbing through [GameEventKind].
final class OnItemUsed extends GameEvent {
  final Player player;
  final InventoryItem item;

  const OnItemUsed({required this.player, required this.item});

  @override
  GameEventKind get kind => GameEventKind.itemUsed;
}

final class OnEffectApplied extends GameEvent {
  final Player player;
  final GameEffect effect;

  const OnEffectApplied({required this.player, required this.effect});

  @override
  GameEventKind get kind => GameEventKind.effectApplied;
}

final class OnEffectExpired extends GameEvent {
  final Player player;
  final GameEffect effect;

  const OnEffectExpired({required this.player, required this.effect});

  @override
  GameEventKind get kind => GameEventKind.effectExpired;
}

/// Fired once when the party's [GameState.partySteps] reaches
/// `GameConstants.stepsToWin` — the journey is complete. There is no
/// individual winner: the whole party travels together, so [player] just
/// carries whoever happened to be resolved as the current step's event
/// participant, for effect-reaction purposes.
final class OnJourneyCompleted extends GameEvent {
  final Player player;

  const OnJourneyCompleted({required this.player});

  @override
  GameEventKind get kind => GameEventKind.journeyCompleted;
}
