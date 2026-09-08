import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/core/widgets/app_dialog_shell.dart';
import 'package:drinking_quest/features/game/presentation/widgets/choice_outcome_dialog.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

/// Drives [tellChoiceOutcome] the way `game_screen` does — from a callback,
/// awaiting it before doing the next thing — and records when that await
/// finished, since "the effects wait for the player" is the whole point of
/// the step.
Future<void> _tell(
  WidgetTester tester,
  String? outcome,
  List<String> log,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            await tellChoiceOutcome(context, outcome);
            log.add('resolved');
          },
          child: const Text('choose'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('choose'));
  await tester.pumpAndSettle();
}

void main() {
  // The content check reads real asset files. `testWidgets` would run it
  // under a fake clock, where a genuinely asynchronous bundle read never
  // completes — the same reason the other content tests are plain `test`s.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CardChoice.outcome', () {
    test('round-trips through JSON and stays absent when unset', () {
      const withOutcome = CardChoice(
        label: 'Присмотреться получше',
        outcome: 'Обычная медная монета, ничего примечательного.',
      );
      expect(
        CardChoice.fromJson(withOutcome.toJson()).outcome,
        withOutcome.outcome,
      );

      // Absent rather than null: every existing choice in the content omits
      // the key, and a round-trip must not start writing it back in.
      const bare = CardChoice(label: 'Пройти мимо');
      expect(bare.toJson().containsKey('outcome'), isFalse);
      expect(CardChoice.fromJson(bare.toJson()).outcome, isNull);
    });

    test('reads the key from raw content JSON', () {
      final choice = CardChoice.fromJson(const {
        'label': 'Поднять',
        'outcome': 'Монета ложится в ладонь тёплой.',
      });
      expect(choice.outcome, 'Монета ложится в ладонь тёплой.');
    });
  });

  group('AdventureChoice.outcome', () {
    test('round-trips through JSON and stays absent when unset', () {
      const transition = NodeTransition(to: EndAdventure());
      const withOutcome = AdventureChoice(
        label: 'Спуститься',
        outcome: 'Ступени держат.',
        onSuccess: transition,
      );
      expect(
        AdventureChoice.fromJson(withOutcome.toJson()).outcome,
        'Ступени держат.',
      );

      const bare = AdventureChoice(label: 'Уйти', onSuccess: transition);
      expect(bare.toJson().containsKey('outcome'), isFalse);
      expect(AdventureChoice.fromJson(bare.toJson()).outcome, isNull);
    });
  });

  group('the outcome step', () {
    testWidgets('shows the text and holds the turn until it is acknowledged', (
      tester,
    ) async {
      final log = <String>[];
      await _tell(
        tester,
        'Обычная медная монета, ничего примечательного.',
        log,
      );

      expect(find.byKey(appDialogContentKey), findsOneWidget);
      expect(
        find.text('Обычная медная монета, ничего примечательного.'),
        findsOneWidget,
      );
      // Still open, so the card has not been resolved behind it.
      expect(log, isEmpty);

      await tester.tap(find.text('Понятно'));
      await tester.pumpAndSettle();

      expect(find.byKey(appDialogContentKey), findsNothing);
      expect(log, ['resolved']);
    });

    testWidgets('adds no step at all for a choice without one', (tester) async {
      final log = <String>[];
      await _tell(tester, null, log);

      expect(find.byKey(appDialogContentKey), findsNothing);
      expect(log, ['resolved']);
    });
  });

  group('content', () {
    // The field is only worth having if the JSON actually reaches the model,
    // and a typo in a key the parser ignores is silent by construction.
    test('at least one shipped choice carries an outcome', () async {
      final cards = await const CardRepository().loadCards();
      final withOutcome = [
        for (final card in cards)
          for (final choice in card.choices)
            if (choice.outcome != null) choice,
      ];
      expect(withOutcome, isNotEmpty);
      expect(withOutcome.every((c) => c.outcome!.trim().isNotEmpty), isTrue);
    });
  });
}
