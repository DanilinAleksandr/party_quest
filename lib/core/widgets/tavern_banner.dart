import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/biome_flavor.dart';

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
    final color = AppColors.biomeColor(_biomeId);
    final icon = AppColors.biomeIcon(_biomeId);
    final atmosphere = biomeAtmosphere(_biomeId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.32),
            theme.colorScheme.surfaceContainerHigh,
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Остановка: Таверна', style: theme.textTheme.titleMedium),
                if (atmosphere.isNotEmpty)
                  Text(
                    atmosphere,
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
