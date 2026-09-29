/// How a watched coin came down: on one face or the other, or — once in a
/// long while — standing on its edge.
///
/// The edge is the rare critical outcome of a gamble: it favours whoever
/// threw, whatever they called, and a duel it lands in is a draw nobody pays
/// for. Only a coin the table watches can do it; a hidden check has no coin.
enum CoinThrow {
  win,
  lose,
  edge;

  /// Whether the thrower comes out of it well — on the face that wins, or
  /// on the edge, which counts as better than either.
  bool get favours => this != lose;
}

/// How often a watched coin stands on its edge.
const double kCoinEdgeChance = 1 / 75;

/// What an edge in a check puts on the one who threw it, on top of the
/// winning branch.
const String kCoinEdgeEffectId = 'effect_lucky_echo';

/// Said when a check that landed on its edge has no `edgeOutcome` of its own.
const String kCoinEdgeOutcome =
    'Такое бывает раз в жизни. Всё обернулось лучше, чем вообще могло.';

/// Said when a duel's coin lands on its edge.
const String kDuelEdgeOutcome =
    '{challenger} и {opponent} смотрят на монету, стоящую на ребре. Спор '
    'решать некому — и платить никому.';
