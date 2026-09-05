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

  factory RandomProvider({int? seed}) {
    final resolvedSeed = seed ?? DateTime.now().microsecondsSinceEpoch;
    return RandomProvider._(resolvedSeed, Random(resolvedSeed));
  }

  RandomProvider._(this.seed, this._source);

  int nextInt(int max) => _source.nextInt(max);

  bool nextBool() => _source.nextBool();

  double nextDouble() => _source.nextDouble();

  T pick<T>(List<T> items) => items[nextInt(items.length)];
}
