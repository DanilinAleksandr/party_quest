import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/steel_palette.dart';
import '../../../core/widgets/biome_banner.dart';
import '../../../core/widgets/game_result_card.dart';
import '../../../core/widgets/item_chip.dart';
import '../../../core/widgets/prologue_banner.dart';
import '../../../core/widgets/rest_banner.dart';
import '../../../core/widgets/tavern_banner.dart';
import 'scene_strip/scene_strip.dart';
import '../../../game_engine/data/content_providers.dart';
import '../../../game_engine/logic/logic.dart';
import '../../../game_engine/models/models.dart';
import '../../settings/application/walk_settings.dart';
import '../application/adventure_names.dart';
import '../application/auto_walk_timer.dart';
import '../application/game_controller.dart';
import '../application/result_diff.dart';
import '../application/result_entry.dart';
import 'widgets/adventure_node_dialog.dart';
import 'widgets/card_resolution_dialog.dart';
import 'widgets/chance_check_dialog.dart';
import 'widgets/continue_journey_button.dart';
import 'widgets/choice_outcome_dialog.dart';
import 'widgets/journey_log_sheet.dart';
import 'widgets/journey_trail.dart';
import 'widgets/origin_reveal_screen.dart';
import 'widgets/participant_selection_dialog.dart';
import 'widgets/player_profile_sheet.dart';
import 'widgets/player_status_panel.dart';
import 'widgets/season_reveal_dialog.dart';
import 'widgets/wager_call_dialog.dart';
import 'win_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  final GameSetupArgs setupArgs;

  const GameScreen({super.key, required this.setupArgs});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

/// How long the party walks into a new biome before the next card: long
/// enough for the strip to carry it in, so a card — a halt above all — does
/// not arrive over the old road like a teleport.
const Duration kBiomeEntryPause = Duration(seconds: 7);

class _GameScreenState extends ConsumerState<GameScreen> {
  late final AutoWalkTimer _autoWalk = AutoWalkTimer(onStep: _walkOn);

  /// The biome the screen last drew, to notice the party entering another.
  String? _seenBiomeId;

  /// Walking on its own: the next countdown is at least [kBiomeEntryPause],
  /// until a step has been taken in the new biome.
  bool _enteringBiome = false;

  /// Walking by hand: the button waits out [kBiomeEntryPause].
  Timer? _entryHold;

  void _noticeBiome(String biomeId) {
    final seen = _seenBiomeId;
    _seenBiomeId = biomeId;
    if (seen == null || seen == biomeId) return;
    _enteringBiome = true;
    _entryHold?.cancel();
    _entryHold = Timer(kBiomeEntryPause, () {
      if (mounted) setState(() => _entryHold = null);
    });
  }

  GameSetupArgs get setupArgs => widget.setupArgs;

  /// What the open card dialog shows — see [CardDialogView].
  ValueNotifier<CardDialogView>? _cardView;

  /// The state as the current card was drawn — the baseline its results
  /// are measured from.
  GameState? _stateAtDraw;

  CardDialogView _viewOf(GameState state) {
    final notifier = ref.read(gameControllerProvider(setupArgs).notifier);
    final card = state.pendingCard!;
    final wasted =
        state.currentPlayer.intoxicationLevel == IntoxicationLevel.wasted;
    final taken = notifier.personalActionTaken;
    return (
      card: card,
      personal: (
        canDrink: notifier.canDrinkForCourage,
        // Said only where the drink would otherwise have been offered.
        tooDrunk: wasted && !taken && card.hasChoices,
        items: notifier.usableItems,
      ),
    );
  }

  /// Whether the party should be walking on its own right now.
  ///
  /// [GameState] alone cannot answer this. A card stops being pending the
  /// moment it is resolved, while its result cards are still being read;
  /// an adventure's nodes, the season reveal and the journey log all sit
  /// over this screen without being a pending card at all. So the one
  /// question that covers every one of them is asked of the navigator:
  /// is anything on top of the game? `ModalRoute.of` rebuilds this screen
  /// whenever that answer changes, which is what restarts the countdown
  /// after the last result card is dismissed.
  ///
  /// Everywhere once the match has begun — the prologue, the tavern and the
  /// halt included. The one press walking on its own asks for is the first,
  /// «НАЧАТЬ»: the table says when the evening starts, and from then on the
  /// road runs by itself. A playtest had somebody press «Продолжить поход»
  /// through a whole prologue on auto, wondering why nobody was walking.
  bool _canWalk(GameState state, WalkSettings walk, {required bool onTop}) =>
      walk.mode == WalkMode.auto &&
      onTop &&
      _hasStarted(state) &&
      state.status == GameStatus.inProgress &&
      state.pendingCard == null &&
      state.pendingParticipantSelection == null;

