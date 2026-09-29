import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game_engine/context/game_context.dart';
import '../../../game_engine/data/content_providers.dart';
import '../../../game_engine/logic/logic.dart';
import '../../../game_engine/models/models.dart';

/// What the UI needs to know about a gamble a choice is about to take,
/// without being told which of the two engine actions is behind it.
///
/// `chanceCheck` and `duel` differ in who else is involved and in what the
/// engine records afterwards. From the seat of the player who tapped, they
/// are the same question — did this come off? — so the screen asks it once,
/// the same way, and this is the shape of that question.
final class Gamble {
  /// The two things the player can call before the throw, or empty when the
  /// scene has nobody in it to call against — see [ChanceCheckAction.sides].
  final List<String> sides;

  final String? winnerOutcome;
  final String? loserOutcome;

  /// A check's own words for a coin on its edge; a duel has none.
  final String? edgeOutcome;

  /// The two players a duel is between, or null for a solo risk.
  ///
  /// [challenger] is whoever tapped; [opponent] is the companion the engine
  /// drew to face them, picked here rather than inside the executor so the
  /// screen can name them both before a single effect lands. Without this
  /// the result read as an impersonal "не повезло" while the penalty
  /// quietly went to somebody else at the table.
  final String? challenger;
  final String? opponent;
  final String? opponentId;

  const Gamble({
    this.sides = const [],
    this.winnerOutcome,
    this.loserOutcome,
    this.edgeOutcome,
    this.challenger,
    this.opponent,
    this.opponentId,
  });

  bool get hasCall => sides.length == 2;

  bool get isDuel => opponentId != null;

  /// The text for the branch that happened, with the two players' names
  /// filled in.
  ///
  /// `{winner}`/`{loser}` follow the same convention `AddChronicleEntryAction`
  /// uses for `{player}`: content is written once and reads correctly
  /// whichever way the coin fell, which is the only way a duel's words can
  /// name the person the penalty actually landed on.
  String? outcomeFor({required bool won}) {
    final text = won ? winnerOutcome : loserOutcome;
    if (text == null) return null;
    final challenger = this.challenger;
    final opponent = this.opponent;
    if (challenger == null || opponent == null) return text;
    return text
        .replaceAll('{winner}', won ? challenger : opponent)
        .replaceAll('{loser}', won ? opponent : challenger);
  }

