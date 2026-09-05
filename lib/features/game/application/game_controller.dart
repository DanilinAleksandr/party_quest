import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game_engine/context/game_context.dart';
import '../../../game_engine/data/content_providers.dart';
import '../../../game_engine/logic/logic.dart';
import '../../../game_engine/models/models.dart';

/// Orchestrates one match's step flow. This is the only place that decides
/// *when* flow events fire, effects expire, and cards are drawn —
/// [ActionExecutor] only knows how to apply a single action, not the
/// surrounding step rules, and everything it and the other engine services
/// need travels through one [GameContext] rather than being threaded
/// through separately.
///
/// The party travels together now — there is no per-player turn order.
/// Every step is one shared event; the drawn card's own [EventParticipant]
/// decides which player(s) it's about, resolved by [ParticipantResolver]
/// before the card is shown (see [takeStep]/[resolveParticipant]).
///
/// The public contract stays `StateNotifier<GameState>`: the UI only ever
/// needs players/pending card/pending participant selection/pending
/// adventure node/status. [GameContext] — with its catalogs, random
/// provider and event bus — is an engine-internal detail this class owns
/// and never leaks to the widget layer.
class GameController extends StateNotifier<GameState> {
  final ActionExecutor _executor = const ActionExecutor();
  final EffectLifecycle _effectLifecycle = const EffectLifecycle();
  final ParticipantResolver _participantResolver = const ParticipantResolver();
  late final EventDispatcher _dispatcher;
  late final AdventureEngine _adventureEngine;
  late GameContext _context;

  /// The party's journey-length target, in `GameState.partySteps` — null
  /// means an infinite journey: no automatic finish, the party ends it by
  /// hand via [endJourneyManually]. Picked freely (not from a fixed set) by
  /// `game_setup_screen.dart`'s slider — see `JourneyLengthConfig`.
  final int? stepsToWin;

  GameController({
    required List<String> playerNames,
    required List<GameCard> cards,
    required ItemCatalog itemCatalog,
    required EffectCatalog effectCatalog,
    required AdventureCatalog adventureCatalog,
    required BiomeCatalog biomeCatalog,
    required OriginCatalog originCatalog,
    int? seed,
    GameMode mode = GameMode.classic,
    int? journeySteps = 20,
    // Every real match starts in JourneyPhase.prologue — see GameState
    // .newGame. This flag exists so tests that aren't about the prologue
    // itself (the vast majority) can start a controller already in
    // JourneyPhase.journey, the same way `seed` exists so tests can pin
    // randomness rather than because a real match ever wants to.
    bool skipPrologue = false,
  }) : stepsToWin = journeySteps,
       super(GameState.newGame(playerNames)) {
    _dispatcher = EventDispatcher(_executor);
    _adventureEngine = AdventureEngine(_executor);
    _context = GameContext(
      state: state,
      random: RandomProvider(seed: seed),
      cardCatalog: CardCatalog(cards),
      itemCatalog: itemCatalog,
      effectCatalog: effectCatalog,
      adventureCatalog: adventureCatalog,
      biomeCatalog: biomeCatalog,
      originCatalog: originCatalog,
      eventBus: GameEventBus(),
      mode: mode,
    );
    // Rolled once, here, using the match's own seeded random provider — same
    // seed always reproduces the same season, same as every other draw this
    // engine makes. Nothing ever changes it again after this (see
    // `WorldState.currentSeason`).
    final season = Season.values[_context.random.nextInt(Season.values.length)];
    _context = _context.withState(
      _context.state.copyWith(
        worldState: _context.state.worldState.copyWith(currentSeason: season),
      ),
    );
    if (skipPrologue) {
      _context = _context.withState(
        _context.state.copyWith(phase: JourneyPhase.journey),
      );
    }
    _setContext(_dispatcher.dispatch(const OnGameStarted(), _context));
  }

  /// The seed this match's randomness was derived from — the same seed
  /// reproduces the exact same sequence of draws, duel outcomes and
  /// adventure branches, which is what a "replay this game" or a
  /// daily-challenge mode needs.
  int get seed => _context.random.seed;

