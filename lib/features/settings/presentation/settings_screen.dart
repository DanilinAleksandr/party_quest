import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/walk_settings.dart';

/// How the party walks, and the icon attribution.
///
/// The attribution is not a placeholder. The origin icons are CC BY 3.0,
/// and naming the authors is a condition of using them, not a courtesy — so
/// it ships with the icons rather than waiting for an "About" screen that
/// does not exist yet.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final walk = ref.watch(walkSettingsProvider);
    final notifier = ref.read(walkSettingsProvider.notifier);
    final auto = walk.mode == WalkMode.auto;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                key: const Key('walk_mode_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Идти самостоятельно'),
                subtitle: const Text(
                  'Карточки появляются сами, пока герои идут',
                ),
                value: auto,
                onChanged: (on) =>
                    notifier.setMode(on ? WalkMode.auto : WalkMode.manual),
              ),
              // Nothing to tune when the party only moves when pressed.
              if (auto) ...[
                const SizedBox(height: 12),
                Text(
                  'Карточка через, сек: от ${walk.minDelay} до ${walk.maxDelay}',
                  style: theme.textTheme.bodyMedium,
                ),
                RangeSlider(
                  key: const Key('walk_delay_slider'),
                  min: kMinWalkDelay.toDouble(),
                  max: kMaxWalkDelay.toDouble(),
                  divisions: kMaxWalkDelay - kMinWalkDelay,
                  values: RangeValues(
                    walk.minDelay.toDouble(),
                    walk.maxDelay.toDouble(),
                  ),
                  labels: RangeLabels('${walk.minDelay}', '${walk.maxDelay}'),
                  onChanged: (range) => notifier.setDelay(
                    min: range.start.round(),
                    max: range.end.round(),
                  ),
                ),
              ],
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
