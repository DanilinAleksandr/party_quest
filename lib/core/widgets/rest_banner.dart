import 'package:flutter/material.dart';

import '../theme/steel_palette.dart';
import 'line_icons.dart';

/// Shown alongside `BiomeBanner` while `WorldState.flag('in_rest')` is set —
/// the halt's twin of `TavernBanner`, stacked under the real biome for the
/// same reason: the party sat down *in* the forest, it did not leave it.
///
/// Takes the walking party's place while it lasts. Nobody is walking at a
/// halt, and a figure frozen mid-stride beside a campfire would say the
/// opposite of the card on top of it.
class RestBanner extends StatelessWidget {
  const RestBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: SteelPalette.surface,
        border: Border.all(color: SteelPalette.steel.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          const LineIcon(
            shape: LineIconShape.campfire,
            size: 20,
            color: SteelPalette.steel,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Остановка: Привал',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: SteelPalette.textHigh,
                  ),
                ),
                Text(
                  'Костёр горит, дорога подождёт до утра',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
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