  void _setContext(GameContext context) {
    _context = context;
    state = context.state;
  }

  /// Runs one full party step: fires [OnTurnStarted], advances the party's
  /// shared progress, checks for a cooperative finish, expires every
  /// player's effects by one, draws a card, and resolves who it's about.
  ///
  /// A card whose [EventParticipant] needs the table to pick a player by
  /// hand (`ChosenParticipant`) suspends here — [state
  /// .pendingParticipantSelection] is set instead of [state.pendingCard],
  /// until [resolveParticipant] is called.
  void takeStep() {
    if (state.status == GameStatus.finished ||
        state.pendingCard != null ||
        state.pendingParticipantSelection != null) {
      return;
    }

    var ctx = _dispatcher.dispatch(
      OnTurnStarted(player: _context.currentPlayer),
      _context,
    );
    ctx = _incrementPartySteps(ctx);
    ctx = _incrementTurnsInBiome(ctx);
    ctx = _incrementTurnsInWeather(ctx);
    ctx = _incrementTurnsInTavern(ctx);

    if (stepsToWin != null && ctx.state.partySteps >= stepsToWin!) {
      _finishJourney(ctx);
      return;
    }

    ctx = _effectLifecycle.expireForAllPlayers(ctx);

    // A random player stands in as `currentPlayer` for eligibility checks
    // (e.g. `currentPlayerHasItem` on the card itself) before the card that
    // will actually run is even known — the same player is reused as the
    // final participant for the common case (no `participant` specified),
    // so a card's eligibility and its resolved actor never disagree.
    ctx = _resolvedOrThrow(
      _participantResolver.resolve(const RandomPlayerParticipant(), ctx),
    );
    final drawnCard = ctx.cardCatalog.drawEligibleCard(ctx);

    final resolution = drawnCard.participant is RandomPlayerParticipant
        ? ResolvedParticipant(ctx)
        : _participantResolver.resolve(drawnCard.participant, ctx);

    if (resolution is NeedsManualPick) {
      ctx = ctx.withState(
        ctx.state.copyWith(pendingParticipantSelection: drawnCard),
      );
      _setContext(ctx);
      return;
    }

    ctx = _resolvedOrThrow(resolution);
    _showCard(drawnCard, ctx);
  }

  /// Ends the journey on demand — the only way an infinite-length match
  /// (`stepsToWin == null`) ever finishes, since [takeStep] has no step
  /// target to compare against. Same finish sequence `takeStep` uses for a
  /// step-target win:
  /// status flips to [GameStatus.finished] and [OnJourneyCompleted] fires,
  /// so the win screen behaves identically either way. A no-op once the
  /// match is already finished, or mid-step (a card/participant pick is
  /// still pending) — ending mid-decision would strand that dialog.
  void endJourneyManually() {
    if (state.status == GameStatus.finished ||
        state.pendingCard != null ||
        state.pendingParticipantSelection != null) {
      return;
    }
    _finishJourney(_context);
  }

  void _finishJourney(GameContext ctx) {
    ctx = ctx.withState(ctx.state.copyWith(status: GameStatus.finished));
    ctx = _dispatcher.dispatch(OnJourneyCompleted(player: ctx.currentPlayer), ctx);
    _setContext(ctx);
  }

  /// Applies the table's pick for a card whose [EventParticipant] was
  /// `ChosenParticipant`, then shows it exactly like any other drawn card.
  void resolveParticipant(String playerId) {
    final card = _context.state.pendingParticipantSelection;
    if (card == null) return;

    final ctx = _participantResolver.resolveChosen(playerId, _context);
    _showCard(card, ctx);
  }

