import 'action_target.dart';
import 'journey_phase.dart';
import 'stat_type.dart';
import 'weather.dart';

/// A single reversible-by-design effect the engine can apply to game state:
/// give/take an item, apply a blessing/curse, shift a stat, or run a duel.
///
/// This is a sealed hierarchy (not a string-typed enum switch) so the
/// compiler forces every consumer (see `ActionExecutor.execute`) to handle
/// new action types as soon as they're added here — there is no way to
/// silently forget a case.
///
/// A card, an effect's per-turn tick, and an item's use-action all resolve
/// to `List<GameAction>`, which is how "several actions in a row" and
/// "global events" are expressed without a separate wrapper type: a card
/// with three actions just runs all three in order, and an action targeting
/// [ActionTarget.allPlayers] is what makes a card "global".
sealed class GameAction {
  const GameAction();

  factory GameAction.fromJson(Map<String, dynamic> json) {
    final kind = json['action'] as String;
    return switch (kind) {
      'giveItem' => GiveItemAction.fromJson(json),
      'takeItem' => TakeItemAction.fromJson(json),
      'applyEffect' => ApplyEffectAction.fromJson(json),
      'removeEffect' => RemoveEffectAction.fromJson(json),
      'modifyStat' => ModifyStatAction.fromJson(json),
      'duel' => StartDuelAction.fromJson(json),
      'setWorldFlag' => SetWorldFlagAction.fromJson(json),
      'modifyGlobalModifier' => ModifyGlobalModifierAction.fromJson(json),
      'startAdventure' => StartAdventureAction.fromJson(json),
      'setBiome' => SetBiomeAction.fromJson(json),
      'setWeather' => SetWeatherAction.fromJson(json),
      'setPhase' => SetPhaseAction.fromJson(json),
      'setLeader' => SetLeaderAction.fromJson(json),
      'revealOrigin' => RevealOriginAction.fromJson(json),
      'addChronicleEntry' => AddChronicleEntryAction.fromJson(json),
      _ => throw FormatException('Unknown game action kind: $kind'),
    };
  }

  Map<String, dynamic> toJson();

  static List<GameAction> listFromJson(List<dynamic>? json) =>
      (json ?? const [])
          .map((e) => GameAction.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);

  static List<Map<String, dynamic>> listToJson(List<GameAction> actions) =>
      actions.map((a) => a.toJson()).toList(growable: false);
}

/// Adds a copy of the item identified by [itemId] to the target's inventory.
final class GiveItemAction extends GameAction {
  final String itemId;
  final ActionTarget target;

  const GiveItemAction({
    required this.itemId,
    this.target = ActionTarget.currentPlayer,
  });

  factory GiveItemAction.fromJson(Map<String, dynamic> json) => GiveItemAction(
    itemId: json['itemId'] as String,
    target: ActionTarget.fromJson(json['target'] as String? ?? 'currentPlayer'),
  );

  @override
  Map<String, dynamic> toJson() => {
    'action': 'giveItem',
    'itemId': itemId,
    'target': target.toJson(),
  };
}

/// Removes the first item matching [itemId] from the target's inventory, if
/// they hold one. A no-op if they don't.
final class TakeItemAction extends GameAction {
  final String itemId;
  final ActionTarget target;

  const TakeItemAction({
    required this.itemId,
    this.target = ActionTarget.currentPlayer,
  });

  factory TakeItemAction.fromJson(Map<String, dynamic> json) => TakeItemAction(
    itemId: json['itemId'] as String,
    target: ActionTarget.fromJson(json['target'] as String? ?? 'currentPlayer'),
  );

  @override
  Map<String, dynamic> toJson() => {
    'action': 'takeItem',
    'itemId': itemId,
    'target': target.toJson(),
  };
}

/// Applies the effect identified by [effectId] to the target. A blessing
/// and a curse are the same action — the effect definition's own polarity
/// decides which one it is — so there is one action type instead of two
/// near-duplicates.
///
/// The effect is looked up by id from `GameContext.effectCatalog` rather
/// than embedded inline, the same way [GiveItemAction] references an item by
/// id: with dozens of blessings/curses reused across hundreds of cards, an
/// inline copy on every card would drift out of sync with itself the moment
/// someone tweaks one duplicate and not the others.
final class ApplyEffectAction extends GameAction {
  final String effectId;
  final ActionTarget target;

  const ApplyEffectAction({
    required this.effectId,
    this.target = ActionTarget.currentPlayer,
  });

  factory ApplyEffectAction.fromJson(Map<String, dynamic> json) =>
      ApplyEffectAction(
        effectId: json['effectId'] as String,
        target: ActionTarget.fromJson(
          json['target'] as String? ?? 'currentPlayer',
        ),
      );

  @override
  Map<String, dynamic> toJson() => {
    'action': 'applyEffect',
    'effectId': effectId,
    'target': target.toJson(),
  };
}

