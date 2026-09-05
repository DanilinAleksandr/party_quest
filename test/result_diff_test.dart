import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/features/game/application/result_diff.dart';
import 'package:drinking_quest/features/game/application/result_entry.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

const _p1 = Player(id: 'p1', name: 'A');
const _p2 = Player(id: 'p2', name: 'B');

GameState _state({required List<Player> players, WorldState worldState = const WorldState()}) {
  return GameState(
    players: players,
    currentPlayerIndex: 0,
    status: GameStatus.inProgress,
    worldState: worldState,
  );
}

void main() {
  group('computeResultEntries — allyGained', () {
    test('emits allyGained when a registered ally flag flips false to true', () {
      final previous = _state(players: [_p1, _p2]);
      final next = _state(
        players: [_p1, _p2],
        worldState: const WorldState(flags: {'captain_ally': true}),
      );

      final entries = computeResultEntries(
        previous: previous,
        next: next,
        targets: [_p1],
        originCatalog: const OriginCatalog({}),
      );

      expect(entries, hasLength(1));
      expect(entries.single.kind, ResultKind.allyGained);
      expect(entries.single.headline, 'Капитан пиратов');
      expect(entries.single.description, isNotNull);
      expect(entries.single.description, isNotEmpty);
    });

    test('does not emit allyGained for an unregistered flag flipping true', () {
      final previous = _state(players: [_p1]);
      final next = _state(
        players: [_p1],
        worldState: const WorldState(flags: {'some_unrelated_flag': true}),
      );

      final entries = computeResultEntries(
        previous: previous,
        next: next,
        targets: [_p1],
        originCatalog: const OriginCatalog({}),
      );

      expect(entries, isEmpty);
    });

    test('does not re-emit allyGained when the flag was already true before', () {
      final previous = _state(
        players: [_p1],
        worldState: const WorldState(flags: {'warlord_ally': true}),
      );
      final next = _state(
        players: [_p1],
        worldState: const WorldState(flags: {'warlord_ally': true}),
      );

      final entries = computeResultEntries(
        previous: previous,
        next: next,
        targets: [_p1],
        originCatalog: const OriginCatalog({}),
      );

      expect(entries, isEmpty);
    });
  });
}
