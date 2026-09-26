import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/features/game_setup/presentation/game_setup_screen.dart';
import 'package:drinking_quest/features/settings/application/walk_settings.dart';
import 'package:drinking_quest/features/settings/presentation/settings_screen.dart';

/// Lets the notifier's first read land.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalkSettingsNotifier', () {
    test('walks on its own out of the box, every 4 to 10 seconds', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = WalkSettingsNotifier();
      await _settle();
      expect(notifier.state, const WalkSettings());
      expect(notifier.state.mode, WalkMode.auto);
      expect(notifier.state.minDelay, 4);
      expect(notifier.state.maxDelay, 10);
      expect(notifier.state.restInterval, 10);
    });

    test('remembers what was set across a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final first = WalkSettingsNotifier();
      await _settle();
      first.setMode(WalkMode.manual);
      first.setDelay(min: 2, max: 7);
      first.setRestInterval(15);
      await _settle();

      final second = WalkSettingsNotifier();
      await _settle();
      expect(
        second.state,
        const WalkSettings(
          mode: WalkMode.manual,
          minDelay: 2,
          maxDelay: 7,
          restInterval: 15,
        ),
      );
    });

    test('ignores a stored range it could not have written', () async {
      SharedPreferences.setMockInitialValues({
        'walk_mode': 'sideways',
        'walk_min_delay': 9,
        'walk_max_delay': 3,
        'rest_interval': 40,
      });
      final notifier = WalkSettingsNotifier();
      await _settle();
      expect(notifier.state, const WalkSettings());
    });
  });

  testWidgets('the delay is only offered while walking on its own', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walkSettingsProvider.overrideWith(
            (ref) => WalkSettingsNotifier(initial: const WalkSettings()),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.text('Идти самостоятельно'), findsOneWidget);
    expect(find.byKey(const Key('walk_delay_slider')), findsOneWidget);
    expect(find.text('Карточка через, сек: от 4 до 10'), findsOneWidget);

    await tester.tap(find.byKey(const Key('walk_mode_switch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('walk_delay_slider')), findsNothing);

    // The halt applies whoever is walking, so it stays.
    expect(find.byKey(const Key('rest_interval_slider')), findsOneWidget);
    expect(find.text('Привал — каждые 10 карточек'), findsOneWidget);

    // The attribution stays where it was.
    expect(find.text('БЛАГОДАРНОСТИ'), findsOneWidget);
  });

  testWidgets('a new match takes the halt interval from the settings', (
    tester,
  ) async {
    Object? arguments;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walkSettingsProvider.overrideWith(
            (ref) => WalkSettingsNotifier(
              initial: const WalkSettings(restInterval: 6),
            ),
          ),
        ],
        child: MaterialApp(
          home: const GameSetupScreen(),
          onGenerateRoute: (settings) {
            arguments = settings.arguments;
            return MaterialPageRoute(builder: (_) => const SizedBox());
          },
        ),
      ),
    );

    for (final name in ['Аня', 'Боря']) {
      await tester.enterText(find.byKey(const Key('player_name_field')), name);
      await tester.tap(find.byTooltip('Добавить игрока'));
      await tester.pump();
    }
    await tester.ensureVisible(find.text('НАЧАТЬ ИГРУ'));
    await tester.tap(find.text('НАЧАТЬ ИГРУ'));
    await tester.pumpAndSettle();

    expect((arguments! as GameSetupArgs).restInterval, 6);
  });

  testWidgets('the stored interval reaches a match, not the default', (
    tester,
  ) async {
    // No override: the real notifier, reading the real (mocked) store. A lazy
    // provider first created by the start tap would hand the match 10.
    SharedPreferences.setMockInitialValues({'rest_interval': 7});
    Object? arguments;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: const GameSetupScreen(),
          onGenerateRoute: (settings) {
            arguments = settings.arguments;
            return MaterialPageRoute(builder: (_) => const SizedBox());
          },
        ),
      ),
    );
    await tester.pump();

    for (final name in ['Аня', 'Боря']) {
      await tester.enterText(find.byKey(const Key('player_name_field')), name);
      await tester.tap(find.byTooltip('Добавить игрока'));
      await tester.pump();
    }
    await tester.ensureVisible(find.text('НАЧАТЬ ИГРУ'));
    await tester.tap(find.text('НАЧАТЬ ИГРУ'));
    await tester.pumpAndSettle();

    expect((arguments! as GameSetupArgs).restInterval, 7);
  });
}
