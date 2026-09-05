import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:drinking_quest/app/app.dart';
import 'package:drinking_quest/core/widgets/app_dialog_shell.dart';
import 'package:drinking_quest/core/widgets/game_result_card.dart';
import 'package:drinking_quest/game_engine/data/content_providers.dart';

/// Loads every content pack *before* the app is pumped, and hands the warmed
/// container to the widget tree.
///
/// This test is about navigation, not about loading. The previous version
/// polled the bootstrap spinner with bounded `pump`s; `pump` only advances the
/// test's fake clock and never waits on a real future, so that worked by luck
/// and the luck ran out once the game passed ~40 content packs.
///
/// Reading the assets needs `runAsync` — and `runAsync` also un-blocks
/// `google_fonts`, which then tries to fetch a font over the network and
/// throws in a sandboxed run. `allowRuntimeFetching = false` is the package's
/// own switch for exactly this, and must be set before the app builds a theme.
Future<ProviderContainer> _warmedContainer(WidgetTester tester) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final container = ProviderContainer();
  await tester.runAsync(() async {
    await container.read(cardsProvider.future);
    await container.read(itemCatalogProvider.future);
    await container.read(effectCatalogProvider.future);
    await container.read(adventureCatalogProvider.future);
    await container.read(biomeCatalogProvider.future);
    await container.read(originCatalogProvider.future);
    await container.read(contentValidationProvider.future);
  });
  return container;
}

void main() {
  testWidgets('Main menu navigates to game setup', (WidgetTester tester) async {
    final container = await _warmedContainer(tester);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AlkoQuestApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Алко-Квест'), findsOneWidget);
    expect(find.text('Новая игра'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);

    await tester.tap(find.text('Новая игра'));
    await tester.pumpAndSettle();

    expect(find.text('Начать игру'), findsOneWidget);

    // Add two players and start the match.
    for (final name in ['Аня', 'Боря']) {
      await tester.enterText(find.byKey(const Key('player_name_field')), name);
      await tester.tap(find.byTooltip('Добавить игрока'));
      await tester.pump();
    }
    expect(find.text('Аня'), findsOneWidget);
    expect(find.text('Боря'), findsOneWidget);

    await tester.tap(find.text('Начать игру'));
    await tester.pumpAndSettle();

    // Game screen: the whole party travels together, so both players show
    // up in the roster from the start, not one at a time.
    expect(find.text('Аня'), findsOneWidget);
    expect(find.text('Боря'), findsOneWidget);
    expect(find.text('Шаг 0 / 20'), findsOneWidget);

    // Take a step: a card should be drawn and presented as a dialog (or,
    // rarely for a card whose event needs the table to pick a player, a
    // participant-selection dialog first — resolve that too if it shows).
    await tester.tap(find.text('Сделать шаг'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(appDialogContentKey), findsOneWidget);

    // Resolve whichever dialog appeared by tapping its first action button
    // — if that was a participant pick, resolve the card dialog it opens
    // next the same way.
    for (
      var i = 0;
      i < 2 && find.byKey(appDialogContentKey).evaluate().isNotEmpty;
      i++
    ) {
      final dialogButton = find
          .descendant(
            of: find.byKey(appDialogContentKey),
            matching: find.byWidgetPredicate(
              (widget) => widget is FilledButton || widget is OutlinedButton,
            ),
          )
          .first;
      await tester.tap(dialogButton);
      await tester.pumpAndSettle();
    }

    // Any real change (item/effect/stat/origin/leader) now shows as its own
    // "карточка результата" — dismiss however many appear, one at a time,
    // before checking the underlying game state.
    while (find.byKey(gameResultCardKey).evaluate().isNotEmpty) {
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();
    }

    // The card is resolved; the party's shared step count advanced by one.
    expect(find.byKey(appDialogContentKey), findsNothing);
    expect(find.byKey(gameResultCardKey), findsNothing);
    expect(find.text('Аня'), findsOneWidget);
    expect(find.text('Боря'), findsOneWidget);
    expect(find.text('Шаг 1 / 20'), findsOneWidget);
  });
}
