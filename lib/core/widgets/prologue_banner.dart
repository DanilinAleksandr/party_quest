import 'package:flutter/material.dart';

/// Shown instead of `BiomeBanner` while `GameState.phase ==
/// JourneyPhase.prologue` — the party hasn't reached a real biome yet
/// (`WorldState.currentBiomeId` is just a placeholder until the first
/// `SetBiomeAction` fires), so showing the real banner would claim a
/// location the party isn't actually at. Same visual shape as
/// `BiomeBanner` for consistency, with its own fixed neutral "road" color
/// rather than any of the six biome colors.
class PrologueBanner extends StatelessWidget {
  const PrologueBanner({super.key});

  static const _color = Color(0xFFB08A3F);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _color.withValues(alpha: 0.32),
            theme.colorScheme.surfaceContainerHigh,
          ],
        ),
        border: Border.all(color: _color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.backpack_outlined, color: _color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🎒 Пролог', style: theme.textTheme.titleMedium),
                Text(
                  'Путь только начинается...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
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
