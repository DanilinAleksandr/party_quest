import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/effect_chip.dart';
import '../../../core/widgets/fade_scale_in.dart';
import '../../../core/widgets/item_chip.dart';
import '../../../core/widgets/origin_badge.dart';
import '../../../core/widgets/stat_chip.dart';
import '../../../game_engine/logic/logic.dart';
import '../../../game_engine/models/models.dart';

/// Shown once the party's journey ends together — either by reaching the
/// chosen step target, or (for an infinite-length journey) by the party
/// ending it by hand via `GameController.endJourneyManually`.
/// Either way it's a shared journey's end, not one player crossing a finish
/// line first. A full screen rather than a dialog: this is the one moment
/// in the match that deserves the whole frame, a recap, and a beat of
/// celebration.
class WinScreen extends StatefulWidget {
  final GameState finalState;
  final OriginCatalog? originCatalog;

  const WinScreen({super.key, required this.finalState, this.originCatalog});

  @override
  State<WinScreen> createState() => _WinScreenState();
}

class _WinScreenState extends State<WinScreen> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.finalState;
    final players = state.players;
    final journeyStats = _JourneyStats.from(state);

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  FadeScaleIn(
                    child: Icon(
                      Icons.emoji_events,
                      size: 72,
                      color: AppColors.rarityColor(Rarity.legendary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeScaleIn(
                    delay: const Duration(milliseconds: 80),
                    child: Text(
                      'Путешествие завершено!',
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Who the party turned out to be comes first, then what
                  // the journey is remembered for, and only then the
                  // counters. The recap cards and the chronicle are what the
                  // table actually retells and screenshots; the tiles are
                  // usually small single digits at ordinary journey lengths,
                  // and opening on four of those made a forty-minute journey
                  // look smaller than it was.
                  for (var i = 0; i < players.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FadeScaleIn(
                        delay: Duration(milliseconds: 140 + i * 90),
                        child: _PlayerRecapCard(
                          player: players[i],
                          allPlayers: players,
                          origin: players[i].originId == null
                              ? null
                              : widget.originCatalog?.byId(
                                  players[i].originId!,
                                ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FadeScaleIn(
                    delay: Duration(milliseconds: 180 + players.length * 90),
                    child: _ChronicleSection(entries: state.chronicle),
                  ),
                  const SizedBox(height: 28),
                  FadeScaleIn(
                    delay: Duration(milliseconds: 240 + players.length * 90),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _StatTile(
                          icon: Icons.directions_walk,
                          value: '${journeyStats.steps}',
                          label: 'шагов пройдено',
                        ),
                        _StatTile(
                          icon: Icons.map_outlined,
                          value: '${journeyStats.biomesVisited}',
                          label: 'биомов посещено',
                        ),
                        _StatTile(
                          icon: Icons.auto_stories_outlined,
                          value: '${journeyStats.adventuresCompleted}',
                          label: 'приключений завершено',
                        ),
                        _StatTile(
                          icon: Icons.help_outline,
                          value: '${journeyStats.originsRevealed}',
                          label: 'происхождений раскрыто',
                        ),
                        if (journeyStats.legendaryEventsSeen > 0)
                          _StatTile(
                            icon: Icons.workspace_premium,
                            value: '${journeyStats.legendaryEventsSeen}',
                            label: 'легендарных событий',
                            color: AppColors.rarityColor(Rarity.legendary),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeScaleIn(
                    delay: Duration(milliseconds: 300 + players.length * 90),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).popUntil(
                          (route) =>
                              route.settings.name == AppRoutes.mainMenu ||
                              route.isFirst,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('На главный экран'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 24,
              maxBlastForce: 18,
              minBlastForce: 6,
              gravity: 0.25,
              colors: [
                AppColors.rarityColor(Rarity.legendary),
                AppColors.rarityColor(Rarity.epic),
                AppColors.rarityColor(Rarity.rare),
                theme.colorScheme.primary,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Летопись путешествия" — the short, hand-authored list of moments the
/// table will actually retell, as opposed to the stat tiles above (numbers)
/// or the full mid-game journal (every step). Reads `GameState.chronicle`
/// verbatim: each entry is already a complete, worded phrase (see
/// `ChronicleEntry`/`AddChronicleEntryAction`), so this widget has nothing
/// to derive — just lay the lines out, oldest first, as a short story.
class _ChronicleSection extends StatelessWidget {
  final List<ChronicleEntry> entries;

  const _ChronicleSection({required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.rarityColor(Rarity.legendary).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_stories,
                color: AppColors.rarityColor(Rarity.legendary),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('Летопись путешествия', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              'Путешествие обошлось без легенд — просто хорошая дорога вместе.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(entry.text, style: theme.textTheme.bodyMedium),
              ),
        ],
      ),
    );
  }
}

class _PlayerRecapCard extends StatelessWidget {
  final Player player;
  final List<Player> allPlayers;
  final Origin? origin;

  const _PlayerRecapCard({
    required this.player,
    required this.allPlayers,
    required this.origin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = {
      for (final stat in StatType.values) stat: player.stats.valueOf(stat),
    }..removeWhere((_, value) => value == 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.playerAvatarColor(
                    player.id,
                  ).withValues(alpha: 0.25),
                  child: Text(
                    player.name.isEmpty ? '?' : player.name[0].toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.playerAvatarColor(player.id),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(player.name, style: theme.textTheme.titleMedium),
                      Text(
                        _titleFor(player, allPlayers, origin),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                OriginBadge(origin: origin),
              ],
            ),
            if (stats.isNotEmpty || player.activeEffects.isNotEmpty || player.inventory.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in stats.entries)
                    StatChip(stat: entry.key, value: entry.value),
                  for (final effect in player.activeEffects)
                    EffectChip(effect: effect),
                  for (final item in player.inventory) ItemChip(item: item),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A handful of lighthearted, derived-only titles — nothing new tracked
/// during the match, purely a read of the final `GameState`. Priority
/// order: a revealed epic/legendary origin is the rarest, most narratively
/// loaded thing that can happen to a player, so it always wins; below that,
/// simple superlatives across the final party state.
String _titleFor(Player player, List<Player> allPlayers, Origin? origin) {
  if (origin != null && origin.rarity == Rarity.legendary) {
    return '🌟 Живая легенда стола';
  }
  if (origin != null && origin.rarity == Rarity.epic) {
    return '✨ Хранитель тайны';
  }
  if (player.curses.isNotEmpty) return '😈 Магнит проклятий';

  final maxItems = allPlayers.map((p) => p.inventory.length).reduce(
    (a, b) => a > b ? a : b,
  );
  if (maxItems > 0 && player.inventory.length == maxItems) {
    return '🎒 Коллекционер похода';
  }

  final statSum = StatType.values
      .map((s) => player.stats.valueOf(s))
      .fold(0, (a, b) => a + b);
  final maxStatSum = allPlayers
      .map(
        (p) => StatType.values
            .map((s) => p.stats.valueOf(s))
            .fold(0, (a, b) => a + b),
      )
      .reduce((a, b) => a > b ? a : b);
  if (maxStatSum > 0 && statSum == maxStatSum) return '💪 Сердце похода';

  return '🍻 Верный спутник';
}

/// Journey-wide numbers for the win screen — every field is derived purely
/// from the final [GameState] (including `journeyLog`, which already
/// stamps each entry's biome and rarity), so this adds no new tracking of
/// its own. "Всего выпито глотков" from the request is deliberately not
/// here: nothing in the engine counts sips today, and adding that counter
/// is exactly the kind of new mechanic this pass was asked to leave for a
/// separate stage.
class _JourneyStats {
  final int steps;
  final int biomesVisited;
  final int adventuresCompleted;
  final int originsRevealed;
  final int legendaryEventsSeen;

  const _JourneyStats({
    required this.steps,
    required this.biomesVisited,
    required this.adventuresCompleted,
    required this.originsRevealed,
    required this.legendaryEventsSeen,
  });

  factory _JourneyStats.from(GameState state) {
    final biomeIds = state.journeyLog
        .map((e) => e.biomeId)
        .whereType<String>()
        .toSet();
    return _JourneyStats(
      steps: state.partySteps,
      biomesVisited: biomeIds.length,
      adventuresCompleted: state.worldState.completedAdventures.length,
      originsRevealed: state.players.where((p) => p.originId != null).length,
      legendaryEventsSeen: state.journeyLog
          .where((e) => e.rarity == Rarity.legendary)
          .length,
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tint, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
