import '../context/game_context.dart';
import 'journey_phase.dart';
import 'season.dart';
import 'stat_type.dart';
import 'weather.dart';

/// A gate a card, adventure choice, or adventure node must pass before it's
/// eligible/shown. `CardCatalog.eligibleCards` evaluates every condition on
/// every card before the weighted draw runs; `AdventureEngine` evaluates a
/// node's choices' conditions before presenting them to the player. Same
/// type, same evaluation rule, reused everywhere something needs to be
/// gated on live game state — that's deliberate: a "has the player visited
/// the witch's hut" check works identically whether it's gating a card or
/// gating a choice inside an adventure.
///
/// A condition list is implicitly AND'ed: every condition must hold. That
/// covers the vast majority of real content ("needs 3+ players" AND
/// "current player doesn't already have this curse"); if OR/NOT combinators
/// turn out to be needed later, they're just two more subtypes here
/// (`AnyOfCondition`, `NotCondition`) — nothing about this design forecloses
/// that.
sealed class GameCondition {
  const GameCondition();

  bool isSatisfied(GameContext context);

  factory GameCondition.fromJson(Map<String, dynamic> json) {
    final kind = json['condition'] as String;
    return switch (kind) {
      'minimumPlayers' => MinimumPlayersCondition(count: json['count'] as int),
      'maximumPlayers' => MaximumPlayersCondition(count: json['count'] as int),
      'minimumStep' => MinimumStepCondition(steps: json['steps'] as int),
      'maximumStep' => MaximumStepCondition(steps: json['steps'] as int),
      'currentPlayerHasItem' => CurrentPlayerHasItemCondition(
        itemId: json['itemId'] as String,
      ),
      'currentPlayerMissingItem' => CurrentPlayerMissingItemCondition(
        itemId: json['itemId'] as String,
      ),
      'partyHasItem' => PartyHasItemCondition(itemId: json['itemId'] as String),
      'partyMissingItem' => PartyMissingItemCondition(
        itemId: json['itemId'] as String,
      ),
      'currentPlayerHasEffect' => CurrentPlayerHasEffectCondition(
        effectId: json['effectId'] as String,
      ),
      'currentPlayerMissingEffect' => CurrentPlayerMissingEffectCondition(
        effectId: json['effectId'] as String,
      ),
      'anyPlayerHasItem' => AnyPlayerHasItemCondition(
        itemId: json['itemId'] as String,
      ),
      'currentPlayerStatAtLeast' => CurrentPlayerStatAtLeastCondition(
        stat: StatType.fromJson(json['stat'] as String),
        value: json['value'] as int,
      ),
      'anyPlayerStatAtLeast' => AnyPlayerStatAtLeastCondition(
        stat: StatType.fromJson(json['stat'] as String),
        value: json['value'] as int,
      ),
      'anyPlayerHasEffect' => AnyPlayerHasEffectCondition(
        effectId: json['effectId'] as String,
      ),
      'currentPlayerHasOrigin' => CurrentPlayerHasOriginCondition(
        originId: json['originId'] as String,
      ),
      'anyPlayerHasOrigin' => AnyPlayerHasOriginCondition(
        originId: json['originId'] as String,
      ),
      'anyPlayerMissingOrigin' => const AnyPlayerMissingOriginCondition(),
      'currentPlayerLacksOrigin' => CurrentPlayerLacksOriginCondition(
        originId: json['originId'] as String,
      ),
      'currentPlayerOriginUnknown' => const CurrentPlayerOriginUnknownCondition(),
      'gameMode' => GameModeCondition(modeId: json['modeId'] as String),
      'inPhase' => InPhaseCondition(
        phase: JourneyPhase.fromJson(json['phase'] as String),
      ),
      'worldFlagSet' => WorldFlagSetCondition(flag: json['flag'] as String),
      'worldFlagUnset' => WorldFlagUnsetCondition(flag: json['flag'] as String),
      'adventureCompleted' => AdventureCompletedCondition(
        adventureId: json['adventureId'] as String,
      ),
      'adventureNotCompleted' => AdventureNotCompletedCondition(
        adventureId: json['adventureId'] as String,
      ),
      'globalModifierAtLeast' => GlobalModifierAtLeastCondition(
        key: json['key'] as String,
        value: json['value'] as int,
      ),
      'inBiome' => InBiomeCondition(biomeId: json['biomeId'] as String),
      'notInBiome' => NotInBiomeCondition(biomeId: json['biomeId'] as String),
      'minimumTurnsInBiome' => MinimumTurnsInBiomeCondition(
        turns: json['turns'] as int,
      ),
      'minimumTurnsInTavern' => MinimumTurnsInTavernCondition(
        turns: json['turns'] as int,
      ),
      'inWeather' => InWeatherCondition(
        weather: Weather.fromJson(json['weather'] as String),
      ),
      'notInWeather' => NotInWeatherCondition(
        weather: Weather.fromJson(json['weather'] as String),
      ),
      'minimumTurnsInWeather' => MinimumTurnsInWeatherCondition(
        turns: json['turns'] as int,
      ),
      'inSeason' => InSeasonCondition(
        season: Season.fromJson(json['season'] as String),
      ),
      'notInSeason' => NotInSeasonCondition(
        season: Season.fromJson(json['season'] as String),
      ),
      'leaderIsSet' => const LeaderIsSetCondition(),
      'leaderIsUnset' => const LeaderIsUnsetCondition(),
      'minimumStepsSinceFlag' => MinimumStepsSinceFlagCondition(
        flag: json['flag'] as String,
        steps: json['steps'] as int,
      ),
      _ => throw FormatException('Unknown game condition kind: $kind'),
    };
  }

