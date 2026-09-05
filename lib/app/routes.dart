import 'package:flutter/material.dart';

import '../features/game/application/game_controller.dart';
import '../features/game/presentation/game_screen.dart';
import '../features/game_setup/presentation/game_setup_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'bootstrap_screen.dart';

/// Route name constants. Centralised so navigation calls never contain a
/// raw string that could typo-diverge from what `onGenerateRoute` expects.
abstract final class AppRoutes {
  static const String mainMenu = '/';
  static const String gameSetup = '/setup';
  static const String game = '/game';
  static const String settings = '/settings';

  // Case values must be qualified (`AppRoutes.x`) — a bare identifier in a
  // Dart switch pattern binds a new variable instead of matching a constant.
  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    return switch (routeSettings.name) {
      AppRoutes.gameSetup => MaterialPageRoute(
        builder: (_) => const GameSetupScreen(),
        settings: routeSettings,
      ),
      AppRoutes.game => MaterialPageRoute(
        builder: (_) =>
            GameScreen(setupArgs: routeSettings.arguments as GameSetupArgs),
        settings: routeSettings,
      ),
      AppRoutes.settings => MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
        settings: routeSettings,
      ),
      _ => MaterialPageRoute(
        builder: (_) => const BootstrapScreen(),
        settings: const RouteSettings(name: AppRoutes.mainMenu),
      ),
    };
  }
}
