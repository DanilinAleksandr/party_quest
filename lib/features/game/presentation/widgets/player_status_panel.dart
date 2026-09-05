import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/influence_source.dart';
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

    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: avatarColor.withValues(alpha: 0.25),
                child: Text(
                  player.name.isEmpty ? '?' : player.name[0].toUpperCase(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: avatarColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                player.name,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              OriginRevealFlash(origin: origin),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 12),
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
                const SizedBox(height: 10),
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
                    color: theme.colorScheme.onSurfaceVariant,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
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