  Map<String, dynamic> toJson();

  static List<GameCondition> listFromJson(List<dynamic>? json) =>
      (json ?? const [])
          .map((e) => GameCondition.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);

  static List<Map<String, dynamic>> listToJson(
    List<GameCondition> conditions,
  ) => conditions.map((c) => c.toJson()).toList(growable: false);
}

final class MinimumPlayersCondition extends GameCondition {
  final int count;

  const MinimumPlayersCondition({required this.count});

  @override
  bool isSatisfied(GameContext context) => context.players.length >= count;

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'minimumPlayers',
    'count': count,
  };
}

final class MaximumPlayersCondition extends GameCondition {
  final int count;

  const MaximumPlayersCondition({required this.count});

  @override
  bool isSatisfied(GameContext context) => context.players.length <= count;

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'maximumPlayers',
    'count': count,
  };
}

/// Gates on how far the party has travelled together — see
/// `GameState.partySteps`. Not per-player: the whole party always advances
/// in lockstep now, so a single shared counter is the only one that means
/// anything.
final class MinimumStepCondition extends GameCondition {
  final int steps;

  const MinimumStepCondition({required this.steps});

  @override
  bool isSatisfied(GameContext context) => context.state.partySteps >= steps;

  @override
  Map<String, dynamic> toJson() => {'condition': 'minimumStep', 'steps': steps};
}

final class MaximumStepCondition extends GameCondition {
  final int steps;

  const MaximumStepCondition({required this.steps});

  @override
  bool isSatisfied(GameContext context) => context.state.partySteps <= steps;

  @override
  Map<String, dynamic> toJson() => {'condition': 'maximumStep', 'steps': steps};
}

final class CurrentPlayerHasItemCondition extends GameCondition {
  final String itemId;

  const CurrentPlayerHasItemCondition({required this.itemId});

  @override
  bool isSatisfied(GameContext context) =>
      context.currentPlayer.inventory.any((i) => i.id == itemId);

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'currentPlayerHasItem',
    'itemId': itemId,
  };
}

final class PartyHasItemCondition extends GameCondition {
  final String itemId;

  const PartyHasItemCondition({required this.itemId});

  @override
  bool isSatisfied(GameContext context) =>
      context.state.partyInventory.any((i) => i.id == itemId);

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'partyHasItem',
    'itemId': itemId,
  };
}

final class PartyMissingItemCondition extends GameCondition {
  final String itemId;

  const PartyMissingItemCondition({required this.itemId});

  @override
  bool isSatisfied(GameContext context) =>
      !context.state.partyInventory.any((i) => i.id == itemId);

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'partyMissingItem',
    'itemId': itemId,
  };
}

final class CurrentPlayerMissingItemCondition extends GameCondition {
  final String itemId;

  const CurrentPlayerMissingItemCondition({required this.itemId});

