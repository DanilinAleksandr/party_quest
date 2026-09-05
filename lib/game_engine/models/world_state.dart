import 'season.dart';
import 'weather.dart';

/// Global, persistent state of the game world — separate from any one
/// player. "The world remembers": a card or an adventure choice can check
/// what happened earlier in the game (did anyone steal the witch's book?
/// did the party help the merchant?) regardless of who did it or whose
/// turn it is now.
///
/// [flags] covers both "world flags" and "story flags" from the design doc
/// — they're the same mechanism (a named boolean fact), so one map covers
/// both; the distinction between the two is purely in how content authors
/// name their flags (`visited_witch_hut` vs `helped_merchant`), not in how
/// the engine stores or evaluates them.
///
/// [completedAdventures] is tracked automatically by `AdventureEngine`
/// whenever an adventure reaches its end, rather than needing every
/// adventure to remember to set its own "I finished" flag by hand.
///
/// "Unlocked encounters" from the design doc has no dedicated field: it's
/// just a [flags] entry plus a [WorldFlagSetCondition] on whichever card or
/// adventure choice should be gated by it — introducing a second parallel
/// concept for "unlocked" would only fragment where content authors have to
/// look to answer "why isn't this available yet?".
///
/// [currentBiomeId] is the party's current "chapter" — see `Biome`. The
/// default mirrors `GameConstants.startingBiomeId`; kept as a plain literal
/// here (rather than importing that constant) so this model stays a leaf
/// with no dependency on app-level configuration.
///
/// [turnsInCurrentBiome] counts turns (any player's) spent since the party
/// last entered [currentBiomeId] — `GameController` increments it every
/// turn, `SetBiomeAction` resets it to 0. This is the entire mechanism
/// behind "a biome lasts a random, unknown-in-advance number of turns": a
/// transition card gated on `MinimumTurnsInBiomeCondition` simply can't be
/// drawn before the minimum, and after that the normal weighted-draw
/// randomness decides turn by turn whether it fires, with no upper bound.
///
/// [previousParticipantId]/[previousWinnerId]/[previousLoserId]/[leaderId]
/// are the party's short-term memory of *who*, feeding `EventParticipant`
/// selectors (`PreviousParticipant`/`PreviousWinner`/`PreviousLoser`/
/// `LeaderParticipant`) so a card can build on the last event or an
/// ongoing role instead of only ever picking fresh. `GameController` sets
/// [previousParticipantId] once a step's participant is resolved;
/// `ActionExecutor` sets [previousWinnerId]/[previousLoserId] whenever a
/// `StartDuelAction` resolves; [leaderId] only ever changes via
/// `SetLeaderAction`, so unlike the other three it can stay the same
/// player across many steps until some event decides to hand it off.
///
/// [flagSetAtStep] records the `GameState.partySteps` value at the moment
/// each flag was last set true — stamped automatically by
/// `SetWorldFlagAction`, not something content authors set by hand. This is
/// the entire mechanism behind a delayed consequence ("через несколько
/// ходов"): `MinimumStepsSinceFlagCondition` just compares the current
/// party step against this stamp. A quiet, ordinary-looking card sets a
/// flag same as any other; whether anything ever reads it later — after a
/// delay, in a different biome, from a specific NPC — is entirely up to
/// what other content happens to check for it.
///
/// [currentWeather]/[turnsInCurrentWeather] are the weather analog of
/// [currentBiomeId]/[turnsInCurrentBiome] — a second, independent world
/// modifier layered on top of biome (see `Weather`). `GameController`
/// increments [turnsInCurrentWeather] every turn the same way it does for
/// [turnsInCurrentBiome]; `SetWeatherAction` resets it to 0. Kept fully
/// separate from biome on purpose: the party's location and the weather
/// around them change on independent schedules, so one `SetBiomeAction`
/// call must never reset the other's dwell counter.
///
/// [currentSeason] is rolled once, at the very start of a match (see
/// `GameController`'s constructor), and never changes again — unlike
/// [currentWeather] it has no dwell counter and no action ever sets it
/// after that initial roll. It's the outermost, longest-lasting of the
/// three world modifiers (biome/weather/season): a single journey always
/// happens in exactly one season, and `biomeAtmosphere` composes its line
/// together with the current weather's, so the same biome reads as a
/// different place across season × weather combinations without either
/// axis needing its own copy of the other's phrase table.
///
/// [turnsInTavern] is the tavern-detour analog of [turnsInCurrentBiome]:
/// how many turns the party has spent since entering the tavern (the
/// `in_tavern` flag), used by `MinimumTurnsInTavernCondition` to gate how
/// soon the party can leave. It can't just reuse [flagSetAtStep]/
/// `GameState.partySteps` the way other delayed content does, because
/// `partySteps` is deliberately frozen while `in_tavern` is set (a tavern
/// detour shouldn't cost journey length) — a frozen counter can never
/// satisfy a "steps since" check. `GameController` derives this purely
/// from current flag state each turn: incrementing while `in_tavern` is
/// set, snapping back to 0 the instant it isn't.
final class WorldState {
  final Map<String, bool> flags;
  final Set<String> completedAdventures;
  final Map<String, int> modifiers;
  final String currentBiomeId;
  final int turnsInCurrentBiome;
  final Weather currentWeather;
  final int turnsInCurrentWeather;
  final Season currentSeason;
  final int turnsInTavern;
  final String? previousParticipantId;
  final String? previousWinnerId;
  final String? previousLoserId;
  final String? leaderId;
  final Map<String, int> flagSetAtStep;

