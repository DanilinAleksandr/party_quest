import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/steel_palette.dart';
import '../../../core/widgets/biome_banner.dart';
import '../../../core/widgets/game_result_card.dart';
import '../../../core/widgets/item_chip.dart';
import '../../../core/widgets/prologue_banner.dart';
import '../../../core/widgets/tavern_banner.dart';
import '../../../game_engine/data/content_providers.dart';
import '../../../game_engine/logic/logic.dart';
import '../../../game_engine/models/models.dart';
import '../application/game_controller.dart';
import '../application/result_diff.dart';
import 'widgets/adventure_node_dialog.dart';
import 'widgets/card_resolution_dialog.dart';
import 'widgets/journey_log_sheet.dart';
import 'widgets/journey_trail.dart';
import 'widgets/participant_selection_dialog.dart';
import 'widgets/player_profile_sheet.dart';
import 'widgets/player_status_panel.dart';
import 'widgets/season_reveal_dialog.dart';
import 'widgets/take_step_button.dart';
import 'win_screen.dart';

class GameScreen extends ConsumerWidget {
  final GameSetupArgs setupArgs;

  const GameScreen({super.key, required this.setupArgs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

      final cardJustDrawn =
          next.pendingCard != null && previous?.pendingCard != next.pendingCard;
      if (cardJustDrawn) {
        showCardResolutionDialog(
          context: context,
          card: next.pendingCard!,
          participants: _participantsFor(next, next.pendingCard!.participant),
          origins: origins,
          onResolve: (choiceIndex) =>
              ref.read(provider.notifier).resolveCard(choiceIndex: choiceIndex),
        );
      }

      final adventureNodeChanged =
          next.pendingAdventureNode != null &&
          previous?.pendingAdventureNode != next.pendingAdventureNode;
      if (adventureNodeChanged) {
        showAdventureNodeDialog(
          context: context,
          node: next.pendingAdventureNode!,
          participants: next.secondaryPlayer == null
              ? [next.currentPlayer]
              : [next.currentPlayer, next.secondaryPlayer!],
          origins: origins,
          onChoice: (choiceIndex) =>
              ref.read(provider.notifier).resolveAdventureChoice(choiceIndex),
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
        final entries = computeResultEntries(
          previous: previous!,
          next: next,
          targets: _diffTargets(
            previous,
            next,
            previous.pendingCard!.participant,
          ),
          originCatalog: origins ?? const OriginCatalog({}),
        );
        for (final entry in entries) {
          await showGameResultCard(context, entry);
          if (!context.mounted) return;
        }
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
        for (final entry in entries) {
          await showGameResultCard(context, entry);
          if (!context.mounted) return;
        }
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
                const SizedBox(height: 18),
              ],
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
              const SizedBox(height: 4),
              TakeStepButton(
                onPressed: canTakeStep
                    ? () => ref.read(provider.notifier).takeStep()
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
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
