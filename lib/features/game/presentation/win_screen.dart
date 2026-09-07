import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/steel_palette.dart';
import '../../../core/widgets/effect_chip.dart';
import '../../../core/widgets/fade_scale_in.dart';
import '../../../core/widgets/item_chip.dart';
import '../../../core/widgets/line_icons.dart';
import '../../../core/widgets/origin_badge.dart';
import '../../../core/widgets/rarity_frame.dart';
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
  static const double _sidePadding = 24;

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
      backgroundColor: SteelPalette.background,
      body: Stack(
        children: [
          SafeArea(
            // No horizontal padding here on purpose: the chronicle runs to
            // both edges of the screen, and everything else pays for its
            // own margins. A padded scroll view would box it in.
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const FadeScaleIn(child: _VictorySeal()),
                  const SizedBox(height: 18),
                  FadeScaleIn(
                    delay: const Duration(milliseconds: 80),
                    child: Text(
                      'Путешествие\nзавершено',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 27,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: SteelPalette.textHigh,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const FadeScaleIn(
                    delay: Duration(milliseconds: 110),
                    child: _GoldDivider(),
                  ),
                  const SizedBox(height: 22),
                  // Who the party turned out to be comes first, then what
                  // the journey is remembered for, and only then the
                  // counters. The recap cards and the chronicle are what the
                  // table actually retells and screenshots; the tiles are
                  // usually small single digits at ordinary journey lengths,
                  // and opening on four of those made a forty-minute journey
                  // look smaller than it was.
                  for (var i = 0; i < players.length; i++)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _sidePadding,
                        0,
                        _sidePadding,
                        12,
                      ),
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
                  const SizedBox(height: 12),
                  FadeScaleIn(
                    delay: Duration(milliseconds: 180 + players.length * 90),
                    child: _ChronicleSection(entries: state.chronicle),
                  ),
                  const SizedBox(height: 26),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _sidePadding,
                    ),
                    child: Column(
                      children: [
                        FadeScaleIn(
                          delay: Duration(
                            milliseconds: 240 + players.length * 90,
                          ),
                          child: _StatGrid(stats: journeyStats),
                        ),
                        const SizedBox(height: 20),
                        FadeScaleIn(
                          delay: Duration(
                            milliseconds: 300 + players.length * 90,
                          ),
                          child: _HomeButton(
                            onPressed: () => Navigator.of(context).popUntil(
                              (route) =>
                                  route.settings.name == AppRoutes.mainMenu ||
                                  route.isFirst,
                            ),
                          ),
                        ),
                      ],
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

/// The gold used across this screen: the seal, the divider, the chronicle's
/// rules and markers. Same value as the legendary rarity accent — here it
/// means "this was the whole journey", which is the one other thing in the
/// game worth spending it on.
Color get _gold => AppColors.rarityColor(Rarity.legendary);

/// A struck seal rather than Material's filled trophy glyph.
class _VictorySeal extends StatelessWidget {
  const _VictorySeal();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(0, -0.25),
          radius: 0.9,
          colors: [_gold.withValues(alpha: 0.2), _gold.withValues(alpha: 0.04)],
        ),
        border: Border.all(color: _gold.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(color: _gold.withValues(alpha: 0.28), blurRadius: 22),
        ],
      ),
      child: LineIcon(
        shape: LineIconShape.trophy,
        size: 34,
        color: _gold,
        strokeWidth: 1.4,
      ),
    );
  }
}

/// Two tapering rules meeting at a lozenge — the same mark the title screen
/// and the origin reveal use, in gold.
class _GoldDivider extends StatelessWidget {
  const _GoldDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Row(
        children: [
          Expanded(child: _Rule(fadesInwards: true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Transform.rotate(
              angle: math.pi / 4,
              child: SizedBox.square(
                dimension: 5,
                child: ColoredBox(color: _gold.withValues(alpha: 0.9)),
              ),
            ),
          ),
          Expanded(child: _Rule(fadesInwards: false)),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final bool fadesInwards;

  const _Rule({required this.fadesInwards});

  @override
  Widget build(BuildContext context) {
    final colors = [_gold.withValues(alpha: 0), _gold.withValues(alpha: 0.6)];
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fadesInwards ? colors : colors.reversed.toList(),
        ),
      ),
    );
  }
}

