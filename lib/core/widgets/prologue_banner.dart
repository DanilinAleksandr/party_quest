import 'package:flutter/material.dart';

import 'line_icons.dart';
import 'scene_banner.dart';

/// Shown instead of `BiomeBanner` while `GameState.phase ==
/// JourneyPhase.prologue` — the party hasn't reached a real biome yet
/// (`WorldState.currentBiomeId` is just a placeholder until the first
/// `SetBiomeAction` fires), so showing the real banner would claim a
/// location the party isn't actually at.
///
/// It gets the *same* [SceneBanner] as a biome, not a thinner cousin of
/// one: "you have not left yet" is a chapter like any other, and the first
/// minute of a match is exactly the wrong place to look like a different
/// screen. Only the mark changes — a house, because the road has not
/// started.
class PrologueBanner extends StatelessWidget {
  const PrologueBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SceneBanner(
      icon: LineIconShape.home,
      title: 'Пролог',
      subtitle: 'Путь только начинается…',
    );
  }
}
