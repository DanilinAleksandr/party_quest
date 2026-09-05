import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

const _forest = Biome(id: 'forest', name: 'Лес', description: 'd');

GameContext _buildContext({
  required List<Player> players,
  List<GameCard> cards = const [],
  WorldState worldState = const WorldState(),
  int seed = 1,
}) {
  return GameContext(
    state: GameState(
      players: players,
      currentPlayerIndex: 0,
      status: GameStatus.inProgress,
      worldState: worldState,
    ),
    random: RandomProvider(seed: seed),
    cardCatalog: CardCatalog(cards),
    itemCatalog: const ItemCatalog({}),
    effectCatalog: const EffectCatalog({}),
    adventureCatalog: const AdventureCatalog({}),
    biomeCatalog: BiomeCatalog({'forest': _forest}),
    originCatalog: const OriginCatalog({}),
    eventBus: GameEventBus(),
    mode: GameMode.classic,
  );
}

const _player = Player(id: 'p1', name: 'A');

const _fillerCard = GameCard(
  id: 'filler_card',
  title: 't',
  description: 'd',
  type: CardType.event,
  rarity: Rarity.common,
  weight: 5,
  tags: [CardTag.prologue],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InWeatherCondition / NotInWeatherCondition', () {
    test('match only the current weather', () {
      final rainy = _buildContext(
        players: [_player],
        worldState: const WorldState(currentWeather: Weather.rain),
      );
      final foggy = _buildContext(
        players: [_player],
        worldState: const WorldState(currentWeather: Weather.fog),
      );

      expect(
        const InWeatherCondition(weather: Weather.rain).isSatisfied(rainy),
        isTrue,
      );
      expect(
        const InWeatherCondition(weather: Weather.rain).isSatisfied(foggy),
        isFalse,
      );
      expect(
        const NotInWeatherCondition(weather: Weather.rain).isSatisfied(foggy),
        isTrue,
      );
      expect(
        const NotInWeatherCondition(weather: Weather.rain).isSatisfied(rainy),
        isFalse,
      );
    });
  });

  group('MinimumTurnsInWeatherCondition', () {
    test('false before enough turns, true once they pass', () {
      final early = _buildContext(
        players: [_player],
        worldState: const WorldState(turnsInCurrentWeather: 2),
      );
      final late = _buildContext(
        players: [_player],
        worldState: const WorldState(turnsInCurrentWeather: 4),
      );

      expect(
        const MinimumTurnsInWeatherCondition(turns: 4).isSatisfied(early),
        isFalse,
      );
      expect(
        const MinimumTurnsInWeatherCondition(turns: 4).isSatisfied(late),
        isTrue,
      );
    });
  });

  group('SetWeatherAction', () {
    test('changes currentWeather and resets turnsInCurrentWeather', () {
      final context = _buildContext(
        players: [_player],
        worldState: const WorldState(
          currentWeather: Weather.sunny,
          turnsInCurrentWeather: 6,
        ),
      );

      const executor = ActionExecutor();
      final next = executor.execute(
        const SetWeatherAction(weather: Weather.fog),
        context,
      );

      expect(next.state.worldState.currentWeather, Weather.fog);
      expect(next.state.worldState.turnsInCurrentWeather, 0);
    });
  });

  group('GameController turn flow', () {
    test(
      'turnsInCurrentWeather increments each step, independent of biome',
      () {
        final controller = GameController(
          seed: 1,
          playerNames: const ['A', 'B'],
          cards: const [_fillerCard],
          itemCatalog: const ItemCatalog({}),
          effectCatalog: const EffectCatalog({}),
          adventureCatalog: const AdventureCatalog({}),
          biomeCatalog: BiomeCatalog({'forest': _forest}),
          originCatalog: const OriginCatalog({}),
        );

        expect(controller.state.worldState.turnsInCurrentWeather, 0);
        controller.takeStep();
        controller.resolveCard(choiceIndex: null);
        expect(controller.state.worldState.turnsInCurrentWeather, 1);
        controller.takeStep();
        controller.resolveCard(choiceIndex: null);
        expect(controller.state.worldState.turnsInCurrentWeather, 2);
      },
    );
  });
}
