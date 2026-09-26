import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/core/widgets/game_result_card.dart';
import 'package:drinking_quest/core/widgets/walking_party.dart';
import 'package:drinking_quest/features/game/application/auto_walk_timer.dart';
import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/features/game/presentation/game_screen.dart';
import 'package:drinking_quest/features/settings/application/walk_settings.dart';
import 'package:drinking_quest/game_engine/data/content_providers.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

GameCard _card(
  String id, {
  List<CardTag> tags = const [],
  List<GameCondition> conditions = const [],
  List<GameAction> actions = const [],
}) => GameCard(
  id: id,
  title: 'Карточка $id',
  description: 'd',
  type: CardType.event,
  rarity: Rarity.common,
  weight: 1,
  tags: tags,
  conditions: conditions,
  actions: actions,
);

/// The road, a way into a halt, and a way out — enough to walk a match to
/// its first halt and no further.
final _cards = [
  _card('road'),
  _card(
    'rest_arrival',
    actions: const [SetWorldFlagAction(flag: 'in_rest', value: true)],
  ),
  _card(
    'rest_departure',
    tags: const [CardTag.rest],
    conditions: const [WorldFlagSetCondition(flag: 'in_rest')],
    actions: const [SetWorldFlagAction(flag: 'in_rest', value: false)],
  ),
];

const GameSetupArgs _args = (playerNames: ['A', 'B'], journeySteps: 200);

GameController _controller({List<GameCard>? cards, bool skipPrologue = true}) =>
    GameController(
      playerNames: _args.playerNames,
      cards: cards ?? _cards,
      itemCatalog: const ItemCatalog({}),
      effectCatalog: const EffectCatalog({}),
      adventureCatalog: const AdventureCatalog({}),
      biomeCatalog: const BiomeCatalog({}),
      originCatalog: const OriginCatalog({}),
      seed: 3,
      journeySteps: 200,
      skipPrologue: skipPrologue,
    );

/// Pumps the game screen over [controller], with the walking settings
/// pinned. The biome catalog holds just the one biome the party is in, so
/// the banners have something to stack under; the origin catalog is left
/// loading for good, which the screen copes with.
Future<void> _pumpGame(
  WidgetTester tester,
  GameController controller,
  WalkSettings walk,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameControllerProvider.overrideWith((ref, args) => controller),
        walkSettingsProvider.overrideWith(
          (ref) => WalkSettingsNotifier(initial: walk),
        ),
        biomeCatalogProvider.overrideWith((ref) async {
          final id = controller.state.worldState.currentBiomeId;
          return BiomeCatalog({
            id: Biome(id: id, name: 'Лес', description: ''),
          });
        }),
        originCatalogProvider.overrideWith(
          (ref) => Completer<OriginCatalog>().future,
        ),
      ],
      child: const MaterialApp(home: GameScreen(setupArgs: _args)),
    ),
  );
  await tester.pump();
}

const _start = 'НАЧАТЬ';
const _onward = 'ПРОДОЛЖИТЬ ПОХОД';
const _next = 'ДАЛЬШЕ';

