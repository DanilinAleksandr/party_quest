import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';
import '../theme/app_colors.dart';
import '../theme/biome_flavor.dart';
import '../theme/weather_flavor.dart';

/// Full-width header showing the party's current "chapter" — the biome was
/// tracked in `WorldState` from the very first biome wave but never actually
/// shown anywhere in the UI until now. Pure presentation: reads [biome] for
/// its name, [biomeAtmosphere] for a short sensory line (a pure function of
/// [Biome.id] and, now, [weather] — the same forest reads as a different
/// place in sun, rain, fog, or at night, purely through this one line), and
/// [AppColors] for the accent color/icon — never touches the engine.
///
/// [weather] is optional and, when given, appended after the biome name as
/// a small "• icon label" — deliberately secondary (muted color, smaller
/// icon) since biome is always the main fact and weather just describes its
/// current state, not a chapter of its own.
///
/// [season] is optional too and feeds only into the subtitle line (composed
/// together with [weather] by [biomeAtmosphere]) — deliberately no separate
/// icon/chip for it in the compact row: the season was already announced
/// once, as its own scene, when the party left the prologue (see
/// `SeasonRevealDialog`), so repeating it here as a badge would be a
/// redundant "setting" rather than atmosphere. The subtitle line is where it
/// keeps showing up, quietly, for the rest of the match.
class BiomeBanner extends StatelessWidget {
  final Biome biome;
  final Weather? weather;
  final Season? season;

  const BiomeBanner({
    super.key,
    required this.biome,
    this.weather,
    this.season,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.biomeColor(biome.id);
    final icon = AppColors.biomeIcon(biome.id);
    final atmosphere = biomeAtmosphere(biome.id, weather, season);
    final subtitle = atmosphere.isEmpty ? biome.description : atmosphere;

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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        biome.name,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (weather != null) ...[
                      Text(
                        '  •  ',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Icon(
                        weatherIcon(weather!),
                        size: 15,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        weatherLabel(weather!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  maxLines: 2,
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