  @override
  bool isSatisfied(GameContext context) =>
      !context.currentPlayer.inventory.any((i) => i.id == itemId);

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'currentPlayerMissingItem',
    'itemId': itemId,
  };
}

final class CurrentPlayerHasEffectCondition extends GameCondition {
  final String effectId;

  const CurrentPlayerHasEffectCondition({required this.effectId});

  @override
  bool isSatisfied(GameContext context) =>
      context.currentPlayer.activeEffects.any((e) => e.id == effectId);

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'currentPlayerHasEffect',
    'effectId': effectId,
  };
}

final class CurrentPlayerMissingEffectCondition extends GameCondition {
  final String effectId;

  const CurrentPlayerMissingEffectCondition({required this.effectId});

  @override
  bool isSatisfied(GameContext context) =>
      !context.currentPlayer.activeEffects.any((e) => e.id == effectId);

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'currentPlayerMissingEffect',
    'effectId': effectId,
  };
}

final class AnyPlayerHasItemCondition extends GameCondition {
  final String itemId;

  const AnyPlayerHasItemCondition({required this.itemId});

  @override
  bool isSatisfied(GameContext context) =>
      context.players.any((p) => p.inventory.any((i) => i.id == itemId));

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'anyPlayerHasItem',
    'itemId': itemId,
  };
}

/// Gates on whichever player the current event resolved to having at
/// least [value] in [stat] — the missing piece that lets content say "a
/// player with high Charisma can try to negotiate" instead of every
/// outcome being pure chance or item-gated. Pairs naturally with
/// `AdventureChoice.successChance`: this condition decides whether the
/// *attempt* is even on the table, the roll decides whether it works.
final class CurrentPlayerStatAtLeastCondition extends GameCondition {
  final StatType stat;
  final int value;

  const CurrentPlayerStatAtLeastCondition({
    required this.stat,
    required this.value,
  });

  @override
  bool isSatisfied(GameContext context) =>
      context.currentPlayer.stats.valueOf(stat) >= value;

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'currentPlayerStatAtLeast',
    'stat': stat.toJson(),
    'value': value,
  };
}

/// Gates on *some* player at the table having at least [value] in [stat] —
/// pairs with a stat-based `EventParticipant` (e.g. `MaxStatParticipant`)
/// the same way `AnyPlayerHasItemCondition` pairs with `HasItemParticipant`.
final class AnyPlayerStatAtLeastCondition extends GameCondition {
  final StatType stat;
  final int value;

  const AnyPlayerStatAtLeastCondition({
    required this.stat,
    required this.value,
  });

  @override
  bool isSatisfied(GameContext context) =>
      context.players.any((p) => p.stats.valueOf(stat) >= value);

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'anyPlayerStatAtLeast',
    'stat': stat.toJson(),
    'value': value,
  };
}

final class AnyPlayerHasEffectCondition extends GameCondition {
  final String effectId;

  const AnyPlayerHasEffectCondition({required this.effectId});

  @override
  bool isSatisfied(GameContext context) =>
      context.players.any((p) => p.activeEffects.any((e) => e.id == effectId));

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'anyPlayerHasEffect',
    'effectId': effectId,
  };
}

/// Gates on whichever player the current event resolved to (see
/// `EventParticipant`) having a specific [Origin] — see `Player.originId`.
final class CurrentPlayerHasOriginCondition extends GameCondition {
  final String originId;

  const CurrentPlayerHasOriginCondition({required this.originId});

  @override
  bool isSatisfied(GameContext context) =>
      context.currentPlayer.originId == originId;

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'currentPlayerHasOrigin',
    'originId': originId,
  };
}

/// The negation of [CurrentPlayerHasOriginCondition]: satisfied unless the
/// acting player is that specific origin. Completes the Not-family every
/// other axis already had (`NotInBiomeCondition`, `NotInWeatherCondition`,
/// `NotInSeasonCondition`, `WorldFlagUnsetCondition`,
/// `AdventureNotCompletedCondition`) — origin was the one dimension that
/// could only ever *open* a door, never close one.
///
/// This is what expresses a drawback that costs nothing permanently: an
/// option everyone else gets, which is simply not available to you because
/// of who you turned out to be (an honest guard won't take a known
/// fugitive's word; nobody negotiates a serious deal with the town
/// drunkard). Pair it with an origin-gated *worse* alternative on the same
/// card and the door doesn't just close — it visibly redirects.
///
/// Do not confuse with [AnyPlayerMissingOriginCondition], which means "has
/// no origin at all yet". A player whose origin is still Unknown satisfies
/// *this* condition for every id: not being revealed as X means the world
/// has no reason to treat you as X.
final class CurrentPlayerLacksOriginCondition extends GameCondition {
  final String originId;