  /// `partySteps` counts the prologue too and only stands still inside a
  /// tavern or a halt, neither of which can be the first step — so zero
  /// means nobody has pressed anything yet.
  static bool _hasStarted(GameState state) => state.partySteps > 0;

  /// Stopped somewhere rather than on the road.
  static bool _inDetour(GameState state) =>
      state.worldState.flag('in_tavern') ||
      state.worldState.flag('in_rest') ||
      state.worldState.flag('in_village');

  /// The countdown ran out. Everything is checked once more rather than
  /// trusted from the last rebuild: a dialog pushed in the same frame would
  /// not have told this screen yet.
  void _walkOn() {
    if (!mounted) return;
    final provider = gameControllerProvider(setupArgs);
    final onTop = ModalRoute.isCurrentOf(context) ?? true;
    if (!_canWalk(
      ref.read(provider),
      ref.read(walkSettingsProvider),
      onTop: onTop,
    )) {
      return;
    }
    _enteringBiome = false;
    ref.read(provider.notifier).takeStep();
  }

  @override
  void dispose() {
    _entryHold?.cancel();
    _autoWalk.dispose();
    _cardView?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = gameControllerProvider(setupArgs);
    final gameState = ref.watch(provider);
    final stepsToWin = ref.watch(provider.notifier).stepsToWin;
    final origins = ref.watch(originCatalogProvider).valueOrNull;
    final biomes = ref.watch(biomeCatalogProvider).valueOrNull;

    ref.listen<GameState>(provider, (previous, next) async {
      final participantPickJustOpened =
          next.pendingParticipantSelection != null &&
          previous?.pendingParticipantSelection !=
              next.pendingParticipantSelection;
      if (participantPickJustOpened) {
        showParticipantSelectionDialog(
          context: context,
          card: next.pendingParticipantSelection!,
          players: next.players,
          onSelect: (playerId) =>
              ref.read(provider.notifier).resolveParticipant(playerId),
        );
      }

      // A card is drawn when there was none. The pending card can also
      // change *while* its dialog is open — a drink for courage narrows its
      // choices again — and that is the same draw, told to the open dialog
      // rather than opening a second one.
      final cardJustDrawn =
          next.pendingCard != null && previous?.pendingCard == null;
      final sameCardChanged =
          !cardJustDrawn &&
          next.pendingCard != null &&
          previous?.pendingCard != next.pendingCard;
      if (sameCardChanged) {
        _cardView?.value = _viewOf(next);
      }
      if (cardJustDrawn) {
        final card = next.pendingCard!;
        _stateAtDraw = next;
        _cardView?.dispose();
        final view = _cardView = ValueNotifier(_viewOf(next));
        showCardResolutionDialog(
          context: context,
          card: card,
          live: view,
          onDrinkForCourage: () =>
              ref.read(provider.notifier).drinkForCourage(),
          onUseItem: (itemId) => ref.read(provider.notifier).useItem(itemId),
          participants: _participantsFor(next, card.participant),
          origins: origins,
          adventureNames: rememberedAdventureNames(
            ref.read(adventureEntryTitlesProvider),
            next.journeyLog,
          ),
          // The outcome is told *before* the choice reaches the controller,
          // not after, and that is what keeps the two screens in the order
          // the player reads them. Resolving is synchronous, and the state
          // change it makes reaches this very listener — and therefore the
          // first result card — before an `await`ed dialog could get its own
          // route onto the navigator. Resolving first would stack the
          // outcome on top of the ledger of what it did.
          onResolve: (choiceIndex) async {
            // The whole beat, in the order the table reads it: call it,
            // watch it land, hear what that meant, and only then does
            // anything change. The throw is made before any of it — see
            // `GameController.roll` — so the die cannot disagree with what
            // the engine goes on to apply.
            final notifier = ref.read(provider.notifier);
            // The card as it stands now, not as it was drawn: a drink for
            // courage may have changed which choice sits at [choiceIndex].
            final current = ref.read(provider).pendingCard ?? card;
            final gamble = notifier.gambleFor(choiceIndex: choiceIndex);
            CoinThrow? coin;

            if (gamble != null) {
              final called = await showWagerCallDialog(
                context: context,
                sides: gamble.sides,
              );
              if (!context.mounted) return;

              coin = notifier.roll();
              await showChanceCheckDialog(
                context: context,
                style: notifier.coinStyle(),
                passed: coin.favours,
                edge: coin == CoinThrow.edge,
                sides: gamble.sides,
                calledIndex: called,
                challenger: gamble.challenger,
                opponent: gamble.opponent,
              );
              if (!context.mounted) return;

              // A gamble's own words win over the choice's, and are told as
              // part of the scene: the choice was made before anybody knew
              // how it would go, so it cannot be the one to say how it went.
              await tellGambleOutcome(
                context,
                gamble.outcomeForThrow(coin),
                cardTitle: card.title,
              );
              if (!context.mounted) return;
            }

            final choiceOutcome = choiceIndex == null
                ? null
                : current.choices[choiceIndex].outcome;

            // A check nobody watches: thrown all the same, and told as a
            // plain consequence — what was in the bag, not whether a coin
            // came down King.
            final hidden = gamble == null
                ? notifier.hiddenCheckFor(choiceIndex: choiceIndex)
                : null;
            if (hidden != null) {
              // Out of sight there is no coin, and so no edge.
              coin = notifier.roll(watched: false);
              await tellChoiceOutcome(
                context,
                (coin.favours ? hidden.winnerOutcome : hidden.loserOutcome) ??
                    choiceOutcome,
              );
              if (!context.mounted) return;
            } else if (coin == null) {
              await tellChoiceOutcome(context, choiceOutcome);
              if (!context.mounted) return;
            }
            notifier.resolveCard(
              choiceIndex: choiceIndex,
              gambleWon: coin?.favours,
              opponentId: gamble?.opponentId,
              coinEdge: coin == CoinThrow.edge,
            );
          },
        );
      }

      final adventureNodeChanged =
          next.pendingAdventureNode != null &&
          previous?.pendingAdventureNode != next.pendingAdventureNode;
      if (adventureNodeChanged) {
        final node = next.pendingAdventureNode!;
        showAdventureNodeDialog(
          context: context,
          node: node,
          participants: next.secondaryPlayer == null
              ? [next.currentPlayer]
              : [next.currentPlayer, next.secondaryPlayer!],
          origins: origins,
          adventureNames: rememberedAdventureNames(
            ref.read(adventureEntryTitlesProvider),
            next.journeyLog,
          ),
          onChoice: (choiceIndex) async {
            await tellChoiceOutcome(context, node.choices[choiceIndex].outcome);
            if (!context.mounted) return;
            ref.read(provider.notifier).resolveAdventureChoice(choiceIndex);
          },
        );
      }

      final justLeftPrologue =
          previous?.phase == JourneyPhase.prologue &&
          next.phase == JourneyPhase.journey;
      if (justLeftPrologue) {
        await showSeasonRevealDialog(context, next.worldState.currentSeason);
        if (!context.mounted) return;
      }

      final cardResolvedWithoutAdventure =
          previous?.pendingCard != null &&
          next.pendingCard == null &&
          next.activeAdventureId == null;
      if (cardResolvedWithoutAdventure) {
        // Measured from when the card was drawn, not from just before the
        // choice: a drink for courage or a draught taken on the card is part
        // of what happened on it, and the table should hear about it.
        final before = _stateAtDraw ?? previous!;
        final entries = computeResultEntries(
          previous: before,
          next: next,
          targets: _diffTargets(
            before,
            next,
            previous!.pendingCard!.participant,
          ),
          originCatalog: origins ?? const OriginCatalog({}),
        );
        await _showResults(context, entries, origins);
        if (!context.mounted) return;
      }

      final adventureJustFinished =
          previous?.activeAdventureId != null && next.activeAdventureId == null;
      if (adventureJustFinished) {
        final entries = computeResultEntries(
          previous: previous!,
          next: next,
          targets: _diffTargets(
            previous,
            next,
            const TwoRandomPlayersParticipant(),
          ),
          originCatalog: origins ?? const OriginCatalog({}),
        );
        await _showResults(context, entries, origins);
        if (!context.mounted) return;
      }

      final justFinished =
          next.status == GameStatus.finished &&
          previous?.status != GameStatus.finished;
      if (justFinished) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WinScreen(finalState: next, originCatalog: origins),
          ),
        );
      }
    });

    final canTakeStep =
        gameState.pendingCard == null &&
        gameState.pendingParticipantSelection == null &&
        gameState.status == GameStatus.inProgress;
    final walk = ref.watch(walkSettingsProvider);
    final started = _hasStarted(gameState);
    final inDetour = _inDetour(gameState);
    final inRest = gameState.worldState.flag('in_rest');
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    _noticeBiome(gameState.worldState.currentBiomeId);
    final timerRuns = _canWalk(gameState, walk, onTop: onTop);
    // Idempotent: a countdown already running is left to finish, and one
    // that should not be running is dropped. Doing it here rather than in a
    // listener is what lets a route change — not only a state change —
    // start and stop it.
    final entryPause = _enteringBiome ? kBiomeEntryPause.inSeconds : 0;
    _autoWalk.update(
      canWalk: timerRuns,
      minDelaySeconds: math.max(walk.minDelay, entryPause),
      maxDelaySeconds: math.max(walk.maxDelay, entryPause),
    );
    final currentBiome = biomes?.byId(gameState.worldState.currentBiomeId);

    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: SteelPalette.background,
      appBar: AppBar(
        backgroundColor: SteelPalette.background,
        surfaceTintColor: Colors.transparent,
        // Left, not centred: the title is a mark of where you are, and the
        // theme's centred Material title reads as an app bar rather than as
        // the chrome of a game.
        centerTitle: false,
        titleSpacing: 20,
        title: Text(
          'Алко-Квест',
          style: textTheme.titleLarge?.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.71,
            color: SteelPalette.textLow,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Журнал путешествия',
            icon: const Icon(Icons.menu_book_outlined, size: 21),
            color: SteelPalette.steelDim,
            onPressed: () => showJourneyLogSheet(
              context: context,
              journeyLog: gameState.journeyLog,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            children: [
              if (gameState.phase == JourneyPhase.prologue) ...[
                const PrologueBanner(),
                const SizedBox(height: 16),
              ] else if (currentBiome != null) ...[
                BiomeBanner(
                  biome: currentBiome,
                  weather: gameState.worldState.currentWeather,
                  season: gameState.worldState.currentSeason,
                ),
                if (gameState.worldState.flag('in_tavern')) ...[
                  const SizedBox(height: 8),
                  const TavernBanner(),
                ],
                if (inRest) ...[const SizedBox(height: 8), const RestBanner()],
                const SizedBox(height: 18),
              ],
              // One strip for the whole journey: the road in the current
              // biome, or the stop the party is at. It moves exactly while
              // the party walks on its own, and stands on its current frame
              // for everything that stops the timer: a dialog, a match not
              // yet begun or over, walking by hand.
              SceneStrip(
                biomeId: gameState.worldState.currentBiomeId,
                moving: timerRuns,
                stop: inRest
                    ? StripStop.rest
                    : gameState.worldState.flag('in_tavern')
                    ? StripStop.tavern
                    : gameState.worldState.flag('in_village')
                    ? StripStop.village
                    : StripStop.none,
              ),
              const SizedBox(height: 14),
              if (stepsToWin != null)
                JourneyTrail(
                  partySteps: gameState.partySteps,
                  totalSteps: stepsToWin,
                )
              else
                // No length means no notches to draw: the endless journey
                // keeps its own row rather than pretending to have a
                // destination it can measure against.
                Row(
                  children: [
                    const Icon(
                      Icons.all_inclusive,
                      size: 18,
                      color: SteelPalette.steel,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Шаг ${gameState.partySteps} — путешествие без конца',
                        style: textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.88,
                          color: SteelPalette.textLow.withValues(alpha: 0.66),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: gameState.status == GameStatus.inProgress
                          ? () =>
                                ref.read(provider.notifier).endJourneyManually()
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: SteelPalette.steel,
                      ),
                      child: const Text('Завершить путешествие'),
                    ),
                  ],
                ),
              if (gameState.partyInventory.isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'СНАРЯЖЕНИЕ ПАРТИИ',
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.52,
                        color: SteelPalette.textLow.withValues(alpha: 0.66),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: gameState.partyInventory
                            .map((item) => ItemChip(item: item))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: SingleChildScrollView(
                    child: Column(
                      children: _rosterRows(
                        players: gameState.players,
                        card: (player) {
                          final playerOrigin = player.originId == null
                              ? null
                              : origins?.byId(player.originId!);
                          return PlayerStatusPanel(
                            player: player,
                            origin: playerOrigin,
                            onTap: () => showPlayerProfileSheet(
                              context: context,
                              player: player,
                              origin: playerOrigin,
                              partyInventory: gameState.partyInventory,
                              worldState: gameState.worldState,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // Walking on its own, the button is there once, to begin;
              // walking by hand, it is there every turn, and says what the
              // press will do from where the party is standing.
              if (walk.mode == WalkMode.manual || !started) ...[
                const SizedBox(height: 4),
                ContinueJourneyButton(
                  label: !started
                      ? 'НАЧАТЬ'
                      // Nobody "continues the journey" from a campfire.
                      : inDetour
                      ? 'ДАЛЬШЕ'
                      : 'ПРОДОЛЖИТЬ ПОХОД',
                  onPressed: canTakeStep && _entryHold == null
                      ? () => ref.read(provider.notifier).takeStep()
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Walks the changes a resolved event produced, one moment at a time.
///
/// An origin reveal takes over the whole screen instead of arriving as
/// another small result card. Every playtest audit called it the best and
/// most under-shown moment in a match, and it cannot be that while it looks
/// exactly like picking up a flask. The small card is *replaced*, not
/// preceded, so the table gets one ceremony rather than two in a row; the
/// half-second flash in the roster card stays where it is, for whenever a
/// player opens their profile later.
Future<void> _showResults(
  BuildContext context,
  List<ResultEntry> entries,
  OriginCatalog? origins,
) async {
  for (final entry in entries) {
    final originId = entry.originId;
    if (entry.kind == ResultKind.originRevealed &&
        originId != null &&
        origins != null &&
        origins.contains(originId)) {
      await showOriginRevealScreen(
        context,
        playerName: entry.playerName ?? '',
        origin: origins.byId(originId),
      );
    } else {
      await showGameResultCard(context, entry);
    }
    if (!context.mounted) return;
  }
}

/// Lays the roster out two to a row, with an odd last player taking the
/// whole width instead of leaving a hole beside them.
///
/// Built by hand rather than with a grid: every grid widget in the
/// framework either forces one cell size on all children or needs a
/// staggered-layout package, and this is four lines of `Row`.
///
/// Both cards in a row share the taller one's height. The alternative —
/// reserving space for chips a player might one day pick up — means
/// guessing a maximum and then either guessing low or leaving a hole under
/// most cards for most of the match. [IntrinsicHeight] costs one extra
/// layout pass over two cards and always matches whatever is actually
/// there.
List<Widget> _rosterRows({
  required List<Player> players,
  required Widget Function(Player player) card,
}) {
  final rows = <Widget>[];
  for (var i = 0; i < players.length; i += 2) {
    if (i > 0) rows.add(const SizedBox(height: 10));
    if (i == players.length - 1) {
      rows.add(SizedBox(width: double.infinity, child: card(players[i])));
    } else {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: card(players[i])),
              const SizedBox(width: 10),
              Expanded(child: card(players[i + 1])),
            ],
          ),
        ),
      );
    }
  }
  return rows;
}

/// Resolves who to show in [EventParticipantBanner] for a just-drawn card —
/// a pure switch on [EventParticipant]'s runtime type, since the actual
/// resolution (who `ActionTarget.currentPlayer`/`.secondaryPlayer` refer to)
/// already happened before the card reached [GameState.pendingCard]. Null
/// means "the whole party" (`WholeGroupParticipant`).
List<Player>? _participantsFor(GameState state, EventParticipant participant) {
  return switch (participant) {
    WholeGroupParticipant() => null,
    TwoRandomPlayersParticipant() =>
      state.secondaryPlayer == null
          ? [state.currentPlayer]
          : [state.currentPlayer, state.secondaryPlayer!],
    _ => [state.currentPlayer],
  };
}

/// Same "who was this about" resolution as [_participantsFor], but returns
/// the *pre-resolution* `Player` objects (looked up in [previous] by id) so
/// [computeResultEntries] has a stable before-state to diff against — using
/// `next.currentPlayer`/`.secondaryPlayer` directly would already reflect
/// whatever the event just changed.
List<Player> _diffTargets(
  GameState previous,
  GameState next,
  EventParticipant participant,
) {
  final ids = switch (participant) {
    WholeGroupParticipant() => next.players.map((p) => p.id).toSet(),
    TwoRandomPlayersParticipant() => {
      next.currentPlayer.id,
      if (next.secondaryPlayer != null) next.secondaryPlayer!.id,
    },
    _ => {next.currentPlayer.id},
  };
  return previous.players.where((p) => ids.contains(p.id)).toList();
}
