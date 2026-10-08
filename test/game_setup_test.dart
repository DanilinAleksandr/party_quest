import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/features/game_setup/presentation/game_setup_screen.dart';
import 'package:drinking_quest/features/game_setup/presentation/widgets/journey_length_picker.dart';
import 'package:drinking_quest/features/settings/application/walk_settings.dart';

/// The setup screen, with whatever it hands the game captured.
Future<GameSetupArgs? Function()> _pumpSetup(WidgetTester tester) async {
  Object? arguments;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        walkSettingsProvider.overrideWith(
          (ref) => WalkSettingsNotifier(initial: const WalkSettings()),
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
  await tester.pump();
  return () => arguments as GameSetupArgs?;
}

Future<void> _addPlayers(WidgetTester tester, List<String> names) async {
  for (final name in names) {
    await tester.enterText(find.byKey(const Key('player_name_field')), name);
    await tester.tap(find.byTooltip('Добавить игрока'));
    await tester.pump();
  }
}

Future<void> _start(WidgetTester tester) async {
  await tester.ensureVisible(find.text('НАЧАТЬ ИГРУ'));
  await tester.tap(find.text('НАЧАТЬ ИГРУ'));
  await tester.pumpAndSettle();
}

int? _picked(WidgetTester tester) =>
    tester.widget<JourneyLengthPicker>(find.byType(JourneyLengthPicker)).value;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the journey length', () {
    testWidgets('is without end unless the table picks one', (tester) async {
      final args = await _pumpSetup(tester);
      expect(_picked(tester), isNull);
      await _addPlayers(tester, ['Аня', 'Боря']);
      await _start(tester);
      expect(args()!.journeySteps, isNull);
    });

    testWidgets('a tap on ∞ is the endless journey, every time', (
      tester,
    ) async {
      await _pumpSetup(tester);
      final infinity = find.byKey(const Key('journey_infinity'));
      await tester.ensureVisible(infinity);
      final trail = tester.getRect(
        find.ancestor(of: infinity, matching: find.byType(GestureDetector)),
      );
      final glyph = tester.getRect(infinity);
      for (final dx in [0.05, 0.5, 0.95]) {
        // Somewhere on the trail first, so ∞ has something to replace.
        await tester.tapAt(trail.centerLeft + const Offset(20, 0));
        await tester.pump();
        expect(_picked(tester), isNotNull);
        await tester.tapAt(
          Offset(glyph.left + glyph.width * dx, glyph.center.dy),
        );
        await tester.pump();
        expect(_picked(tester), isNull, reason: 'at $dx of the glyph');
      }
    });

    testWidgets('a drag to the right edge is the endless journey too', (
      tester,
    ) async {
      await _pumpSetup(tester);
      final infinity = find.byKey(const Key('journey_infinity'));
      await tester.ensureVisible(infinity);
      final trail = tester.getRect(
        find.ancestor(of: infinity, matching: find.byType(GestureDetector)),
      );
      await tester.tapAt(trail.centerLeft + const Offset(20, 0));
      await tester.pump();
      expect(_picked(tester), isNotNull);
      await tester.dragFrom(
        trail.centerLeft + const Offset(20, 0),
        Offset(trail.width + 40, 0),
      );
      await tester.pump();
      expect(_picked(tester), isNull);

      // Just short of the glyph is the longest finite journey.
      await tester.tapAt(
        Offset(tester.getRect(infinity).left - 1, trail.center.dy),
      );
      await tester.pump();
      expect(_picked(tester), 200);
    });
  });

  group('the party', () {
    testWidgets('is the last one that set out, in its order', (tester) async {
      SharedPreferences.setMockInitialValues({
        'last_party': ['Вика', 'Аня', 'Боря'],
      });
      final args = await _pumpSetup(tester);
      await tester.pump();
      expect(find.text('В ОТРЯДЕ · 3'), findsOneWidget);

      // One tap takes somebody out.
      await tester.tap(find.byTooltip('Удалить игрока').first);
      await tester.pump();
      await _start(tester);
      expect(args()!.playerNames, ['Аня', 'Боря']);
    });

    testWidgets('is remembered for next time', (tester) async {
      await _pumpSetup(tester);
      await _addPlayers(tester, ['Гена', 'Даша']);
      await _start(tester);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('last_party'), ['Гена', 'Даша']);
    });

    testWidgets('starts empty with no last party', (tester) async {
      await _pumpSetup(tester);
      await tester.pump();
      expect(find.byTooltip('Удалить игрока'), findsNothing);
    });
  });
}
