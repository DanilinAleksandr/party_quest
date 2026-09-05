import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      // Only useful in compact mode, where the name is gone — harmless
      // otherwise, and cheaper than branching the whole widget.
      message: labelFor(stat),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconFor(stat), size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              compact ? '$value' : '${labelFor(stat)} $value',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