  const CurrentPlayerLacksOriginCondition({required this.originId});

  @override
  bool isSatisfied(GameContext context) =>
      context.currentPlayer.originId != originId;

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'currentPlayerLacksOrigin',
    'originId': originId,
  };
}

/// Gates on whichever player the current event resolved to still being
/// Unknown (`Player.originId == null`). Unlike
/// `AnyPlayerMissingOriginCondition` + `UnknownOriginParticipant` — which
/// together pick a fresh still-Unknown player at the moment a *plain* reveal
/// card is drawn — an adventure's protagonist is already fixed by whichever
/// `EventParticipant` resolved its entry card, and can't be re-picked
/// mid-story. This condition is what lets an `AdventureChoice` embedded deep
/// in an existing adventure (e.g. a dragon recognizing its own bloodline)
/// gate itself on "this specific ongoing protagonist hasn't been revealed
/// yet", without disturbing who that protagonist is.
final class CurrentPlayerOriginUnknownCondition extends GameCondition {
  const CurrentPlayerOriginUnknownCondition();

  @override
  bool isSatisfied(GameContext context) => context.currentPlayer.originId == null;

  @override
  Map<String, dynamic> toJson() => {'condition': 'currentPlayerOriginUnknown'};
}

/// Gates on *some* player at the table having a specific [Origin] —
/// typically pairs with `HasOriginParticipant` on the same card, the same
/// way `AnyPlayerHasItemCondition` pairs with `HasItemParticipant`: the
/// condition decides whether the card is even eligible, the participant
/// selector decides who it actually happens to.
final class AnyPlayerHasOriginCondition extends GameCondition {
  final String originId;

  const AnyPlayerHasOriginCondition({required this.originId});

  @override
  bool isSatisfied(GameContext context) =>
      context.players.any((p) => p.originId == originId);

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'anyPlayerHasOrigin',
    'originId': originId,
  };
}

/// Gates on at least one player still being "Неизвестный" (`Player
/// .originId == null`) — the eligibility half of the origin-reveal
/// mechanism: pairs with `UnknownOriginParticipant` on the same card so a
/// reveal event stops being drawable at all once every player's origin has
/// already come out.
final class AnyPlayerMissingOriginCondition extends GameCondition {
  const AnyPlayerMissingOriginCondition();

  @override
  bool isSatisfied(GameContext context) =>
      context.players.any((p) => p.originId == null);

  @override
  Map<String, dynamic> toJson() => {'condition': 'anyPlayerMissingOrigin'};
}

/// Restricts to a specific [GameMode] — e.g. content that only makes sense
/// in a future "daily challenge" mode.
final class GameModeCondition extends GameCondition {
  final String modeId;

  const GameModeCondition({required this.modeId});

  @override
  bool isSatisfied(GameContext context) => context.mode.id == modeId;

  @override
  Map<String, dynamic> toJson() => {'condition': 'gameMode', 'modeId': modeId};
}

/// Gates on `GameState.phase` — see [JourneyPhase]. Needed alongside the
/// `CardTag.prologue` filter in `CardCatalog.eligibleCards`: the tag filter
/// only *restricts* eligibility during `JourneyPhase.prologue`, it doesn't
/// stop a prologue-tagged card from being eligible again later once the
/// phase has moved on. Content that should only ever fire during one
/// specific phase (the six "leave prologue" cards) needs this condition to
/// say so explicitly.
final class InPhaseCondition extends GameCondition {
  final JourneyPhase phase;

  const InPhaseCondition({required this.phase});

  @override
  bool isSatisfied(GameContext context) => context.state.phase == phase;

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'inPhase',
    'phase': phase.toJson(),
  };
}