/// Removes the effect identified by [effectId] from the target, if they
/// currently have it. A no-op otherwise. The symmetric counterpart to
/// [ApplyEffectAction] — needed for content like "a potion that cures a
/// curse", which has no other way to exist: without this, an applied
/// effect can only ever be waited out, never lifted early.
final class RemoveEffectAction extends GameAction {
  final String effectId;
  final ActionTarget target;

  const RemoveEffectAction({
    required this.effectId,
    this.target = ActionTarget.currentPlayer,
  });

  factory RemoveEffectAction.fromJson(Map<String, dynamic> json) =>
      RemoveEffectAction(
        effectId: json['effectId'] as String,
        target: ActionTarget.fromJson(
          json['target'] as String? ?? 'currentPlayer',
        ),
      );

  @override
  Map<String, dynamic> toJson() => {
    'action': 'removeEffect',
    'effectId': effectId,
    'target': target.toJson(),
  };
}

/// Adds [amount] (may be negative) to the target's [stat].
final class ModifyStatAction extends GameAction {
  final StatType stat;
  final int amount;
  final ActionTarget target;

  const ModifyStatAction({
    required this.stat,
    required this.amount,
    this.target = ActionTarget.currentPlayer,
  });

  factory ModifyStatAction.fromJson(Map<String, dynamic> json) =>
      ModifyStatAction(
        stat: StatType.fromJson(json['stat'] as String),
        amount: json['amount'] as int,
        target: ActionTarget.fromJson(
          json['target'] as String? ?? 'currentPlayer',
        ),
      );

  @override
  Map<String, dynamic> toJson() => {
    'action': 'modifyStat',
    'stat': stat.toJson(),
    'amount': amount,
    'target': target.toJson(),
  };
}

/// Pits the current player against one random other player. The engine
/// picks a winner and applies [winnerActions] to them and [loserActions] to
/// the loser — the physical challenge (arm wrestling, a dare, a quiz) is
/// played out by the group at the table, the app only settles the stakes.
final class StartDuelAction extends GameAction {
  final List<GameAction> winnerActions;
  final List<GameAction> loserActions;

  const StartDuelAction({
    this.winnerActions = const [],
    this.loserActions = const [],
  });

  factory StartDuelAction.fromJson(Map<String, dynamic> json) =>
      StartDuelAction(
        winnerActions: GameAction.listFromJson(
          json['winnerActions'] as List<dynamic>?,
        ),
        loserActions: GameAction.listFromJson(
          json['loserActions'] as List<dynamic>?,
        ),
      );

  @override
  Map<String, dynamic> toJson() => {
    'action': 'duel',
    'winnerActions': GameAction.listToJson(winnerActions),
    'loserActions': GameAction.listToJson(loserActions),
  };
}

/// Sets a global world/story flag — see `WorldState`. Global, not per-player:
/// "the witch's book was stolen" is a fact about the world, not about
/// whoever did the stealing.
final class SetWorldFlagAction extends GameAction {
  final String flag;
  final bool value;

  const SetWorldFlagAction({required this.flag, this.value = true});

  factory SetWorldFlagAction.fromJson(Map<String, dynamic> json) =>
      SetWorldFlagAction(
        flag: json['flag'] as String,
        value: json['value'] as bool? ?? true,
      );

  @override
  Map<String, dynamic> toJson() => {
    'action': 'setWorldFlag',
    'flag': flag,
    'value': value,
  };
}

/// Adds [amount] (may be negative) to a named global modifier — see
/// `WorldState`.
final class ModifyGlobalModifierAction extends GameAction {
  final String key;
  final int amount;

  const ModifyGlobalModifierAction({required this.key, required this.amount});

  factory ModifyGlobalModifierAction.fromJson(Map<String, dynamic> json) =>
      ModifyGlobalModifierAction(
        key: json['key'] as String,
        amount: json['amount'] as int,
      );

  @override
  Map<String, dynamic> toJson() => {
    'action': 'modifyGlobalModifier',
    'key': key,
    'amount': amount,
  };
}

/// Hands control to the Adventure Engine: the current player steps into the
/// adventure identified by [adventureId] instead of the card resolving
/// immediately. See `AdventureEngine` for how a multi-node adventure
/// suspends the normal turn flow until it concludes.
final class StartAdventureAction extends GameAction {
  final String adventureId;

  const StartAdventureAction({required this.adventureId});

  factory StartAdventureAction.fromJson(Map<String, dynamic> json) =>
      StartAdventureAction(adventureId: json['adventureId'] as String);

  @override
  Map<String, dynamic> toJson() => {
    'action': 'startAdventure',
    'adventureId': adventureId,
  };
}

/// Moves the whole party into a different [Biome] — see `WorldState
/// .currentBiomeId`. This is the entire biome-transition mechanism: a
/// "leaving the forest" card is just an ordinary card, gated to the current
/// biome, whose action is this. "After several steps", "after a specific
/// adventure", and "at random" are not three different engine mechanisms —
/// they're the same action reached via [MinimumStepCondition], an
/// adventure's ending `NodeTransition`, and ordinary weighted draw,
/// respectively.
final class SetBiomeAction extends GameAction {
  final String biomeId;

