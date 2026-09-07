import 'package:flutter/material.dart';

/// Nearly empty for the MVP — the screen and route exist so future settings
/// (sound, house rules, win condition) have a home without a routing
/// change.
///
/// The one thing on it that is not a placeholder is the icon attribution.
/// The origin icons are CC BY 3.0, and naming the authors is a condition of
/// using them, not a courtesy — so it ships with the icons rather than
/// waiting for an "About" screen that does not exist yet.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'Настройки появятся в одном из следующих обновлений.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 16),
              Text(
                'БЛАГОДАРНОСТИ',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              // Selectable so the links can actually be copied — there is
              // no url_launcher in the project, and pulling in a dependency
              // to open two URLs would cost more than it gives.
              SelectableText(
                'Иконки происхождений — Lorc и Delapouite, game-icons.net,\n'
                'лицензия CC BY 3.0.\n'
                'https://game-icons.net\n'
                'https://creativecommons.org/licenses/by/3.0/',
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
