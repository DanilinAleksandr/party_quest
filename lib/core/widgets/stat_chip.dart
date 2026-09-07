import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';
import '../theme/steel_palette.dart';

/// One player stat, rendered as a small pill — icon + Russian label + value.
/// Centralizes the icon/label mapping that used to live inline in
/// `player_status_panel.dart` so any future screen showing a stat (a
/// negotiation prompt, a stat-check choice) can reuse the same look.
class StatChip extends StatelessWidget {
  final StatType stat;
  final int value;

  /// Drops the stat's name, leaving icon + value. For the roster card, where
  /// four players' worth of spelled-out stats is most of what made the game
  /// screen heavy — the full names live one tap away in the player profile.
  final bool compact;

  /// The size every compact cell on a roster card settles at — stat chips
  /// and `_CountPill` alike.
  ///
  /// Without this they sized to their contents, and since the two widgets
  /// had different padding they came out visibly different heights sitting
  /// side by side in the same card. Worse, a card gained and lost cells as
  /// the match went on, so the row appeared to resize itself whenever a
  /// player picked up a stat. A fixed cell makes the card a grid that fills
  /// in, instead of a row that reflows.
  ///
  /// [cellMinWidth] is a floor rather than a fixed width so a three-digit
  /// value still fits; in the range the game actually produces every cell
  /// comes out identical.
  static const double cellHeight = 28;
  static const double cellMinWidth = 50;

  const StatChip({
    super.key,
    required this.stat,
    required this.value,
    this.compact = false,
  });

  static IconData iconFor(StatType stat) => switch (stat) {
    StatType.strength => Icons.fitness_center,
    StatType.luck => Icons.casino_outlined,
    StatType.charisma => Icons.emoji_emotions_outlined,
    StatType.endurance => Icons.shield_outlined,
    StatType.attentiveness => Icons.visibility_outlined,
    StatType.cunning => Icons.psychology_outlined,
  };

  static String labelFor(StatType stat) => switch (stat) {
    StatType.strength => 'Сила',
    StatType.luck => 'Удача',
    StatType.charisma => 'Харизма',
    StatType.endurance => 'Выносливость',
    StatType.attentiveness => 'Внимательность',
    StatType.cunning => 'Хитрость',
  };

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      // Only useful in compact mode, where the name is gone — harmless
      // otherwise, and cheaper than branching the whole widget.
      message: labelFor(stat),
      child: Container(
        height: compact ? cellHeight : null,
        // No `alignment:` here on purpose. Container turns that into an
        // Align, which expands to the largest size its constraints allow —
        // inside a Wrap that means every chip stretches to the full row.
        // The Row below does the centring instead.
        constraints: compact
            ? const BoxConstraints(minWidth: cellMinWidth)
            : null,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 0 : 6,
        ),
        decoration: BoxDecoration(
          color: SteelPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconFor(stat), size: 15, color: SteelPalette.steel),
            const SizedBox(width: 6),
            Text(
              compact ? '$value' : '${labelFor(stat)} $value',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: SteelPalette.textLow),
            ),
          ],
        ),
      ),
    );
  }
}
