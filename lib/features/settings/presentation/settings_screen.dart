import 'package:flutter/material.dart';

/// Minimal placeholder. Intentionally empty of options for the MVP — the
/// screen and route exist so future settings (sound, theme, house rules,
/// win condition) have a home without a routing change.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Настройки появятся в одном из следующих обновлений.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