  const WorldState({
    this.flags = const {},
    this.completedAdventures = const {},
    this.modifiers = const {},
    this.currentBiomeId = 'forest',
    this.turnsInCurrentBiome = 0,
    this.currentWeather = Weather.sunny,
    this.turnsInCurrentWeather = 0,
    this.currentSeason = Season.summer,
    this.turnsInTavern = 0,
    this.previousParticipantId,
    this.previousWinnerId,
    this.previousLoserId,
    this.leaderId,
    this.flagSetAtStep = const {},
  });

  bool flag(String key) => flags[key] ?? false;

  int modifier(String key) => modifiers[key] ?? 0;

  WorldState withFlag(String key, bool value) =>
      copyWith(flags: {...flags, key: value});

  WorldState withModifier(String key, int delta) =>
      copyWith(modifiers: {...modifiers, key: modifier(key) + delta});

  WorldState withCompletedAdventure(String adventureId) =>
      copyWith(completedAdventures: {...completedAdventures, adventureId});

  WorldState copyWith({
    Map<String, bool>? flags,
    Set<String>? completedAdventures,
    Map<String, int>? modifiers,
    String? currentBiomeId,
    int? turnsInCurrentBiome,
    Weather? currentWeather,
    int? turnsInCurrentWeather,
    Season? currentSeason,
    int? turnsInTavern,
    String? previousParticipantId,
    String? previousWinnerId,
    String? previousLoserId,
    String? leaderId,
    Map<String, int>? flagSetAtStep,
  }) {
    return WorldState(
      flags: flags ?? this.flags,
      completedAdventures: completedAdventures ?? this.completedAdventures,
      modifiers: modifiers ?? this.modifiers,
      currentBiomeId: currentBiomeId ?? this.currentBiomeId,
      turnsInCurrentBiome: turnsInCurrentBiome ?? this.turnsInCurrentBiome,
      currentWeather: currentWeather ?? this.currentWeather,
      turnsInCurrentWeather: turnsInCurrentWeather ?? this.turnsInCurrentWeather,
      currentSeason: currentSeason ?? this.currentSeason,
      turnsInTavern: turnsInTavern ?? this.turnsInTavern,
      previousParticipantId: previousParticipantId ?? this.previousParticipantId,
      previousWinnerId: previousWinnerId ?? this.previousWinnerId,
      previousLoserId: previousLoserId ?? this.previousLoserId,
      leaderId: leaderId ?? this.leaderId,
      flagSetAtStep: flagSetAtStep ?? this.flagSetAtStep,
    );
  }

  factory WorldState.fromJson(Map<String, dynamic> json) => WorldState(
    flags: (json['flags'] as Map<String, dynamic>? ?? const {}).map(
      (k, v) => MapEntry(k, v as bool),
    ),
    completedAdventures:
        (json['completedAdventures'] as List<dynamic>? ?? const [])
            .cast<String>()
            .toSet(),
    modifiers: (json['modifiers'] as Map<String, dynamic>? ?? const {}).map(
      (k, v) => MapEntry(k, v as int),
    ),
    currentBiomeId: json['currentBiomeId'] as String? ?? 'forest',
    turnsInCurrentBiome: json['turnsInCurrentBiome'] as int? ?? 0,
    currentWeather: json['currentWeather'] == null
        ? Weather.sunny
        : Weather.fromJson(json['currentWeather'] as String),
    turnsInCurrentWeather: json['turnsInCurrentWeather'] as int? ?? 0,
    currentSeason: json['currentSeason'] == null
        ? Season.summer
        : Season.fromJson(json['currentSeason'] as String),
    turnsInTavern: json['turnsInTavern'] as int? ?? 0,
    previousParticipantId: json['previousParticipantId'] as String?,
    previousWinnerId: json['previousWinnerId'] as String?,
    previousLoserId: json['previousLoserId'] as String?,
    leaderId: json['leaderId'] as String?,
    flagSetAtStep: (json['flagSetAtStep'] as Map<String, dynamic>? ?? const {})
        .map((k, v) => MapEntry(k, v as int)),
  );

  Map<String, dynamic> toJson() => {
    'flags': flags,
    'completedAdventures': completedAdventures.toList(),
    'modifiers': modifiers,
    'currentBiomeId': currentBiomeId,
    'turnsInCurrentBiome': turnsInCurrentBiome,
    'currentWeather': currentWeather.toJson(),
    'turnsInCurrentWeather': turnsInCurrentWeather,
    'currentSeason': currentSeason.toJson(),
    'turnsInTavern': turnsInTavern,
    'previousParticipantId': previousParticipantId,
    'previousWinnerId': previousWinnerId,
    'previousLoserId': previousLoserId,
    'leaderId': leaderId,
    'flagSetAtStep': flagSetAtStep,
  };
}