  const SetBiomeAction({required this.biomeId});

  factory SetBiomeAction.fromJson(Map<String, dynamic> json) =>
      SetBiomeAction(biomeId: json['biomeId'] as String);

  @override
  Map<String, dynamic> toJson() => {'action': 'setBiome', 'biomeId': biomeId};
}

/// Changes the weather layered on top of the current [Biome] — see
/// `WorldState.currentWeather`. Mirrors [SetBiomeAction] exactly, but never
/// touches `currentBiomeId` or any biome-steering modifier: weather and
/// biome change on fully independent schedules, so a weather-transition
/// card is just an ordinary card gated on `MinimumTurnsInWeatherCondition`
/// whose action is this.
final class SetWeatherAction extends GameAction {
  final Weather weather;

  const SetWeatherAction({required this.weather});

  factory SetWeatherAction.fromJson(Map<String, dynamic> json) =>
      SetWeatherAction(weather: Weather.fromJson(json['weather'] as String));

  @override
  Map<String, dynamic> toJson() => {
    'action': 'setWeather',
    'weather': weather.toJson(),
  };
}

/// Moves the match to a new `JourneyPhase` — see `GameState.phase` and
/// `CardTag.prologue`. The six "leave prologue" cards pair this with
/// [SetBiomeAction] in the same action list (phase and biome are two
/// separate facts, so two separate actions, same as every other combined
/// moment in this engine expresses as several small actions in a row).
final class SetPhaseAction extends GameAction {
  final JourneyPhase phase;

  const SetPhaseAction({required this.phase});

  factory SetPhaseAction.fromJson(Map<String, dynamic> json) =>
      SetPhaseAction(phase: JourneyPhase.fromJson(json['phase'] as String));

  @override
  Map<String, dynamic> toJson() => {
    'action': 'setPhase',
    'phase': phase.toJson(),
  };
}

/// Hands the party's temporary leader role to [target] — see `WorldState
/// .leaderId` and `LeaderParticipant`. [target] is resolved the same way
/// every other action's target is; meant for a single-player target
/// (`currentPlayer`, `secondaryPlayer`, `leftOfCurrentPlayer`, etc.) — if it
/// resolves to more than one player (e.g. `allPlayers`), the first one is
/// made leader.
final class SetLeaderAction extends GameAction {
  final ActionTarget target;

  const SetLeaderAction({this.target = ActionTarget.currentPlayer});

  factory SetLeaderAction.fromJson(Map<String, dynamic> json) =>
      SetLeaderAction(
        target: ActionTarget.fromJson(
          json['target'] as String? ?? 'currentPlayer',
        ),
      );

  @override
  Map<String, dynamic> toJson() => {
    'action': 'setLeader',
    'target': target.toJson(),
  };
}

/// Reveals [target]'s hidden origin as [originId] — see `Origin`. Applies
/// that origin's `Origin.statModifiers` once, permanently, and sets
/// `Player.originId`. A no-op if [target] already has an origin (a reveal
/// can't happen twice, so this is a defensive guard against a
/// content-authoring mistake letting the same player get re-revealed and
/// double-stack their stat nudge — content should already gate reveal
/// cards on `AnyPlayerMissingOriginCondition` + `UnknownOriginParticipant`
/// so this never comes up in practice).
final class RevealOriginAction extends GameAction {
  final String originId;
  final ActionTarget target;

  const RevealOriginAction({
    required this.originId,
    this.target = ActionTarget.currentPlayer,
  });

  factory RevealOriginAction.fromJson(Map<String, dynamic> json) =>
      RevealOriginAction(
        originId: json['originId'] as String,
        target: ActionTarget.fromJson(
          json['target'] as String? ?? 'currentPlayer',
        ),
      );

  @override
  Map<String, dynamic> toJson() => {
    'action': 'revealOrigin',
    'originId': originId,
    'target': target.toJson(),
  };
}

/// Appends a hand-authored, already-worded line to
/// `GameState.chronicle` — the "Летопись путешествия," reserved for
/// content authors to mark genuinely significant moments (a true nature
/// revealed, an alliance formed, a legendary confrontation resolved), never
/// derived automatically the way `JourneyLogEntry` is. [text] may contain
/// the literal placeholder `{player}`, replaced with whoever [target]
/// resolves to — omit it entirely for a whole-party line where naming one
/// player wouldn't make sense.
final class AddChronicleEntryAction extends GameAction {
  final String text;
  final ActionTarget target;

  const AddChronicleEntryAction({
    required this.text,
    this.target = ActionTarget.currentPlayer,
  });

  factory AddChronicleEntryAction.fromJson(Map<String, dynamic> json) =>
      AddChronicleEntryAction(
        text: json['text'] as String,
        target: ActionTarget.fromJson(
          json['target'] as String? ?? 'currentPlayer',
        ),
      );

  @override
  Map<String, dynamic> toJson() => {
    'action': 'addChronicleEntry',
    'text': text,
    'target': target.toJson(),
  };
}
