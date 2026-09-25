import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    });

    test('remembers what was set across a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final first = WalkSettingsNotifier();
      await _settle();
      first.setMode(WalkMode.manual);
      first.setDelay(min: 2, max: 7);
      await _settle();

      final second = WalkSettingsNotifier();
      await _settle();
      expect(
        second.state,
        const WalkSettings(mode: WalkMode.manual, minDelay: 2, maxDelay: 7),
      );
    });

    test('ignores a stored range it could not have written', () async {
      SharedPreferences.setMockInitialValues({
        'walk_mode': 'sideways',
        'walk_min_delay': 9,
        'walk_max_delay': 3,
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

    // The attribution stays where it was.
    expect(find.text('БЛАГОДАРНОСТИ'), findsOneWidget);
  });
}
