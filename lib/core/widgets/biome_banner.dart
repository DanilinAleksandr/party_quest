import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';
import '../theme/biome_flavor.dart';
import '../theme/weather_flavor.dart';
import 'line_icons.dart';
import 'scene_banner.dart';

/// Full-width header showing the party's current "chapter" — the biome was
/// tracked in `WorldState` from the very first biome wave but never actually
/// shown anywhere in the UI until now. Pure presentation: reads [biome] for
/// its name and [biomeAtmosphere] for a short sensory line (a pure function
/// of [Biome.id] and, now, [weather] — the same forest reads as a different
/// place in sun, rain, fog, or at night, purely through this one line) —
/// never touches the engine.
///
/// The scene itself lives in [SceneBanner], shared with `PrologueBanner`.
/// This widget's whole job is turning a [Biome] into that scene's inputs.
///
/// [weather] is optional and, when given, appended after the biome name as
/// a small "• icon label" — deliberately secondary since biome is always
/// the main fact and weather just describes its current state, not a
/// chapter of its own.
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
    final atmosphere = biomeAtmosphere(biome.id, weather, season);
    return SceneBanner(
      icon: biomeLineIcon(biome.id),
      title: biome.name,
      subtitle: atmosphere.isEmpty ? biome.description : atmosphere,
      trailingIcon: weather == null ? null : weatherIcon(weather!),
      trailingLabel: weather == null ? null : weatherLabel(weather!),
    );
  }
}
