import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/influence_source.dart';
import '../../../../core/theme/steel_palette.dart';
import '../../../../core/widgets/origin_reveal_flash.dart';
import '../../../../core/widgets/rarity_frame.dart';
import '../../../../core/widgets/stat_chip.dart';
import '../../../../game_engine/models/models.dart';

/// One player's card in the roster — deliberately a *summary*, not a sheet.
///
/// During a match the table needs only two things from it: whose card this
/// is, and whether anything unusual is going on with them. So items and
/// effects are reduced to counted icons, stats lose their spelled-out names,
/// and no description appears anywhere. The full picture — descriptions,
/// remaining turns, what an ally does — lives in `showPlayerProfileSheet`,
/// one tap away via [onTap].
///
/// The one thing kept at full size is the origin: it's a single short pill,
/// it *is* the character's identity, and its reveal is the game's biggest
/// per-player moment (see [OriginRevealFlash]) — compacting it into a
/// nameless icon would throw that away to save nothing.
class PlayerStatusPanel extends StatelessWidget {
  final Player player;

  /// The player's revealed [Origin], or null if `Player.originId` hasn't
  /// been revealed yet — passed in rather than looked up here so this
  /// widget stays a pure function of its arguments, same as before.
  final Origin? origin;

  /// Opens this player's profile. Optional so the widget stays usable in
  /// contexts with nothing to open (tests, the win screen).
  final VoidCallback? onTap;

  const PlayerStatusPanel({
    super.key,
    required this.player,
    this.origin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = {
      for (final stat in StatType.values) stat: player.stats.valueOf(stat),
    }..removeWhere((_, value) => value == 0);
    final avatarColor = AppColors.playerAvatarColor(player.id);
    final blessings = player.blessings.length;
    final curses = player.curses.length;

    final card = Material(
      color: SteelPalette.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        // Quiet, but present. A card whose origin is still unrevealed gets
        // no [RarityFrame] around it, and at a fainter alpha than this it
        // stopped reading as a separate object and dissolved into the
        // screen behind it.
        side: BorderSide(color: SteelPalette.steel.withValues(alpha: 0.22)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  // A cut stone rather than a social-app circle, lit from
                  // the same upper left as everything else.
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      SteelPalette.steel.withValues(alpha: 0.14),
                      Colors.black.withValues(alpha: 0.25),
                    ],
                  ),
                ),
                child: Text(
                  player.name.isEmpty ? '?' : player.name[0].toUpperCase(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    // The per-player colour survives the repaint: it is how
                    // the table tells four cards apart at a glance, and it
                    // is the one hue on the card that is not saying
                    // something about rarity.
                    color: avatarColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                player.name,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: SteelPalette.textHigh,
                ),
              ),
              const SizedBox(height: 8),
              OriginRevealFlash(origin: origin),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: stats.entries
                      .map(
                        (entry) => StatChip(
                          stat: entry.key,
                          value: entry.value,
                          compact: true,
                        ),
                      )
                      .toList(),
                ),
              ],
              if (player.inventory.isNotEmpty ||
                  blessings > 0 ||
                  curses > 0) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    if (player.inventory.isNotEmpty)
                      _CountPill(
                        icon: InfluenceSource.item.icon,
                        color: InfluenceSource.item.color,
                        count: player.inventory.length,
                        tooltip: 'Предметы',
                      ),
                    // Blessings and curses are the same list split by
                    // polarity (`Player.blessings`/`curses`), and they keep
                    // the green/red vocabulary `EffectChip` established, so
                    // the color alone says which is which.
                    if (blessings > 0)
                      _CountPill(
                        icon: Icons.auto_awesome,
                        color: AppColors.positiveEffectColor,
                        count: blessings,
                        tooltip: 'Благословения',
                      ),
                    if (curses > 0)
                      _CountPill(
                        icon: Icons.dangerous_outlined,
                        color: AppColors.negativeEffectColor,
                        count: curses,
                        tooltip: 'Проклятия',
                      ),
                  ],
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Подробнее ›',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: SteelPalette.textLow.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // A visible payoff for the moment an origin reveals: the whole card
    // picks up a rarity-tinted frame instead of the reveal only changing a
    // text label.
    if (origin == null) return card;
    return RarityFrame(
      rarity: origin!.rarity,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }
}

/// "There are three of these" — an icon and a number, no name. The whole
/// point of the compact card: enough to notice, not enough to read.
class _CountPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final String tooltip;

  const _CountPill({
    required this.icon,
    required this.color,
    required this.count,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        // Same cell as [StatChip]: these two sit next to each other in the
        // same card, and sizing each to its own contents made one look
        // shrunken beside the other.
        height: StatChip.cellHeight,
        constraints: const BoxConstraints(minWidth: StatChip.cellMinWidth),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
