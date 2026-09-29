import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/features/game/presentation/widgets/chance_check_dialog.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

const _echo = GameEffect(
  id: kCoinEdgeEffectId,
  name: 'Счастливое эхо',
  description: 'd',
  polarity: EffectPolarity.positive,
  duration: 15,
  remainingTurns: 15,
);

GameCard _card(String id, List<GameAction> actions) => GameCard(
  id: id,
  title: 'Карточка $id',
  description: 'd',
  type: CardType.event,
  rarity: Rarity.common,
  weight: 1,
  choices: [
    CardChoice(label: 'Рискнуть', actions: actions),
    const CardChoice(label: 'Пройти мимо'),
  ],
);

GameController _controller(
  GameCard card, {
  List<String> players = const ['A', 'B'],
  int seed = 5,
}) => GameController(
  playerNames: players,
  cards: [card],
  itemCatalog: const ItemCatalog({}),
  effectCatalog: const EffectCatalog({kCoinEdgeEffectId: _echo}),
  adventureCatalog: const AdventureCatalog({}),
  biomeCatalog: const BiomeCatalog({}),
  originCatalog: const OriginCatalog({}),
  seed: seed,
  journeySteps: null,
  skipPrologue: true,
);

final _check = _card('check', const [
  ChanceCheckAction(
    winnerActions: [ModifyStatAction(stat: StatType.luck, amount: 1)],
    loserActions: [ModifyStatAction(stat: StatType.luck, amount: -1)],
  ),
]);

final _duel = _card('duel', const [
  StartDuelAction(
    winnerActions: [ModifyStatAction(stat: StatType.charisma, amount: 1)],
    loserActions: [ModifyStatAction(stat: StatType.charisma, amount: -1)],
  ),
]);