  /// [outcomeFor], for any of the three ways the coin can come down. A duel
  /// on its edge is a draw and says so in its own words; a check on its
  /// edge uses its [edgeOutcome], or [kCoinEdgeOutcome].
  String? outcomeForThrow(CoinThrow coin) {
    if (coin != CoinThrow.edge) return outcomeFor(won: coin == CoinThrow.win);
    final challenger = this.challenger;
    final opponent = this.opponent;
    if (isDuel && challenger != null && opponent != null) {
      return kDuelEdgeOutcome
          .replaceAll('{challenger}', challenger)
          .replaceAll('{opponent}', opponent);
    }
    return edgeOutcome ?? kCoinEdgeOutcome;
  }
}

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
    int restInterval = kRestInterval,
    // Every real match starts in JourneyPhase.prologue — see GameState
    // .newGame. This flag exists so tests that aren't about the prologue
    // itself (the vast majority) can start a controller already in
    // JourneyPhase.journey, the same way `seed` exists so tests can pin
    // randomness rather than because a real match ever wants to.
    bool skipPrologue = false,
    // Rolled from the seed in a real match; tests about the drink pin them
    // so one drink is one.
    List<int>? ages,
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
      restInterval: restInterval,
    );
    // Rolled once, here, using the match's own seeded random provider — same
    // seed always reproduces the same season, same as every other draw this
    // engine makes. Nothing ever changes it again after this (see
    // `WorldState.currentSeason`).
    final season = Season.values[_context.random.nextInt(Season.values.length)];
    ages ??= rollAges(_context.random.seed, _context.players.length);
    _context = _context.withState(
      _context.state.copyWith(
        worldState: _context.state.worldState.copyWith(currentSeason: season),
        players: [
          for (final (i, p) in _context.players.indexed)
            p.copyWith(age: ages[i]),
        ],
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

  /// Runs one full party step: advances the party's
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

    var ctx = _incrementPartySteps(_context);
    ctx = _incrementTurnsInBiome(ctx);
    ctx = _incrementTurnsInWeather(ctx);
    ctx = _incrementTurnsInTavern(ctx);
    ctx = _incrementTurnsInRest(ctx);

    if (stepsToWin != null && ctx.state.partySteps >= stepsToWin!) {
      _finishJourney(ctx);
      return;
    }

    // Only what was already on at the last draw counts down: an effect put
    // on during that card has not had a card of its own yet. So a duration
    // is exactly the number of cards drawn while the effect is on.
    ctx = _effectLifecycle.expireForAllPlayers(
      ctx,
      ticks: (player, effect) =>
          _effectsAtDraw[player.id]?.contains(effect.id) ?? false,
    );

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
    ctx = _dispatcher.dispatch(
      OnJourneyCompleted(player: ctx.currentPlayer),
      ctx,
    );
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

  /// The drawn card as it was before [_filterCardChoices] narrowed it. A
  /// personal action can change what the player qualifies for, so the
  /// choices are narrowed again from here — not from what is on screen,
  /// which would never bring back a choice that was hidden before the drink.
  GameCard? _drawnCard;

  /// One personal action per card: a drink for courage or an item used.
  bool _personalActionTaken = false;

  /// Everyone's scale as the current card was drawn — see [_afterCard].
  Map<String, double> _intoxicationAtDraw = const {};

  /// Which effects each player had on when the current card was drawn — the
  /// ones that count down at the next step.
  Map<String, Set<String>> _effectsAtDraw = const {};

  bool get personalActionTaken => _personalActionTaken;

  /// Whether «Для храбрости» can be offered right now. Not on a card without
  /// choices — there is nothing for a drink to change there — and not to a
  /// player who is already wasted.
  bool get canDrinkForCourage {
    final card = _drawnCard;
    return card != null &&
        state.pendingCard != null &&
        state.activeAdventureId == null &&
        card.hasChoices &&
        !_personalActionTaken &&
        _context.currentPlayer.intoxicationLevel != IntoxicationLevel.wasted;
  }

  /// The current player's items that can be used by hand from a card, one
  /// of each kind.
  List<InventoryItem> get usableItems {
    if (state.pendingCard == null ||
        state.activeAdventureId != null ||
        _personalActionTaken) {
      return const [];
    }
    final seen = <String>{};
    return [
      for (final item in _context.currentPlayer.inventory)
        if (item.usageType == ItemUsageType.manual &&
            item.useActions.isNotEmpty &&
            seen.add(item.id))
          item,
    ];
  }

  /// «Для храбрости»: the current player drinks one, and the card's choices
  /// are narrowed again from the card as drawn.
  void drinkForCourage() {
    if (!canDrinkForCourage) return;
    _takePersonalAction(_executor.execute(const DrinkAction(), _context));
  }

  /// Uses [itemId] from the current player's inventory: its actions run for
  /// them, a consumable is spent, and the choices are narrowed again.
  void useItem(String itemId) {
    final item = usableItems.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return;
    final player = _context.currentPlayer;
    var ctx = _executor.executeAsPlayer(item.useActions, player.id, _context);
    if (item.isConsumable) {
      ctx = _executor.executeAsPlayer(
        [TakeItemAction(itemId: item.id)],
        player.id,
        ctx,
      );
    }
    _takePersonalAction(ctx);
  }

  void _takePersonalAction(GameContext ctx) {
    _personalActionTaken = true;
    final drawn = _drawnCard!;
    _setContext(
      ctx.withState(
        ctx.state.copyWith(pendingCard: _filterCardChoices(drawn, ctx)),
      ),
    );
  }

  void _showCard(GameCard drawnCard, GameContext context) {
    // The turn is the card's: whoever it is about has their turn start now,
    // before the card is shown or anything on it is measured.
    context = _dispatcher.dispatch(
      OnTurnStarted(player: context.currentPlayer),
      context,
    );
    _drawnCard = drawnCard;
    _personalActionTaken = false;
    _intoxicationAtDraw = {
      for (final p in context.players) p.id: p.intoxication,
    };
    _effectsAtDraw = {
      for (final p in context.players)
        p.id: {for (final e in p.activeEffects) e.id},
    };
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
  /// The gamble a choice is about to take, or null when it takes none.
  ///
  /// Covers both kinds: a `chanceCheck` against fate and a `duel` against
  /// another player. From the current player's seat they are the same
  /// question — did this come off? — and both deserve the same visible
  /// throw. A duel at a table of one is excluded, because the engine
  /// declines to hold one and nothing would follow the animation.
  Gamble? gambleFor({int? choiceIndex}) {
    final card = _context.state.pendingCard;
    if (card == null) return null;

    for (final action in _actionsFor(card, choiceIndex)) {
      switch (action) {
        // Thrown out of sight — see [hiddenCheckFor].
        case ChanceCheckAction a when !a.open:
          continue;
        case ChanceCheckAction a:
          return Gamble(
            sides: a.sides,
            winnerOutcome: a.winnerOutcome,
            loserOutcome: a.loserOutcome,
            edgeOutcome: a.edgeOutcome,
          );
        case StartDuelAction a:
          final opponents = _context.players
              .where((p) => p.id != _context.currentPlayer.id)
              .toList();
          if (opponents.isEmpty) return null;
          final opponent = opponents[_context.random.nextInt(opponents.length)];
          return Gamble(
            sides: a.sides,
            winnerOutcome: a.winnerOutcome,
            loserOutcome: a.loserOutcome,
            challenger: _context.currentPlayer.name,
            opponent: opponent.name,
            opponentId: opponent.id,
          );
        default:
          continue;
      }
    }
    return null;
  }

  /// The chance check a choice is about to make out of sight — one with
  /// `open: false` — or null when it makes none.
  ///
  /// No coin and no call: the UI throws with [roll] exactly as for a gamble,
  /// so it can tell the player what came of it *before* resolving, and then
  /// hands the same answer to [resolveCard]. Only the throw's being watched
  /// is left out.
  ChanceCheckAction? hiddenCheckFor({int? choiceIndex}) {
    final card = _context.state.pendingCard;
    if (card == null) return null;
    for (final action in _actionsFor(card, choiceIndex)) {
      if (action is ChanceCheckAction && !action.open) return action;
    }
    return null;
  }

  /// Throws for a gamble [gambleFor] found, or a check [hiddenCheckFor]
  /// found.
  ///
  /// The throw happens here, before anything is applied, because the UI has
  /// to show the same result the engine settles on and has to show it
  /// *first*. Resolving is synchronous and its state change reaches
  /// `ref.listen` — and therefore the first result card — before an awaited
  /// animation could get its own route onto the navigator, the same race the
  /// outcome dialog had to be ordered around. Hand the value back to
  /// [resolveCard] and the two agree by construction.
  ///
  /// [watched] is whether the table sees a coin: only a watched coin can
  /// stand on its edge. The face is drawn from the match's stream exactly as
  /// before the edge existed, and the edge from a stream of its own, so a
  /// seed replays every face it always did.
  CoinThrow roll({bool watched = true}) {
    final won = _context.random.nextBool();
    if (watched && _context.random.nextEdge(kCoinEdgeChance)) {
      return CoinThrow.edge;
    }
    return won ? CoinThrow.win : CoinThrow.lose;
  }

  /// The chronicle's line for a coin that stood on its edge in [action] —
  /// null when [action] is not the watched throw.
  String? _edgeChronicleLine(
    GameCard card,
    GameAction action,
    GameContext ctx,
    String? opponentId,
  ) {
    final player = ctx.currentPlayer.name;
    switch (action) {
      case ChanceCheckAction a when a.open:
        return '«${card.title}» — $player бросает монету, и она встаёт на '
            'ребро.';
      case StartDuelAction _:
        final opponent = ctx.players
            .where((p) => p.id == opponentId)
            .firstOrNull
            ?.name;
        if (opponent == null) return null;
        return '«${card.title}» — $player и $opponent бросают монету, и она '
            'встаёт на ребро.';
      default:
        return null;
    }
  }

  List<GameAction> _actionsFor(GameCard card, int? choiceIndex) =>
      card.hasChoices ? card.choices[choiceIndex!].actions : card.actions;

  /// [gambleWon], when given, is the throw [roll] already made and the UI
  /// already showed, and it settles every gamble in this step — the engine
  /// is told the answer instead of quietly rolling a second one.
  ///
  /// The value is passed to the executor's own duel/chance-check methods
  /// rather than flattening the action list here, because a duel's two
  /// branches land on two different players and a flat list cannot say that.
  /// Either way `ActionExecutor` keeps a complete implementation of its own:
  /// every gamble nobody pre-rolled — inside an adventure, on an effect's
  /// reaction — still rolls for itself.
  ///
  /// [coinEdge] is a watched coin that stood on its edge (see [roll]): it
  /// settles the gamble as an edge whatever [gambleWon] says, and goes into
  /// the chronicle as the legend it is.
  void resolveCard({
    int? choiceIndex,
    bool? gambleWon,
    String? opponentId,
    bool coinEdge = false,
  }) {
    final card = _context.state.pendingCard;
    if (card == null) return;
    if (coinEdge) gambleWon ??= true;

    var ctx = _context;
    String? edgeLine;
    for (final action in _actionsFor(card, choiceIndex)) {
      if (coinEdge && edgeLine == null) {
        edgeLine = _edgeChronicleLine(card, action, ctx, opponentId);
      }
      ctx = switch (action) {
        ChanceCheckAction a when gambleWon != null =>
          _executor.resolveChanceCheck(
            a,
            ctx,
            passed: gambleWon,
            edge: coinEdge && a.open,
          ),
        StartDuelAction a when gambleWon != null => _executor.startDuel(
          a,
          ctx,
          currentPlayerWins: gambleWon,
          opponentId: opponentId,
          edge: coinEdge,
        ),
        _ => _executor.execute(action, ctx),
      };
    }
    if (edgeLine != null) {
      ctx = ctx.withState(
        ctx.state.copyWith(
          chronicle: [
            ...ctx.state.chronicle,
            ChronicleEntry(text: edgeLine, coinEdge: true),
          ],
        ),
      );
    }

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
    ctx = _afterCard(ctx);
    _drawnCard = null;
    _setContext(ctx);
  }

  /// What one played card does to everybody's drinking: the scale wears
  /// down, a sleeper counts down towards waking, and whoever came back down
  /// from drunk gets the hangover for it.
  ///
  /// Counted per card rather than per step. Inside a tavern or at a halt
  /// `partySteps` stands still, and that is exactly where people need to
  /// sober up; at the fire they sleep it off three times as fast, and the
  /// halt lifts a hangover outright.
  GameContext _afterCard(GameContext ctx) {
    final resting = ctx.state.worldState.flag('in_rest');
    final wearsOff = kSoberingPerCard * (resting ? kRestSoberingFactor : 1);
    final hangovers = <String>[];

    Player wearOff(Player player) {
      // Whoever drank on this card does not sober on it too. With the
      // thresholds where they are, one drink is exactly "навеселе", and a
      // tenth off on the same card would make it vanish before anybody saw
      // it.
      final atDraw = _intoxicationAtDraw[player.id];
      if (atDraw != null && player.intoxication > atDraw) {
        if (player.wasDrunk && player.intoxication < kDrunkAt) {
          if (!resting) hangovers.add(player.id);
          return player.copyWith(wasDrunk: false);
        }
        return player;
      }
      if (player.isPassedOut) {
        final left = player.passedOutCards - 1;
        if (left > 0) return player.copyWith(passedOutCards: left);
        // Slept it off — and woke up to pay for it.
        hangovers.add(player.id);
        return player.copyWith(
          passedOutCards: 0,
          intoxication: 0,
          wasDrunk: false,
        );
      }
      // Hundredths, kept as hundredths: float drift must never turn ten
      // cards of sobering into nine and a bit. Hundredths rather than tenths,
      // because an old hand's drink is 0.75.
      final raw = player.intoxication - wearsOff;
      final intoxication = raw <= 0 ? 0.0 : (raw * 100).round() / 100;
      if (player.wasDrunk && intoxication < kDrunkAt) {
        if (!resting) hangovers.add(player.id);
        return player.copyWith(intoxication: intoxication, wasDrunk: false);
      }
      return player.copyWith(intoxication: intoxication);
    }

    final players = [for (final p in ctx.players) wearOff(p)];
    ctx = ctx.withState(ctx.state.copyWith(players: players));

    if (ctx.effectCatalog.contains(kHangoverEffectId)) {
      for (final id in hangovers) {
        ctx = _executor.executeAsPlayer(
          const [ApplyEffectAction(effectId: kHangoverEffectId)],
          id,
          ctx,
        );
        ctx = ctx.withState(
          ctx.state.copyWith(
            players: [
              for (final p in ctx.players)
                p.id == id ? p.withHangoverForAge() : p,
            ],
          ),
        );
      }
    }
    if (resting) {
      ctx = ctx.withState(
        ctx.state.copyWith(
          players: [
            for (final p in ctx.players)
              p.isHungover
                  ? p.copyWith(
                      activeEffects: p.activeEffects
                          .where((e) => e.id != kHangoverEffectId)
                          .toList(),
                    )
                  : p,
          ],
        ),
      );
    }
    return ctx;
  }

  /// Skipped while the party is inside the tavern (`WorldState.flag(
  /// 'in_tavern')`) — a detour there shouldn't cost journey length, only
  /// real time. `turnsInCurrentBiome` (below) keeps counting regardless,
  /// uninterrupted by tavern visits, since the real biome never actually
  /// changes while inside one — see `turnsInTavern`/`_incrementTurnsInTavern`
  /// for the tavern's own local dwell counter.
  GameContext _incrementPartySteps(GameContext ctx) {
    final world = ctx.state.worldState;
    if (world.flag('in_tavern') || world.flag('in_rest')) {
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

  /// The same counter for a halt at the fire — see `WorldState.turnsInRest`.
  /// Kept beside its twin rather than folded into one method taking a flag
  /// name: they are two separate detours that happen to have the same shape,
  /// and a shared helper would only make the next one that *doesn't* share
  /// it harder to add.
  GameContext _incrementTurnsInRest(GameContext ctx) {
    final inRest = ctx.state.worldState.flag('in_rest');
    final worldState = ctx.state.worldState.copyWith(
      turnsInRest: inRest ? ctx.state.worldState.turnsInRest + 1 : 0,
    );
    return ctx.withState(ctx.state.copyWith(worldState: worldState));
  }
}

/// What `GameSetupScreen` collects before a match starts — bundled into one
/// record so the route arguments and the provider's family key stay a
/// single value instead of drifting apart as setup grows more options.
typedef GameSetupArgs = ({
  List<String> playerNames,
  int? journeySteps,
  int restInterval,
});

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
        restInterval: args.restInterval,
      );
    });