/// Gates on a world/story flag being set — see [WorldState]. "world flags"
/// and "story flags" from the design doc are the same mechanism (a named
/// boolean fact about the world), so one condition type covers both; the
/// distinction is purely in how content authors name their flags.
final class WorldFlagSetCondition extends GameCondition {
  final String flag;

  const WorldFlagSetCondition({required this.flag});

  @override
  bool isSatisfied(GameContext context) => context.state.worldState.flag(flag);

  @override
  Map<String, dynamic> toJson() => {'condition': 'worldFlagSet', 'flag': flag};
}

final class WorldFlagUnsetCondition extends GameCondition {
  final String flag;

  const WorldFlagUnsetCondition({required this.flag});

  @override
  bool isSatisfied(GameContext context) => !context.state.worldState.flag(flag);

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'worldFlagUnset',
    'flag': flag,
  };
}

/// Gates on whether a given [Adventure] has ever been completed this game —
/// "the world remembers": e.g. the witch reacts differently if the player
/// has already been through her hut once.
final class AdventureCompletedCondition extends GameCondition {
  final String adventureId;

  const AdventureCompletedCondition({required this.adventureId});

  @override
  bool isSatisfied(GameContext context) =>
      context.state.worldState.completedAdventures.contains(adventureId);

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'adventureCompleted',
    'adventureId': adventureId,
  };
}

final class AdventureNotCompletedCondition extends GameCondition {
  final String adventureId;

  const AdventureNotCompletedCondition({required this.adventureId});

  @override
  bool isSatisfied(GameContext context) =>
      !context.state.worldState.completedAdventures.contains(adventureId);

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'adventureNotCompleted',
    'adventureId': adventureId,
  };
}

final class GlobalModifierAtLeastCondition extends GameCondition {
  final String key;
  final int value;

  const GlobalModifierAtLeastCondition({
    required this.key,
    required this.value,
  });

  @override
  bool isSatisfied(GameContext context) =>
      context.state.worldState.modifier(key) >= value;

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'globalModifierAtLeast',
    'key': key,
    'value': value,
  };
}

/// Gates on the party currently being in a specific [Biome] — see
/// `WorldState.currentBiomeId`. This is the entire mechanism by which
/// biomes "restrict and reshape the available content pool": a card tagged
/// with this condition simply doesn't exist as a possibility outside that
/// biome, the same way any other conditional card doesn't.
final class InBiomeCondition extends GameCondition {
  final String biomeId;

  const InBiomeCondition({required this.biomeId});

  @override
  bool isSatisfied(GameContext context) =>
      context.state.worldState.currentBiomeId == biomeId;

  @override
  Map<String, dynamic> toJson() => {'condition': 'inBiome', 'biomeId': biomeId};
}

final class NotInBiomeCondition extends GameCondition {
  final String biomeId;

  const NotInBiomeCondition({required this.biomeId});

  @override
  bool isSatisfied(GameContext context) =>
      context.state.worldState.currentBiomeId != biomeId;

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'notInBiome',
    'biomeId': biomeId,
  };
}

/// Gates on how long the party has been in the *current* biome (any
/// player's turns since the last [SetBiomeAction], see
/// `WorldState.turnsInCurrentBiome`) — the mechanism behind biomes having a
/// random duration with a minimum but no maximum, instead of switching on a
/// fixed schedule.
final class MinimumTurnsInBiomeCondition extends GameCondition {
  final int turns;

  const MinimumTurnsInBiomeCondition({required this.turns});

  @override
  bool isSatisfied(GameContext context) =>
      context.state.worldState.turnsInCurrentBiome >= turns;

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'minimumTurnsInBiome',
    'turns': turns,
  };
}

/// Weather analog of [InBiomeCondition] — see `WorldState.currentWeather`.
final class InWeatherCondition extends GameCondition {
  final Weather weather;

  const InWeatherCondition({required this.weather});

  @override
  bool isSatisfied(GameContext context) =>
      context.state.worldState.currentWeather == weather;

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'inWeather',
    'weather': weather.toJson(),
  };
}

/// Weather analog of [NotInBiomeCondition] — see `WorldState.currentWeather`.
final class NotInWeatherCondition extends GameCondition {
  final Weather weather;

  const NotInWeatherCondition({required this.weather});

  @override
  bool isSatisfied(GameContext context) =>
      context.state.worldState.currentWeather != weather;

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'notInWeather',
    'weather': weather.toJson(),
  };
}

