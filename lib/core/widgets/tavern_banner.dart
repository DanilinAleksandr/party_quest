import 'package:flutter/material.dart';

import '../theme/biome_flavor.dart';
import '../theme/steel_palette.dart';
import 'line_icons.dart';

/// Shown alongside `BiomeBanner` while `WorldState.flag('in_tavern')` is
/// set — the tavern is a detour *inside* whatever real biome the party is
/// already traveling through, not a rotation biome of its own, so this
/// stacks under the real banner rather than replacing it (mirrors how
/// `PrologueBanner` replaces it, but deliberately doesn't here — the real
/// biome never stopped being true). No `Biome`/`BiomeCatalog` dependency,
/// same reasoning `PrologueBanner` already documents: hardcoded copy,
/// reusing `AppColors`'s existing `'tavern'` entries purely for visual
/// consistency with the biome color/icon palette.
class TavernBanner extends StatelessWidget {
  const TavernBanner({super.key});

  static const _biomeId = 'tavern';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atmosphere = biomeAtmosphere(_biomeId);

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
            shape: LineIconShape.mug,
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
                  'Остановка: Таверна',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: SteelPalette.textHigh,
                  ),
                ),
                if (atmosphere.isNotEmpty)
                  Text(
                    atmosphere,
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