/// "Летопись путешествия" — the short, hand-authored list of moments the
/// table will actually retell, as opposed to the stat tiles below (numbers)
/// or the full mid-game journal (every step). Reads `GameState.chronicle`
/// verbatim: each entry is already a complete, worded phrase (see
/// `ChronicleEntry`/`AddChronicleEntryAction`), so this widget has nothing
/// to derive — just lay the lines out, oldest first, as a short story.
///
/// It runs edge to edge, with rules along its top and bottom instead of a
/// border all the way round. A rounded card would have made the chronicle
/// one more panel among the recap cards; a band that breaks the margin
/// reads as a page from a different book, which is what it is.
class _ChronicleSection extends StatelessWidget {
  final List<ChronicleEntry> entries;

  const _ChronicleSection({required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF181B1F),
        border: Border(
          top: BorderSide(color: _gold.withValues(alpha: 0.36)),
          bottom: BorderSide(color: _gold.withValues(alpha: 0.36)),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_gold.withValues(alpha: 0.07), _gold.withValues(alpha: 0)],
          stops: const [0, 0.7],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_stories_outlined, color: _gold, size: 16),
              const SizedBox(width: 9),
              Text(
                'ЛЕТОПИСЬ ПУТЕШЕСТВИЯ',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.4,
                  color: _gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text(
              'Путешествие обошлось без легенд — просто хорошая дорога вместе.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13.5,
                height: 1.45,
                color: SteelPalette.textLow.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: _gold.withValues(alpha: 0.28)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Transform.translate(
                              // Half the lozenge hangs off the rule, so it
                              // sits *on* the line rather than beside it.
                              offset: const Offset(-3.5, 0),
                              child: Transform.rotate(
                                angle: math.pi / 4,
                                child: SizedBox.square(
                                  dimension: 5,
                                  child: ColoredBox(color: _gold),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              entry.text,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 13.5,
                                height: 1.45,
                                color: SteelPalette.textLow,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
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
    final title = _titleFor(player, allPlayers, origin);

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181B1F),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      SteelPalette.steel.withValues(alpha: 0.16),
                      Colors.black.withValues(alpha: 0.28),
                    ],
                  ),
                ),
                child: Text(
                  player.name.isEmpty ? '?' : player.name[0].toUpperCase(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: SteelPalette.textHigh,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // The badge shares a line with the name only. Sitting it
              // beside the whole column squeezed both lines, and the title
              // — the longer of the two — was the one that got cut.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A Wrap, not a Row: when a long name meets a long
                    // origin the badge drops to its own line instead of
                    // being cut to "Луннорождё…". Neither of the two is
                    // worth truncating — they are the whole point of the
                    // card.
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          player.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: SteelPalette.textHigh,
                          ),
                        ),
                        if (origin != null) OriginBadge(origin: origin),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        LineIcon(
                          shape: title.icon,
                          size: 14,
                          color: SteelPalette.textLow.withValues(alpha: 0.7),
                          strokeWidth: 1.4,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            title.text,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: SteelPalette.textLow.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (stats.isNotEmpty ||
              player.activeEffects.isNotEmpty ||
              player.inventory.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in stats.entries)
                  StatChip(stat: entry.key, value: entry.value, compact: true),
                for (final effect in player.activeEffects)
                  EffectChip(effect: effect),
                for (final item in player.inventory) ItemChip(item: item),
              ],
            ),
          ],
        ],
      ),
    );

    // The whole card wears the rarity, not just a badge in the corner: at
    // the end of the journey the question is who these people turned out
    // to be, and a legendary origin should be visible across the room.
    if (origin == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SteelPalette.steel.withValues(alpha: 0.16)),
        ),
        child: card,
      );
    }
    return RarityFrame(
      rarity: origin!.rarity,
      borderRadius: BorderRadius.circular(14),
      child: card,
    );
  }
}

/// A lighthearted, derived-only title: its text and the mark that goes
/// with it. Nothing new is tracked during the match — this is purely a read
/// of the final `GameState`.
typedef _PlayerTitle = ({String text, LineIconShape icon});