final _hidden = _card('hidden', const [
  ChanceCheckAction(
    open: false,
    winnerActions: [ModifyStatAction(stat: StatType.luck, amount: 1)],
  ),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the throw', () {
    test('stands on its edge about once in 75 throws', () {
      final c = _controller(_check);
      var edges = 0;
      const throws = 10000;
      for (var i = 0; i < throws; i++) {
        if (c.roll() == CoinThrow.edge) edges++;
      }
      // Expected 133; four standard deviations either way.
      expect(edges, inInclusiveRange(88, 180));
      // ignore: avoid_print
      print('edges in $throws throws: $edges (1/${throws ~/ edges})');
    });

    test('the same seed throws the same, edges included', () {
      List<CoinThrow> throws(int seed) {
        final c = _controller(_check, seed: seed);
        return [for (var i = 0; i < 2000; i++) c.roll()];
      }

      expect(throws(9), throws(9));
      expect(throws(9), contains(CoinThrow.edge));
    });

    test('the faces an existing seed throws are unchanged by the edge', () {
      // The edge comes from a stream of its own: the face a throw lands on
      // is still the match's next coin, as it was before the edge existed.
      final c = _controller(_check, seed: 11);
      final expected = RandomProvider(seed: 11);
      // The controller drew the season from the same stream first.
      expected.nextInt(Season.values.length);
      for (var i = 0; i < 500; i++) {
        final face = expected.nextBool();
        final coin = c.roll();
        if (coin != CoinThrow.edge) expect(coin.favours, face);
      }
    });

    test('a hidden check has no coin, so no edge', () {
      final c = _controller(_hidden);
      for (var i = 0; i < 10000; i++) {
        expect(c.roll(watched: false), isNot(CoinThrow.edge));
      }
    });
  });

  group('on its edge', () {
    test('a check runs its winning branch and adds «Счастливое эхо»', () {
      final c = _controller(_check)..takeStep();
      final me = c.state.currentPlayer.id;
      c.resolveCard(choiceIndex: 0, coinEdge: true);
      final p = c.state.players.firstWhere((p) => p.id == me);
      expect(p.stats.valueOf(StatType.luck), 1);
      expect(p.activeEffects.map((e) => e.id), contains(kCoinEdgeEffectId));
      // Nobody else is touched.
      for (final other in c.state.players.where((p) => p.id != me)) {
        expect(other.stats.valueOf(StatType.luck), 0);
        expect(other.activeEffects, isEmpty);
      }
    });

    test('a duel is a draw: neither branch, no winner, no loser', () {
      final c = _controller(_duel, players: const ['A', 'B', 'C'])..takeStep();
      final gamble = c.gambleFor(choiceIndex: 0)!;
      c.resolveCard(
        choiceIndex: 0,
        coinEdge: true,
        opponentId: gamble.opponentId,
      );
      for (final p in c.state.players) {
        expect(p.stats.valueOf(StatType.charisma), 0);
      }
      expect(c.state.worldState.previousWinnerId, isNull);
      expect(c.state.worldState.previousLoserId, isNull);
    });

    test('goes into the chronicle as a legend of its own', () {
      final c = _controller(_check)..takeStep();
      final name = c.state.currentPlayer.name;
      c.resolveCard(choiceIndex: 0, coinEdge: true);
      final entry = c.state.chronicle.single;
      expect(entry.coinEdge, isTrue);
      expect(entry.text, contains('Карточка check'));
      expect(entry.text, contains(name));
      expect(entry.text, contains('на ребро'));

      final d = _controller(_duel, players: const ['A', 'B'])..takeStep();
      final gamble = d.gambleFor(choiceIndex: 0)!;
      d.resolveCard(
        choiceIndex: 0,
        coinEdge: true,
        opponentId: gamble.opponentId,
      );
      final duelEntry = d.state.chronicle.single;
      expect(duelEntry.coinEdge, isTrue);
      expect(duelEntry.text, contains(gamble.challenger));
      expect(duelEntry.text, contains(gamble.opponent));
    });

    test('an ordinary throw writes nothing to the chronicle', () {
      final c = _controller(_check)..takeStep();
      c.resolveCard(choiceIndex: 0, gambleWon: true);
      expect(c.state.chronicle, isEmpty);
    });

    test('says its own words, or the general ones', () {
      const gamble = Gamble(winnerOutcome: 'w', loserOutcome: 'l');
      expect(gamble.outcomeForThrow(CoinThrow.edge), kCoinEdgeOutcome);
      expect(gamble.outcomeForThrow(CoinThrow.win), 'w');
      expect(
        const Gamble(edgeOutcome: 'e').outcomeForThrow(CoinThrow.edge),
        'e',
      );
      const duel = Gamble(
        winnerOutcome: 'w',
        challenger: 'Аня',
        opponent: 'Боря',
        opponentId: 'b',
      );
      expect(
        duel.outcomeForThrow(CoinThrow.edge),
        'Аня и Боря смотрят на монету, стоящую на ребре. Спор решать '
        'некому — и платить никому.',
      );
    });

    test('a check\'s edge words survive JSON', () {
      const a = ChanceCheckAction(edgeOutcome: 'чудо');
      final back = GameAction.fromJson(a.toJson()) as ChanceCheckAction;
      expect(back.edgeOutcome, 'чудо');
    });
  });

  group('the dialog', () {
    Future<void> roll(
      WidgetTester tester, {
      List<String>? sides,
      int? calledIndex,
      String? challenger,
      String? opponent,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showChanceCheckDialog(
                context: context,
                passed: true,
                edge: true,
                sides: sides,
                calledIndex: calledIndex,
                challenger: challenger,
                opponent: opponent,
              ),
              child: const Text('gamble'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('gamble'));
      await tester.pump();
    }

    testWidgets('says «Ребро» only once the coin stands still', (tester) async {
      await roll(tester);
      // Down and rocking, but not yet standing: nothing is said.
      await tester.pump(const Duration(milliseconds: 2600));
      expect(find.text('Ребро'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Ребро'), findsOneWidget);
      expect(find.text('Монета встала на ребро.'), findsOneWidget);
      expect(find.text('Обошлось'), findsNothing);
    });

    testWidgets('a called wager says the edge came up', (tester) async {
      await roll(tester, sides: const ['Король', 'Шут'], calledIndex: 1);
      await tester.pumpAndSettle();
      expect(find.text('Ставка: Шут  ·  Выпало: ребро'), findsOneWidget);
    });

    testWidgets('a duel on its edge names nobody to pay', (tester) async {
      await roll(tester, challenger: 'Аня', opponent: 'Боря');
      await tester.pumpAndSettle();
      expect(find.text('Аня и Боря'), findsOneWidget);
      expect(find.text('Ребро'), findsOneWidget);
      expect(find.textContaining('Платит'), findsNothing);
    });
  });

  group('a coin that spins on its edge', () {
    Future<void> spin(
      WidgetTester tester, {
      required bool passed,
      List<String>? sides,
      int? calledIndex,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showChanceCheckDialog(
                context: context,
                passed: passed,
                spinner: true,
                sides: sides,
                calledIndex: calledIndex,
              ),
              child: const Text('gamble'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('gamble'));
      await tester.pump();
    }

    String face(WidgetTester tester) {
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      return (svg.bytesLoader as SvgAssetLoader).assetName;
    }

    testWidgets('says nothing while it spins', (tester) async {
      await spin(tester, passed: true);
      // Down after two seconds in the air, and spinning for at least 1.5.
      await tester.pump(const Duration(milliseconds: 3000));
      expect(find.text('Обошлось'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Обошлось'), findsOneWidget);
    });

    testWidgets('a check that held falls on the King', (tester) async {
      await spin(tester, passed: true);
      await tester.pumpAndSettle();
      expect(face(tester), contains('coin_king'));
    });

    testWidgets('a check that failed falls on the Jester', (tester) async {
      await spin(tester, passed: false);
      await tester.pumpAndSettle();
      expect(face(tester), contains('coin_jester'));
    });

    testWidgets('a called wager lands on the side the call needs', (
      tester,
    ) async {
      await spin(
        tester,
        passed: true,
        sides: const ['Король', 'Шут'],
        calledIndex: 1,
      );
      await tester.pumpAndSettle();
      expect(face(tester), contains('coin_jester'));
      expect(find.text('Ставка: Шут  ·  Выпало: Шут'), findsOneWidget);
    });
  });
}
