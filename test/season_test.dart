import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

const _forest = Biome(id: 'forest', name: 'Лес', description: 'd');

GameContext _buildContext({
  required List<Player> players,
  WorldState worldState = const WorldState(),
}) {
  return GameContext(
    state: GameState(
      players: players,
      currentPlayerIndex: 0,
      status: GameStatus.inProgress,
      worldState: worldState,
    ),
    random: RandomProvider(seed: 1),
    cardCatalog: const CardCatalog([]),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InSeasonCondition / NotInSeasonCondition', () {
    test('match only the current season', () {
      final winter = _buildContext(
        players: [_player],
        worldState: const WorldState(currentSeason: Season.winter),
      );
      final summer = _buildContext(
        players: [_player],
        worldState: const WorldState(currentSeason: Season.summer),
      );

      expect(
        const InSeasonCondition(season: Season.winter).isSatisfied(winter),
        isTrue,
      );
      expect(
        const InSeasonCondition(season: Season.winter).isSatisfied(summer),
        isFalse,
      );
      expect(
        const NotInSeasonCondition(season: Season.winter).isSatisfied(summer),
        isTrue,
      );
      expect(
        const NotInSeasonCondition(season: Season.winter).isSatisfied(winter),
        isFalse,
      );
    });
  });

  group('GameController', () {
    test('rolls a season once at construction and never changes it', () {
      final controller = GameController(
        seed: 7,
        playerNames: const ['A', 'B'],
        cards: const [],
        itemCatalog: const ItemCatalog({}),
        effectCatalog: const EffectCatalog({}),
        adventureCatalog: const AdventureCatalog({}),
        biomeCatalog: BiomeCatalog({'forest': _forest}),
        originCatalog: const OriginCatalog({}),
      );

      final rolled = controller.state.worldState.currentSeason;
      expect(Season.values, contains(rolled));

      final again = GameController(
        seed: 7,
        playerNames: const ['A', 'B'],
        cards: const [],
        itemCatalog: const ItemCatalog({}),
        effectCatalog: const EffectCatalog({}),
        adventureCatalog: const AdventureCatalog({}),
        biomeCatalog: BiomeCatalog({'forest': _forest}),
        originCatalog: const OriginCatalog({}),
      );
      expect(
        again.state.worldState.currentSeason,
        rolled,
        reason: 'same seed must reproduce the same season',
      );
    });
  });
}
