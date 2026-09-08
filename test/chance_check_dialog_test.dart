import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:drinking_quest/core/widgets/app_dialog_shell.dart';
import 'package:drinking_quest/features/game/presentation/widgets/chance_check_dialog.dart';
import 'package:drinking_quest/features/game/presentation/widgets/choice_outcome_dialog.dart';
import 'package:drinking_quest/features/game/presentation/widgets/wager_call_dialog.dart';

Future<void> _roll(
  WidgetTester tester,
  bool passed,
  List<String> log, {
  List<String>? sides,
  int? calledIndex,
  String? challenger,
  String? opponent,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            await showChanceCheckDialog(
              context: context,
              passed: passed,
              sides: sides,
              calledIndex: calledIndex,
              challenger: challenger,
              opponent: opponent,
            );
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

const _coin = ['Король', 'Шут'];

void main() {
  group('the roll', () {
    testWidgets('says nothing until the coin has settled', (tester) async {
      final log = <String>[];
      await _roll(tester, true, log);

      expect(find.byKey(appDialogContentKey), findsOneWidget);
      expect(find.text('Обошлось'), findsNothing);
      expect(find.text('Дальше'), findsNothing);
      expect(log, isEmpty);
    });

    testWidgets('lands on the result it was given, and waits there', (
      tester,
    ) async {
      final log = <String>[];
      await _roll(tester, true, log);
      await tester.pumpAndSettle();

      expect(find.text('Обошлось'), findsOneWidget);
      expect(find.text('Дальше'), findsOneWidget);
      // The effects must not be applied behind a dialog still on screen.
      expect(log, isEmpty);

      await tester.tap(find.text('Дальше'));
      await tester.pumpAndSettle();

      expect(find.byKey(appDialogContentKey), findsNothing);
      expect(log, ['resolved']);
    });

    testWidgets('a failed check names the cost, not the miss', (tester) async {
      final log = <String>[];
      await _roll(tester, false, log);
      await tester.pumpAndSettle();

      expect(find.text('Платишь'), findsOneWidget);
      expect(find.text('Обошлось'), findsNothing);
    });
  });

  group('a called wager', () {
    testWidgets('a won call is the side that came up', (tester) async {
      await _roll(tester, true, [], sides: _coin, calledIndex: 0);
      await tester.pumpAndSettle();

      expect(find.text('Ставка: Король  ·  Выпало: Король'), findsOneWidget);
    });

    testWidgets('a lost call names the side that beat it', (tester) async {
      // The line can never contradict the verdict above it: losing means
      // the other side came up, by definition of having called one.
      await _roll(tester, false, [], sides: _coin, calledIndex: 0);
      await tester.pumpAndSettle();

      expect(find.text('Ставка: Король  ·  Выпало: Шут'), findsOneWidget);
    });

    testWidgets('an uncalled throw says nothing about sides', (tester) async {
      await _roll(tester, false, []);
      await tester.pumpAndSettle();

      expect(find.textContaining('Ставка'), findsNothing);
    });
  });

  group('the call', () {
    testWidgets('offers both sides and reports the one picked', (tester) async {
      int? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                picked = await showWagerCallDialog(
                  context: context,
                  sides: _coin,
                );
              },
              child: const Text('bet'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('bet'));
      await tester.pumpAndSettle();

      expect(find.text('Король'), findsOneWidget);
      expect(find.text('Шут'), findsOneWidget);

      await tester.tap(find.text('Шут'));
      await tester.pumpAndSettle();

      expect(picked, 1);
    });
  });

  group('the face the coin lands on', () {
    String faceOf(WidgetTester tester) {
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      return (svg.bytesLoader as SvgAssetLoader).assetName;
    }

    testWidgets('is the side that was called, when the call won', (
      tester,
    ) async {
      // Now that the faces have names, showing the Jester over a receipt
      // that reads "Ставка: Король — она и выпала" would be a plain
      // contradiction on screen.
      await _roll(tester, true, [], sides: _coin, calledIndex: 0);
      await tester.pumpAndSettle();

      expect(faceOf(tester), contains('coin_king'));
    });

    testWidgets('is the other side, when the call lost', (tester) async {
      await _roll(tester, false, [], sides: _coin, calledIndex: 0);
      await tester.pumpAndSettle();

      expect(faceOf(tester), contains('coin_jester'));
    });

    testWidgets('follows the call, not the outcome, either way', (
      tester,
    ) async {
      // Calling the Jester and winning has to show the Jester — the coin
      // reports the throw, not whether the player is pleased about it.
      await _roll(tester, true, [], sides: _coin, calledIndex: 1);
      await tester.pumpAndSettle();

      expect(faceOf(tester), contains('coin_jester'));
    });

    testWidgets('reads King for a solo risk that held', (tester) async {
      // No call means no side to be right about, so the coin falls back to
      // the plain reading of its faces: order held, or chance took it.
      await _roll(tester, true, []);
      await tester.pumpAndSettle();

      expect(faceOf(tester), contains('coin_king'));
    });

    testWidgets('reads Jester for a solo risk that did not', (tester) async {
      await _roll(tester, false, []);
      await tester.pumpAndSettle();

      expect(faceOf(tester), contains('coin_jester'));
    });
  });

  group('a duel', () {
    testWidgets('names both players and which way it went', (tester) async {
      // Second person is wrong here: the penalty may land on the companion,
      // and "не повезло" would leave the table guessing who is meant.
      await _roll(tester, true, [], challenger: 'Артём', opponent: 'София');
      await tester.pumpAndSettle();

      expect(find.text('Артём и София'), findsOneWidget);
      // Артём's throw came off, so София is the one who pays.
      expect(find.text('Платит: София'), findsOneWidget);
      expect(find.text('Платишь'), findsNothing);
    });

    testWidgets('names the challenger when the challenger lost', (
      tester,
    ) async {
      await _roll(tester, false, [], challenger: 'Артём', opponent: 'София');
      await tester.pumpAndSettle();

      expect(find.text('Платит: Артём'), findsOneWidget);
    });

    testWidgets('a solo risk still speaks to the one who took it', (
      tester,
    ) async {
      await _roll(tester, true, []);
      await tester.pumpAndSettle();

      expect(find.text('Обошлось'), findsOneWidget);
      expect(find.textContaining('Платит:'), findsNothing);
    });
  });

  group('the gamble outcome', () {
    testWidgets('keeps the card name and labels its text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => tellGambleOutcome(
                context,
                'Пьёт София.',
                cardTitle: 'Пари между спутниками',
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Пари между спутниками'), findsOneWidget);
      expect(find.text('В РЕЗУЛЬТАТЕ'), findsOneWidget);
      expect(find.text('Пьёт София.'), findsOneWidget);
      // The generic heading belongs to the ordinary, non-random choices.
      expect(find.text('Последствие'), findsNothing);
    });

    testWidgets('is skipped entirely when the gamble has no words', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  tellGambleOutcome(context, null, cardTitle: 'Ва-банк'),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byKey(appDialogContentKey), findsNothing);
    });
  });
}
