import 'package:flutter/material.dart';

import '../theme/steel_palette.dart';
import 'line_icons.dart';

/// Shown instead of `BiomeBanner` while `GameState.phase ==
/// JourneyPhase.prologue` — the party hasn't reached a real biome yet
/// (`WorldState.currentBiomeId` is just a placeholder until the first
/// `SetBiomeAction` fires), so showing the real banner would claim a
/// location the party isn't actually at. Same visual shape as
/// `BiomeBanner` for consistency: same steel, one step quieter, because
/// the prologue is the stretch before the world has told you where you are.
class PrologueBanner extends StatelessWidget {
  const PrologueBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF181B20), Color(0xFF14161A)],
        ),
        border: Border.all(color: SteelPalette.steel.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          const LineIcon(
            shape: LineIconShape.waypoint,
            size: 24,
            color: SteelPalette.steel,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Пролог',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.95,
                    color: SteelPalette.textHigh,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Путь только начинается...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: SteelPalette.textLow.withValues(alpha: 0.72),
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