/// Closes the card dialog that is up. Settles by the clock rather than with
/// `pumpAndSettle`, which the walkers — a looping animation — never allow.
Future<void> _dismissCard(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.text('Понятно'));
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  group('AutoWalkTimer', () {
    testWidgets('steps once, somewhere inside the delay range', (tester) async {
      for (var seed = 0; seed < 20; seed++) {
        var steps = 0;
        final timer = AutoWalkTimer(
          onStep: () => steps++,
          random: Random(seed),
        );
        timer.update(canWalk: true, minDelaySeconds: 4, maxDelaySeconds: 10);

        final delay = timer.scheduledDelay!;
        expect(delay, greaterThanOrEqualTo(const Duration(seconds: 4)));
        expect(delay, lessThanOrEqualTo(const Duration(seconds: 10)));

        // Nothing before the minimum, however often it is re-told.
        await tester.pump(const Duration(milliseconds: 3900));
        timer.update(canWalk: true, minDelaySeconds: 4, maxDelaySeconds: 10);
        expect(steps, 0, reason: 'seed $seed');
        expect(timer.scheduledDelay, delay, reason: 'not restarted');

        await tester.pump(delay - const Duration(milliseconds: 3900));
        expect(steps, 1, reason: 'seed $seed');
        expect(timer.isScheduled, isFalse);
        timer.dispose();
      }
    });

    testWidgets('is dropped the moment the party cannot walk', (tester) async {
      var steps = 0;
      final timer = AutoWalkTimer(onStep: () => steps++, random: Random(1));
      timer.update(canWalk: true, minDelaySeconds: 1, maxDelaySeconds: 2);
      await tester.pump(const Duration(milliseconds: 500));

      timer.update(canWalk: false, minDelaySeconds: 1, maxDelaySeconds: 2);
      expect(timer.isScheduled, isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(steps, 0);

      // And comes back as a fresh countdown, not the rest of the old one.
      timer.update(canWalk: true, minDelaySeconds: 1, maxDelaySeconds: 2);
      await tester.pump(const Duration(milliseconds: 900));
      expect(steps, 0);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(steps, 1);
      timer.dispose();
    });
  });

  group('the game screen', () {
    testWidgets('by hand: the button is always there, saying what it does', (
      tester,
    ) async {
      final controller = _controller();
      await _pumpGame(
        tester,
        controller,
        const WalkSettings(mode: WalkMode.manual),
      );

      expect(find.text(_start), findsOneWidget);
      // No timer is walking the party behind the button's back.
      await tester.pump(const Duration(seconds: 30));
      expect(controller.state.pendingCard, isNull);

      await tester.tap(find.text(_start));
      await tester.pump();
      expect(controller.state.pendingCard, isNotNull);
      await _dismissCard(tester);
      expect(find.text(_onward), findsOneWidget);

      // Up to the halt, where nobody "continues the journey".
      while (!controller.state.worldState.flag('in_rest')) {
        await tester.tap(find.text(_onward));
        await tester.pump();
        await _dismissCard(tester);
      }
      expect(find.text(_next), findsOneWidget);
      expect(find.text(_onward), findsNothing);
    });

    testWidgets('on its own: one press to begin, and never another', (
      tester,
    ) async {
      final controller = _controller();
      await _pumpGame(
        tester,
        controller,
        const WalkSettings(mode: WalkMode.auto, minDelay: 2, maxDelay: 3),
      );

      // Nothing moves until the table says so.
      expect(find.text(_start), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(controller.state.pendingCard, isNull);

      await tester.tap(find.text(_start));
      await tester.pump();
      expect(controller.state.pendingCard, isNotNull);
      await _dismissCard(tester);
      expect(find.text(_start), findsNothing);
      expect(find.text(_onward), findsNothing);

      // The countdown started as the card closed, early in `_dismissCard`'s
      // 1.2 s; 2 to 3 s from then.
      await tester.pump(const Duration(milliseconds: 700));
      expect(controller.state.pendingCard, isNull);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(controller.state.pendingCard, isNotNull);

      // The card is on screen now, and the countdown is gone with it: a
      // minute later there is still only the one card.
      final card = controller.state.pendingCard;
      await tester.pump(const Duration(minutes: 1));
      expect(controller.state.pendingCard, same(card));
      expect(controller.state.partySteps, 2);
    });

    testWidgets('at a halt the cards keep coming on their own, no button', (
      tester,
    ) async {
      final controller = _controller();
      // Walk to the tenth step by hand, where the halt falls due.
      for (var i = 0; i < kRestInterval; i++) {
        controller.takeStep();
        controller.resolveCard();
      }
      expect(controller.state.worldState.flag('in_rest'), isTrue);

      await _pumpGame(
        tester,
        controller,
        const WalkSettings(mode: WalkMode.auto, minDelay: 1, maxDelay: 1),
      );

      expect(find.text('Остановка: Привал'), findsOneWidget);
      expect(find.byType(PartyCamp), findsOneWidget);
      expect(find.byType(WalkingParty), findsNothing);
      for (final label in [_start, _onward, _next]) {
        expect(find.text(label), findsNothing);
      }

      await tester.pump(const Duration(milliseconds: 1100));
      expect(controller.state.pendingCard?.id, 'rest_departure');
    });

    testWidgets('in the prologue the party walks on its own too', (
      tester,
    ) async {
      final controller = _controller(
        cards: [
          ..._cards,
          _card('prologue_road', tags: const [CardTag.prologue]),
        ],
        skipPrologue: false,
      );
      await _pumpGame(
        tester,
        controller,
        const WalkSettings(mode: WalkMode.auto, minDelay: 1, maxDelay: 1),
      );

      await tester.tap(find.text(_start));
      await tester.pump();
      await _dismissCard(tester);
      expect(controller.state.phase, JourneyPhase.prologue);
      expect(find.byType(WalkingParty), findsOneWidget);
      expect(find.text(_onward), findsNothing);

      await tester.pump(const Duration(milliseconds: 1100));
      expect(controller.state.pendingCard?.id, 'prologue_road');
      expect(controller.state.partySteps, 2);
    });

    testWidgets('the countdown waits out the result cards, not just the card', (
      tester,
    ) async {
      // A card that changes something, so resolving it leaves a result card
      // on screen after `pendingCard` has already gone back to null. One
      // step is taken before the screen is built, so the match has begun.
      final controller = _controller(
        cards: [
          _card(
            'gift',
            actions: const [ModifyStatAction(stat: StatType.luck, amount: 1)],
          ),
        ],
      );
      controller.takeStep();
      controller.resolveCard();
      await _pumpGame(
        tester,
        controller,
        const WalkSettings(mode: WalkMode.auto, minDelay: 1, maxDelay: 1),
      );

      await tester.pump(const Duration(milliseconds: 1100));
      expect(controller.state.pendingCard?.id, 'gift');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Понятно'));
      await tester.pumpAndSettle();
      expect(controller.state.pendingCard, isNull);
      expect(find.byKey(gameResultCardKey), findsOneWidget);

      // The step is free to take by the state's account, and yet nothing
      // comes while the table is still reading what the last card did.
      await tester.pump(const Duration(minutes: 1));
      expect(controller.state.pendingCard, isNull);
      expect(controller.state.partySteps, 2);

      // Closed, and the countdown starts over from the full delay, counted
      // from the moment the card is dismissed.
      await tester.tap(find.text('Продолжить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byKey(gameResultCardKey), findsNothing);
      expect(controller.state.pendingCard, isNull);
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.state.pendingCard?.id, 'gift');
    });
  });

  testWidgets('a hidden check says what came of it, with no coin', (
    tester,
  ) async {
    final controller = _controller(
      cards: [
        GameCard(
          id: 'bag',
          title: 'Мешок',
          description: 'd',
          type: CardType.event,
          rarity: Rarity.common,
          weight: 1,
          choices: const [
            CardChoice(
              label: 'Проверить мешок',
              actions: [
                ChanceCheckAction(
                  open: false,
                  winnerOutcome: 'Нашлось.',
                  loserOutcome: 'Пусто.',
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await _pumpGame(
      tester,
      controller,
      const WalkSettings(mode: WalkMode.manual),
    );

    await tester.tap(find.text(_start));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Проверить мешок'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The roll screen's body is private to its file; its name is the one
    // handle a test from outside has on it.
    expect(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_RollBody'),
      findsNothing,
    );
    expect(find.text('Последствие'), findsOneWidget);
    final told = find.text('Нашлось.').evaluate().isNotEmpty
        ? 'Нашлось.'
        : 'Пусто.';
    expect(find.text(told), findsOneWidget);

    // What it said is what it did: nothing has been applied until the
    // player has read it, and then exactly that branch is.
    expect(controller.state.pendingCard, isNotNull);
    await tester.tap(find.text('Понятно'));
    await tester.pump();
    expect(controller.state.pendingCard, isNull);
  });
}