  void _showCard(GameCard drawnCard, GameContext context) {
    final card = _filterCardChoices(drawnCard, context);
    final worldState = context.state.worldState.copyWith(
      previousParticipantId: context.currentPlayer.id,
    );
    var ctx = context.withState(
      context.state.copyWith(
        pendingCard: card,
        clearPendingParticipantSelection: true,
        worldState: worldState,
      ),
    );
    ctx = _dispatcher.dispatch(
      OnCardDrawn(card: card, player: ctx.currentPlayer),
      ctx,
    );
    _setContext(ctx);
  }

  GameContext _resolvedOrThrow(ParticipantResolution resolution) =>
      switch (resolution) {
        ResolvedParticipant(context: final context) => context,
        NeedsManualPick() => throw StateError(
          'RandomPlayerParticipant must always resolve immediately.',
        ),
      };

  /// Narrows a drawn card's choices down to the ones the player is
  /// currently eligible for — mirrors how `AdventureEngine` filters a
  /// node's choices. If every choice happens to be conditioned out (a
  /// content-authoring mistake — always leave at least one unconditioned
  /// fallback choice), falls back to the full list rather than presenting a
  /// dialog with no buttons.
  GameCard _filterCardChoices(GameCard card, GameContext context) {
    if (!card.hasChoices) return card;
    final eligible = card.choices
        .where((c) => c.conditions.every((cond) => cond.isSatisfied(context)))
        .toList();
    return eligible.isEmpty ? card : card.withChoices(eligible);
  }

  /// Resolves the pending card: [choiceIndex] must be provided when the card
  /// has choices, and is ignored otherwise.
  ///
  /// If the card's action starts an adventure that needs player input, the
  /// step is left suspended — [state.activeAdventureId] is set and the card
  /// stays pending — until [resolveAdventureChoice] eventually walks the
  /// adventure to its end. Otherwise (no adventure, or one that resolved
  /// instantly with zero choices) the step finishes immediately, same as
  /// before adventures existed.
  void resolveCard({int? choiceIndex}) {
    final card = _context.state.pendingCard;
    if (card == null) return;

    final actions = card.hasChoices
        ? card.choices[choiceIndex!].actions
        : card.actions;
    final ctx = _executor.executeAll(actions, _context);

    if (ctx.state.activeAdventureId != null) {
      _setContext(ctx);
      return;
    }

    _finishCardResolution(card, ctx);
  }

  /// Resolves one choice at the current adventure node, continuing the
  /// adventure. If it concludes as a result, finishes resolving the card
  /// that originally started it — otherwise the step stays suspended at the
  /// next node.
  void resolveAdventureChoice(int choiceIndex) {
    final adventureId = _context.state.activeAdventureId;
    final node = _context.state.pendingAdventureNode;
    final card = _context.state.pendingCard;
    if (adventureId == null || node == null || card == null) return;

    final adventure = _context.adventureCatalog.byId(adventureId);
    final ctx = _adventureEngine.resolveChoice(
      adventure,
      node,
      choiceIndex,
      _context,
    );

    if (ctx.state.activeAdventureId != null) {
      _setContext(ctx);
      return;
    }

    _finishCardResolution(card, ctx);
  }

  /// The shared tail of resolving a step's card, whether or not it went
  /// through an adventure along the way: announce resolution, clear the
  /// card, announce the step ending. The next [takeStep] call resolves a
  /// fresh participant for whatever comes next — there's no "next player"
  /// to hand off to anymore.
  void _finishCardResolution(GameCard card, GameContext context) {
    final resolvedFor = context.currentPlayer;
    var ctx = _dispatcher.dispatch(
      OnCardResolved(card: card, player: resolvedFor, choiceIndex: null),
      context,
    );
    ctx = ctx.withState(
      ctx.state.copyWith(
        clearPendingCard: true,
        journeyLog: [
          ...ctx.state.journeyLog,
          JourneyLogEntry(
            text: '${resolvedFor.name}: ${card.title}',
            type: card.type,
            rarity: card.rarity,
            biomeId: ctx.state.worldState.currentBiomeId,
            relatedPlayerId: resolvedFor.id,
          ),
        ],
      ),
    );
    ctx = _dispatcher.dispatch(OnTurnFinished(player: resolvedFor), ctx);
    _setContext(ctx);
  }

