import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/core/widgets/app_dialog_shell.dart';
import 'package:drinking_quest/features/game/presentation/widgets/chance_check_dialog.dart';

Future<void> _roll(WidgetTester tester, bool passed, List<String> log) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            await showChanceCheckDialog(context: context, passed: passed);
            log.add('resolved');
          },
          child: const Text('gamble'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('gamble'));
  // Past the dialog's own entrance, into the tumble.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('the roll', () {
    testWidgets('says nothing until the die has settled', (tester) async {
      final log = <String>[];
      await _roll(tester, true, log);

      expect(find.byKey(appDialogContentKey), findsOneWidget);
      expect(find.text('Повезло'), findsNothing);
      expect(find.text('Дальше'), findsNothing);
      expect(log, isEmpty);
    });

    testWidgets('lands on the result it was given, and waits there', (
      tester,
    ) async {
      final log = <String>[];
      await _roll(tester, true, log);
      await tester.pumpAndSettle();

      expect(find.text('Повезло'), findsOneWidget);
      expect(find.text('Дальше'), findsOneWidget);
      // The effects must not be applied behind a dialog still on screen.
      expect(log, isEmpty);

      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();

      expect(find.byKey(appDialogContentKey), findsNothing);
      expect(log, ['resolved']);
    });

    testWidgets('a failed check says so', (tester) async {
      final log = <String>[];
      await _roll(tester, false, log);
      await tester.pumpAndSettle();

      expect(find.text('Не повезло'), findsOneWidget);
      expect(find.text('Повезло'), findsNothing);
    });
  });
}
