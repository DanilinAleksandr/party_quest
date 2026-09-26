import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/settings/application/walk_settings.dart';

void main() {
  // Before anything touches a platform channel: the settings read below goes
  // through one, and without the binding it throws — quietly, since a
  // failed read falls back to the defaults.
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  // Start reading the stored settings now, at launch. Providers are lazy,
  // and nothing on the way to a new match watches this one: left alone, it
  // would first be created by the tap that starts the match — and hand that
  // match the defaults, since the stored values arrive a moment later.
  container.read(walkSettingsProvider);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AlkoQuestApp(),
    ),
  );
}