/// Priority order: a revealed epic/legendary origin is the rarest, most
/// narratively loaded thing that can happen to a player, so it always wins;
/// below that, simple superlatives across the final party state.
///
/// The mark is decoration, not part of the rarity system, so it is never
/// tinted by rarity — it stays the same muted steel as the text beside it.
_PlayerTitle _titleFor(Player player, List<Player> allPlayers, Origin? origin) {
  if (origin != null && origin.rarity == Rarity.legendary) {
    return (text: 'Живая легенда стола', icon: LineIconShape.starBurst);
  }
  if (origin != null && origin.rarity == Rarity.epic) {
    return (text: 'Хранитель тайны', icon: LineIconShape.lockedChest);
  }
  if (player.curses.isNotEmpty) {
    return (text: 'Магнит проклятий', icon: LineIconShape.mask);
  }

  final maxItems = allPlayers
      .map((p) => p.inventory.length)
      .reduce((a, b) => a > b ? a : b);
  if (maxItems > 0 && player.inventory.length == maxItems) {
    return (text: 'Коллекционер похода', icon: LineIconShape.backpack);
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
  if (maxStatSum > 0 && statSum == maxStatSum) {
    return (text: 'Сердце похода', icon: LineIconShape.heart);
  }

  return (text: 'Верный спутник', icon: LineIconShape.mug);
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

/// The counters as one ruled block rather than five floating cards.
///
/// Individually bordered tiles made five small numbers look like five
/// separate achievements; one grid with hairlines between cells says "this
/// is the ledger of one journey". The hairlines are the container's own
/// colour showing through a 1px gap between opaque cells — cheaper and
/// crisper than drawing dividers.
class _StatGrid extends StatelessWidget {
  final _JourneyStats stats;

  static const int _columns = 3;
  static const double _cellHeight = 102;

  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final tiles = <_StatTile>[
      _StatTile(
        icon: Icons.directions_walk,
        value: '${stats.steps}',
        label: 'шагов пройдено',
      ),
      _StatTile(
        icon: Icons.map_outlined,
        value: '${stats.biomesVisited}',
        label: 'биомов посещено',
      ),
      _StatTile(
        icon: Icons.auto_stories_outlined,
        value: '${stats.adventuresCompleted}',
        label: 'приключений завершено',
      ),
      _StatTile(
        icon: Icons.help_outline,
        value: '${stats.originsRevealed}',
        label: 'происхождений раскрыто',
      ),
      if (stats.legendaryEventsSeen > 0)
        _StatTile(
          icon: Icons.workspace_premium,
          value: '${stats.legendaryEventsSeen}',
          label: 'легендарных событий',
          gold: true,
        ),
    ];
    final rows = (tiles.length / _columns).ceil();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: SteelPalette.steel.withValues(alpha: 0.14),
        child: Column(
          children: [
            for (var row = 0; row < rows; row++)
              Row(
                children: [
                  for (var column = 0; column < _columns; column++)
                    Expanded(
                      child: Container(
                        height: _cellHeight,
                        margin: const EdgeInsets.all(0.5),
                        color: SteelPalette.background,
                        child: _cellAt(row * _columns + column, tiles),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// An index past the last tile is a real cell with nothing in it — the
  /// grid stays rectangular rather than ending in a ragged row.
  Widget _cellAt(int index, List<_StatTile> tiles) =>
      index < tiles.length ? tiles[index] : const SizedBox.shrink();
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool gold;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.gold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = gold ? _gold : SteelPalette.steel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: tint, size: 19),
          const SizedBox(height: 7),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 19,
              height: 1,
              fontWeight: FontWeight.w600,
              color: gold ? _gold : SteelPalette.textHigh,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9.5,
              height: 1.3,
              color: SteelPalette.textLow.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Leaving is not a ceremony, so this one fires on the tap rather than
/// through [TactilePressButton] — the table has already had its moment.
class _HomeButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _HomeButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: SteelPalette.steel.withValues(alpha: 0.5),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF22262B), Color(0xFF1A1D21)],
            ),
          ),
          child: Text(
            'НА ГЛАВНЫЙ ЭКРАН',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 16,
              height: 1,
              fontWeight: FontWeight.w600,
              letterSpacing: 3.2,
              color: SteelPalette.textHigh,
            ),
          ),
        ),
      ),
    );
  }
}
