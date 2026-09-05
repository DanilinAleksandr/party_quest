import 'effect_polarity.dart';
import 'game_action.dart';
import 'game_event.dart';

/// A blessing or curse definition (a template) that gets attached to a
/// player. Definitions live once in `assets/data/effects/` and are
/// referenced by id from cards/items via [ApplyEffectAction] — see that
/// class for why this is a lookup rather than an inline copy.
///
/// [duration]/[remainingTurns] are separate: `duration` is the template's
/// length (used to reset the timer via [instantiate]), while
/// `remainingTurns` is how much of that is left on a specific player's
/// active copy. A negative [duration] means the effect lasts until
/// something else removes it rather than expiring on its own.
final class GameEffect {
  final String id;
  final String name;
  final String description;
  final EffectPolarity polarity;
  final int duration;
  final int remainingTurns;
  final bool autoExpire;

  /// Actions to run when a game event of a given kind occurs while this
  /// effect is active on a player — e.g. `{GameEventKind.turnStarted: [+1
  /// luck]}` reproduces what used to be a bespoke "tick" mechanic, but any
  /// event kind works, so an effect can just as easily react to a card
  /// being drawn or an item being received. [GameEffect] only holds this
  /// declaratively; it has no reference to `ActionExecutor` or the event
  /// bus — `EventDispatcher` is the one piece that reads this map and
  /// actually runs the actions, keeping effects decoupled from execution.
  final Map<GameEventKind, List<GameAction>> reactions;

  /// While active, the next time `ApplyEffectAction` would apply a
  /// *negative*-polarity effect to this player, this effect is consumed
  /// (removed) instead of the curse landing. A generic "ward" primitive —
  /// declarative data, not a special case for one specific curse or one
  /// specific item — checked by `ActionExecutor._applyEffect`.
  final bool blocksNextNegativeEffect;

  const GameEffect({
    required this.id,
    required this.name,
    required this.description,
    required this.polarity,
    required this.duration,
    required this.remainingTurns,
    this.autoExpire = true,
    this.reactions = const {},
    this.blocksNextNegativeEffect = false,
  });

  bool get isIndefinite => duration < 0;

  bool get isExpired => autoExpire && !isIndefinite && remainingTurns <= 0;

  /// Fresh copy with the timer reset to [duration], as applied when a card
  /// grants this effect to a player for the first time.
  GameEffect instantiate() => copyWith(remainingTurns: duration);

  /// One turn elapsed; counts down unless the effect is indefinite.
  GameEffect tick() =>
      isIndefinite ? this : copyWith(remainingTurns: remainingTurns - 1);

  GameEffect copyWith({
    String? id,
    String? name,
    String? description,
    EffectPolarity? polarity,
    int? duration,
    int? remainingTurns,
    bool? autoExpire,
    Map<GameEventKind, List<GameAction>>? reactions,
    bool? blocksNextNegativeEffect,
  }) {
    return GameEffect(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      polarity: polarity ?? this.polarity,
      duration: duration ?? this.duration,
      remainingTurns: remainingTurns ?? this.remainingTurns,
      autoExpire: autoExpire ?? this.autoExpire,
      reactions: reactions ?? this.reactions,
      blocksNextNegativeEffect:
          blocksNextNegativeEffect ?? this.blocksNextNegativeEffect,
    );
  }

  factory GameEffect.fromJson(Map<String, dynamic> json) {
    final duration = json['duration'] as int;
    final reactionsJson =
        json['reactions'] as Map<String, dynamic>? ?? const {};
    return GameEffect(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      polarity: EffectPolarity.fromJson(json['polarity'] as String),
      duration: duration,
      // A freshly parsed effect template starts with a full timer.
      remainingTurns: json['remainingTurns'] as int? ?? duration,
      autoExpire: json['autoExpire'] as bool? ?? true,
      reactions: reactionsJson.map(
        (key, value) => MapEntry(
          GameEventKind.fromJson(key),
          GameAction.listFromJson(value as List<dynamic>),
        ),
      ),
      blocksNextNegativeEffect:
          json['blocksNextNegativeEffect'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'polarity': polarity.toJson(),
    'duration': duration,
    'remainingTurns': remainingTurns,
    'autoExpire': autoExpire,
    'reactions': reactions.map(
      (key, value) => MapEntry(key.toJson(), GameAction.listToJson(value)),
    ),
    'blocksNextNegativeEffect': blocksNextNegativeEffect,
  };
}
