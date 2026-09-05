import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/core/widgets/app_dialog_shell.dart';

Future<void> _open(
  WidgetTester tester, {
  required Widget content,
  required List<Widget> actions,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showAppDialog<void>(
            context: context,
            icon: Icons.auto_stories_outlined,
            title: 'Приключение',
            content: content,
            actions: actions,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('showAppDialog sizing', () {
    testWidgets('an overlong dialog scrolls instead of clipping its buttons', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // The realistic worst case: a wordy adventure node plus a full menu of
      // choices. Reaching the end of this test at all is the assertion — a
      // RenderFlex overflow is a FlutterError, which fails the test.
      await _open(
        tester,
        content: const Text(
          'Тропа выводит вас к обрыву, за которым в тумане угадываются '
          'очертания старой каменной лестницы, уходящей вниз, к самой воде. '
          'Кто-то поднимался по ней совсем недавно — на ступенях осталась '
          'мокрая земля, и она ещё не успела высохнуть.',
        ),
        actions: [
          for (final label in [
            'Спуститься по лестнице',
            'Позвать и подождать ответа',
            'Обойти обрыв стороной',
            'Осмотреть следы внимательнее',
            'Уйти, не оглядываясь',
          ])
            FilledButton(onPressed: () {}, child: Text(label)),
        ],
      );

      // The last button exists in the tree; scrolling is what makes it
      // reachable, so assert it can actually be brought into view.
      final lastButton = find.text('Уйти, не оглядываясь');
      expect(lastButton, findsOneWidget);
      await tester.scrollUntilVisible(lastButton, 100);
      expect(tester.getRect(lastButton).bottom, lessThan(560));
    });

    testWidgets('an ordinary dialog is no taller than its content', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _open(
        tester,
        content: const Text('На дороге стоит телега без лошади.'),
        actions: [FilledButton(onPressed: () {}, child: const Text('Понятно'))],
      );

      // The scroll view must shrink-wrap, not swallow the whole screen —
      // otherwise every dialog would render as a full-height panel.
      final card = tester.getRect(find.byKey(appDialogContentKey));
      expect(card.height, lessThan(400));
      // Still centered vertically.
      expect((card.center.dy - 400).abs(), lessThan(1));
    });
  });
}