/// Weather analog of [MinimumTurnsInBiomeCondition] — gates on how long the
/// current weather has held (see `WorldState.turnsInCurrentWeather`), the
/// same "random duration, minimum but no maximum" shape biome dwell uses,
/// on its own independent schedule.
final class MinimumTurnsInWeatherCondition extends GameCondition {
  final int turns;

  const MinimumTurnsInWeatherCondition({required this.turns});

  @override
  bool isSatisfied(GameContext context) =>
      context.state.worldState.turnsInCurrentWeather >= turns;

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'minimumTurnsInWeather',
    'turns': turns,
  };
}

/// Gates on the match's fixed [Season] — see `WorldState.currentSeason`.
/// Unlike biome/weather there is no dwell-time counterpart: a season never
/// changes mid-match, so this alone is enough to express "only in winter."
final class InSeasonCondition extends GameCondition {
  final Season season;

  const InSeasonCondition({required this.season});

  @override
  bool isSatisfied(GameContext context) =>
      context.state.worldState.currentSeason == season;

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'inSeason',
    'season': season.toJson(),
  };
}

/// Negation of [InSeasonCondition] — e.g. gating a route as impassable
/// specifically in winter without needing a separate "closed" flag.
final class NotInSeasonCondition extends GameCondition {
  final Season season;

  const NotInSeasonCondition({required this.season});

  @override
  bool isSatisfied(GameContext context) =>
      context.state.worldState.currentSeason != season;

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'notInSeason',
    'season': season.toJson(),
  };
}

/// Gates on how long the party has been inside the tavern this visit (see
/// `WorldState.turnsInTavern`) — the tavern-detour analog of
/// [MinimumTurnsInBiomeCondition]. Used by the tavern's own exit cards so
/// the party can't leave the instant it arrives; no upper bound, same
/// "minimum but no maximum" shape every biome dwell already has.
final class MinimumTurnsInTavernCondition extends GameCondition {
  final int turns;

  const MinimumTurnsInTavernCondition({required this.turns});

  @override
  bool isSatisfied(GameContext context) =>
      context.state.worldState.turnsInTavern >= turns;

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'minimumTurnsInTavern',
    'turns': turns,
  };
}

/// Gates on enough party steps having passed since [flag] was last set true
/// — see `WorldState.flagSetAtStep`. False if the flag was never set (or is
/// currently false). This is the whole mechanism behind a neutral event's
/// delayed payoff ("через несколько ходов"): the event that sets [flag]
/// looks completely ordinary, and nothing about it reveals whether some
/// later card is quietly waiting on this condition.
final class MinimumStepsSinceFlagCondition extends GameCondition {
  final String flag;
  final int steps;

  const MinimumStepsSinceFlagCondition({required this.flag, required this.steps});

  @override
  bool isSatisfied(GameContext context) {
    final worldState = context.state.worldState;
    if (!worldState.flag(flag)) return false;
    final setAtStep = worldState.flagSetAtStep[flag];
    if (setAtStep == null) return false;
    return context.state.partySteps - setAtStep >= steps;
  }

  @override
  Map<String, dynamic> toJson() => {
    'condition': 'minimumStepsSinceFlag',
    'flag': flag,
    'steps': steps,
  };
}

/// Gates on the party currently having a temporary leader — see
/// `WorldState.leaderId`/`LeaderParticipant`. Content that narratively
/// assumes a leader already exists ("Лидер ведёт переговоры") should use
/// this rather than relying on `LeaderParticipant`'s random-player
/// fallback, which would otherwise make some arbitrary player look like an
/// established leader who was never actually chosen.
final class LeaderIsSetCondition extends GameCondition {
  const LeaderIsSetCondition();

  @override
  bool isSatisfied(GameContext context) =>
      context.state.worldState.leaderId != null;

  @override
  Map<String, dynamic> toJson() => {'condition': 'leaderIsSet'};
}

final class LeaderIsUnsetCondition extends GameCondition {
  const LeaderIsUnsetCondition();

  @override
  bool isSatisfied(GameContext context) =>
      context.state.worldState.leaderId == null;

  @override
  Map<String, dynamic> toJson() => {'condition': 'leaderIsUnset'};
}
