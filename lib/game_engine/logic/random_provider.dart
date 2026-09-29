import 'dart:math';

/// The single source of randomness for a match. Every roll in the engine
/// goes through this instead of a bare `dart:math` `Random`, so:
///
/// - a game can be replayed exactly by reusing its [seed] (debugging,
///   reproducing a reported bug, "daily challenge" runs where every player
///   should see the same sequence of cards that day);
/// - tests can construct a deterministic provider instead of asserting on
///   randomized outcomes.
final class RandomProvider {
  final int seed;
  final Random _source;

  /// A stream of its own for whether a watched coin stands on its edge,
  /// seeded from the match's: adding the edge moved none of the draws an
  /// existing seed replays.
  final Random _edge;

  factory RandomProvider({int? seed}) {
    final resolvedSeed = seed ?? DateTime.now().microsecondsSinceEpoch;
    return RandomProvider._(
      resolvedSeed,
      Random(resolvedSeed),
      Random(resolvedSeed ^ 0x3D6E5EED),
    );
  }

  RandomProvider._(this.seed, this._source, this._edge);

  /// Whether a coin stands on its edge, at odds of [chance].
  bool nextEdge(double chance) => _edge.nextDouble() < chance;

  int nextInt(int max) => _source.nextInt(max);

  bool nextBool() => _source.nextBool();

  double nextDouble() => _source.nextDouble();

  T pick<T>(List<T> items) => items[nextInt(items.length)];
}
