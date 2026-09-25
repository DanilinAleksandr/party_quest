import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

GameController _controller() => GameController(
  playerNames: _args.playerNames,
  cards: _cards,
  itemCatalog: const ItemCatalog({}),
  effectCatalog: const EffectCatalog({}),
  adventureCatalog: const AdventureCatalog({}),
  biomeCatalog: const BiomeCatalog({}),
  originCatalog: const OriginCatalog({}),
  seed: 3,
  journeySteps: 200,
  skipPrologue: true,
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

const _button = 'ПРОДОЛЖИТЬ ПОХОД';

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
    testWidgets('by hand: the button is there and takes the step', (
      tester,
    ) async {
      final controller = _controller();
      await _pumpGame(
        tester,
        controller,
        const WalkSettings(mode: WalkMode.manual),
      );

      expect(find.text(_button), findsOneWidget);
      // No timer is walking the party behind the button's back.
      await tester.pump(const Duration(seconds: 30));
      expect(controller.state.pendingCard, isNull);

      await tester.tap(find.text(_button));
      await tester.pump();
      expect(controller.state.pendingCard, isNotNull);
    });

    testWidgets('on its own: no button, and a card turns up by itself', (
      tester,
    ) async {
      final controller = _controller();
      await _pumpGame(
        tester,
        controller,
        const WalkSettings(mode: WalkMode.auto, minDelay: 2, maxDelay: 3),
      );

      expect(find.text(_button), findsNothing);

      await tester.pump(const Duration(milliseconds: 1900));
      expect(controller.state.pendingCard, isNull);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(controller.state.pendingCard, isNotNull);

      // The card is on screen now, and the countdown is gone with it: a
      // minute later there is still only the one card.
      final card = controller.state.pendingCard;
      await tester.pump(const Duration(minutes: 1));
      expect(controller.state.pendingCard, same(card));
      expect(controller.state.partySteps, 1);
    });

    testWidgets('at a halt the button is back, even walking on its own', (
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
      expect(find.text(_button), findsOneWidget);

      // The timer does not reach in here.
      await tester.pump(const Duration(seconds: 30));
      expect(controller.state.pendingCard, isNull);

      await tester.tap(find.text(_button));
      await tester.pump();
      expect(controller.state.pendingCard?.id, 'rest_departure');
    });
  });
}
