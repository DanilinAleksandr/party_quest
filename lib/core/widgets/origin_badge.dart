import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';
import 'rarity_frame.dart';

/// A player's origin, or the mystery state before it's revealed. [origin]
/// null means `Player.originId` hasn't been set yet — shown as a muted "?"
/// badge rather than blank space, so "still unknown" reads as a deliberate
/// narrative state rather than a missing value.
class OriginBadge extends StatelessWidget {
  final Origin? origin;

  const OriginBadge({super.key, required this.origin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final origin = this.origin;

    if (origin == null) {
      final muted = theme.colorScheme.onSurfaceVariant;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: muted.withValues(alpha: 0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline, size: 16, color: muted),
            const SizedBox(width: 6),
            Text(
              'Неизвестный',
              style: theme.textTheme.labelMedium?.copyWith(
                color: muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return RarityFrame(
      rarity: origin.rarity,
      borderRadius: BorderRadius.circular(20),
      backgroundAlpha: 0.16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        origin.name,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
