import 'package:uuid/uuid.dart';

import 'adventure_node.dart';
import 'chronicle_entry.dart';
import 'game_card.dart';
import 'game_status.dart';
import 'inventory_item.dart';
import 'journey_log_entry.dart';
import 'journey_phase.dart';
import 'player.dart';
import 'world_state.dart';

/// The full state of one match, as held by `GameController`.
///
/// The party travels together — there is no per-player turn order anymore.
/// [partySteps] is the party's shared progress toward the win condition.
/// [currentPlayerIndex] (and [secondaryPlayerIndex]) are a *transient*
/// resolution detail: whichever player(s) the current event's participant
/// selector picked, for the duration of resolving that one card — not a
/// persistent "whose turn it is." See `EventParticipant`/
/// `ParticipantResolver`.
final class GameState {
  final List<Player> players;
  final int currentPlayerIndex;

  /// The second player picked by a `TwoRandomPlayersParticipant` selector,
  /// if the current event's card called for one — see `ActionTarget
  /// .secondaryPlayer`. Null for every other selector.
  final int? secondaryPlayerIndex;

  final GameStatus status;

  /// How many steps the party has taken together so far — the sole
  /// progress counter toward `GameConstants.stepsToWin`. Replaces what used
  /// to be a per-player `steps` field: since the whole party always
  /// advances together, one shared counter is the only one that means
  /// anything.
  final int partySteps;

  /// The card currently drawn and awaiting resolution, or null when there is
  /// nothing for the UI to show a dialog for.
  final GameCard? pendingCard;

  /// Non-null while a just-drawn card's participant selector needs the
  /// table to pick a player by hand (`ChosenParticipant`) before the card
  /// itself can be shown — see `GameController.resolveParticipant`. Mutually
  /// exclusive with [pendingCard]: the card moves from here into
  /// [pendingCard] once a player is picked.
  final GameCard? pendingParticipantSelection;

  /// Items the whole party shares (a map, a tent, a keg) rather than any one
  /// player carrying them — see `InventoryItem.ownership`.
  final List<InventoryItem> partyInventory;

  /// Global world/story memory — see [WorldState].
  final WorldState worldState;

  /// Non-null while the current player is inside a multi-node adventure
  /// (see `AdventureEngine`): the id of the adventure they're in, and the
  /// node they're currently at, already filtered to the choices they're
  /// actually eligible to see. The normal turn flow (advancing to the next
  /// player) is suspended for as long as these are set.
  final String? activeAdventureId;
  final AdventureNode? pendingAdventureNode;

  /// A structured entry per resolved step, oldest first — purely a UI
  /// convenience (the journey log sheet, the win screen's derived stats)
  /// with no gameplay weight; nothing reads it back the way
  /// `WorldState.flags` drives content. See
  /// `GameController._finishCardResolution`, the only place that appends to
  /// it. See `JourneyLogEntry` for why this isn't just `List<String>`.
  final List<JourneyLogEntry> journeyLog;

  /// "Летопись путешествия" — a short, hand-authored, oldest-first record of
  /// only the moments worth retelling after the match (a true nature
  /// revealed, an alliance formed, a legendary confrontation resolved), as
  /// opposed to [journeyLog]'s "every step, mechanically." Only
  /// `AddChronicleEntryAction` ever appends to this — see [ChronicleEntry].
  final List<ChronicleEntry> chronicle;

  /// Which broad stretch of the match this is — see [JourneyPhase]. Defaults
  /// to [JourneyPhase.journey] (the steady state most tests/callers care
  /// about); [GameState.newGame] is the one place that starts a match in
  /// [JourneyPhase.prologue] instead.
  final JourneyPhase phase;

  const GameState({
    required this.players,
    required this.currentPlayerIndex,
    required this.status,
    this.secondaryPlayerIndex,
    this.partySteps = 0,
    this.pendingCard,
    this.pendingParticipantSelection,
    this.partyInventory = const [],
    this.worldState = const WorldState(),
    this.activeAdventureId,
    this.pendingAdventureNode,
    this.journeyLog = const [],
    this.chronicle = const [],
    this.phase = JourneyPhase.journey,
  });

  /// Every player starts with no origin — see `Origin`/`RevealOriginAction`.
  /// Origins are hidden at the start of a match and only surface through
  /// rare in-game events, never chosen at setup. Every match starts in
  /// [JourneyPhase.prologue] — see `CardCatalog.eligibleCards`.
  factory GameState.newGame(List<String> playerNames) {
    const uuid = Uuid();
    return GameState(
      players: playerNames
          .map((name) => Player(id: uuid.v4(), name: name))
          .toList(),
      currentPlayerIndex: 0,
      status: GameStatus.inProgress,
      phase: JourneyPhase.prologue,
    );
  }

  Player get currentPlayer => players[currentPlayerIndex];

  Player? get secondaryPlayer =>
      secondaryPlayerIndex == null ? null : players[secondaryPlayerIndex!];

  GameState copyWith({
    List<Player>? players,
    int? currentPlayerIndex,
    int? secondaryPlayerIndex,
    bool clearSecondaryPlayer = false,
    GameStatus? status,
    int? partySteps,
    GameCard? pendingCard,
    bool clearPendingCard = false,
    GameCard? pendingParticipantSelection,
    bool clearPendingParticipantSelection = false,
    List<InventoryItem>? partyInventory,
    WorldState? worldState,
    String? activeAdventureId,
    AdventureNode? pendingAdventureNode,
    bool clearActiveAdventure = false,
    List<JourneyLogEntry>? journeyLog,
    List<ChronicleEntry>? chronicle,
    JourneyPhase? phase,
  }) {
    return GameState(
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      secondaryPlayerIndex: clearSecondaryPlayer
          ? null
          : (secondaryPlayerIndex ?? this.secondaryPlayerIndex),
      status: status ?? this.status,
      partySteps: partySteps ?? this.partySteps,
      pendingCard: clearPendingCard ? null : (pendingCard ?? this.pendingCard),
      pendingParticipantSelection: clearPendingParticipantSelection
          ? null
          : (pendingParticipantSelection ?? this.pendingParticipantSelection),
      partyInventory: partyInventory ?? this.partyInventory,
      worldState: worldState ?? this.worldState,
      activeAdventureId: clearActiveAdventure
          ? null
          : (activeAdventureId ?? this.activeAdventureId),
      pendingAdventureNode: clearActiveAdventure
          ? null
          : (pendingAdventureNode ?? this.pendingAdventureNode),
      journeyLog: journeyLog ?? this.journeyLog,
      chronicle: chronicle ?? this.chronicle,
      phase: phase ?? this.phase,
    );
  }
}
