import 'package:flutter/material.dart';

import '../../../../core/theme/season_flavor.dart';
import '../../../../core/widgets/app_dialog_shell.dart';
import '../../../../game_engine/models/models.dart';

/// Shown exactly once per match, the instant the party leaves the prologue
/// — the only place `Season` is ever announced directly (everywhere else it
/// only shows up quietly, woven into `biomeAtmosphere`'s subtitle line).
/// `WorldState.currentSeason` is rolled once at game start and never
/// changes, so there's no risk of this firing again later — the phase
/// transition it's tied to (`JourneyPhase.prologue` → `.journey`) only ever
/// happens once.
Future<void> showSeasonRevealDialog(BuildContext context, Season season) {
  return showAppDialog<void>(
    context: context,
    icon: seasonIcon(season),
    title: seasonLabel(season),
    accentColor: seasonColor(season),
    barrierDismissible: false,
    content: Text(
      seasonRevealNarration(season),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge,
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Продолжить'),
      ),
    ],
  );
}