  /// Skipped while the party is inside the tavern (`WorldState.flag(
  /// 'in_tavern')`) — a detour there shouldn't cost journey length, only
  /// real time. `turnsInCurrentBiome` (below) keeps counting regardless,
  /// uninterrupted by tavern visits, since the real biome never actually
  /// changes while inside one — see `turnsInTavern`/`_incrementTurnsInTavern`
  /// for the tavern's own local dwell counter.
  GameContext _incrementPartySteps(GameContext ctx) {
    if (ctx.state.worldState.flag('in_tavern')) {
      return ctx;
    }
    return ctx.withState(
      ctx.state.copyWith(partySteps: ctx.state.partySteps + 1),
    );
  }

  /// Counts every step toward how long the party has spent in the current
  /// biome — see `WorldState.turnsInCurrentBiome`. Reset to 0 by
  /// `SetBiomeAction` whenever the biome actually changes.
  GameContext _incrementTurnsInBiome(GameContext ctx) {
    final worldState = ctx.state.worldState.copyWith(
      turnsInCurrentBiome: ctx.state.worldState.turnsInCurrentBiome + 1,
    );
    return ctx.withState(ctx.state.copyWith(worldState: worldState));
  }

  /// Counts every step toward how long the current weather has held — see
  /// `WorldState.turnsInCurrentWeather`. Reset to 0 by `SetWeatherAction`
  /// whenever the weather actually changes; runs on its own schedule,
  /// entirely independent of `_incrementTurnsInBiome`.
  GameContext _incrementTurnsInWeather(GameContext ctx) {
    final worldState = ctx.state.worldState.copyWith(
      turnsInCurrentWeather: ctx.state.worldState.turnsInCurrentWeather + 1,
    );
    return ctx.withState(ctx.state.copyWith(worldState: worldState));
  }

  /// Counts turns spent on this specific tavern visit — see
  /// `WorldState.turnsInTavern`. Unlike `turnsInCurrentBiome`, this isn't
  /// reset by any action; it's derived fresh from the flag every turn
  /// (increment while inside, snap to 0 the instant the flag clears), since
  /// entering/leaving the tavern never calls `SetBiomeAction`.
  GameContext _incrementTurnsInTavern(GameContext ctx) {
    final inTavern = ctx.state.worldState.flag('in_tavern');
    final worldState = ctx.state.worldState.copyWith(
      turnsInTavern: inTavern ? ctx.state.worldState.turnsInTavern + 1 : 0,
    );
    return ctx.withState(ctx.state.copyWith(worldState: worldState));
  }
}

/// What `GameSetupScreen` collects before a match starts — bundled into one
/// record so the route arguments and the provider's family key stay a
/// single value instead of drifting apart as setup grows more options.
typedef GameSetupArgs = ({List<String> playerNames, int? journeySteps});

/// Keyed by the setup args record from game setup. Riverpod caches one
/// controller per distinct record value, which is exactly one per match
/// since the setup screen only ever passes a fresh record once.
final gameControllerProvider =
    StateNotifierProvider.family<GameController, GameState, GameSetupArgs>((
      ref,
      args,
    ) {
      final cards = ref.watch(cardsProvider).requireValue;
      final itemCatalog = ref.watch(itemCatalogProvider).requireValue;
      final effectCatalog = ref.watch(effectCatalogProvider).requireValue;
      final adventureCatalog = ref.watch(adventureCatalogProvider).requireValue;
      final biomeCatalog = ref.watch(biomeCatalogProvider).requireValue;
      final originCatalog = ref.watch(originCatalogProvider).requireValue;
      return GameController(
        playerNames: args.playerNames,
        cards: cards,
        itemCatalog: itemCatalog,
        effectCatalog: effectCatalog,
        adventureCatalog: adventureCatalog,
        biomeCatalog: biomeCatalog,
        originCatalog: originCatalog,
        journeySteps: args.journeySteps,
      );
    });
