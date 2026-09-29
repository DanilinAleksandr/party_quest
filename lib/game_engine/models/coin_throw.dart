import 'dart:math';

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

/// How one throw of the coin looks — never what it comes to, which is
/// always the [CoinThrow] already thrown. Every throw is drawn afresh, so
/// the table cannot learn the pattern.
///
/// All of it follows from [number], the variant's name: the same number is
/// the same throw, which is what lets a replay look the same and lets
/// somebody say «вариант 3 плохой».
final class CoinStyle {
  final int number;

  /// How high the toss goes, against the usual: 0.8–1.2.
  final double lift;

  /// Half-turns in the air: 8, 10 or 12 — always even, so a coin that falls
  /// flat can be started on the face it must end on.
  final int halfTurns;

  /// How far the axis it turns about leans off square, in radians, so it
  /// does not always turn straight at the eye.
  final double axisTilt;

  /// Whether it comes down spinning on its edge like a disc on a table —
  /// about one throw in three. A coin that will stand always spins.
  final bool spins;

  /// Which way it wheels when it spins: 1 or −1.
  final int spinDirection;

  /// How long it spins on its edge, in seconds: 1.5–2.5.
  final double spinTime;

  /// How far it rolls round while spinning, in logical pixels.
  final double rollRadius;

  /// How many times it bounces when it lands flat: 1–3.
  final int bounces;

  /// How many times a coin that will stand nearly falls first: 1–3.
  final int nearFalls;

  const CoinStyle({
    required this.number,
    required this.lift,
    required this.halfTurns,
    required this.axisTilt,
    required this.spins,
    required this.spinDirection,
    required this.spinTime,
    required this.rollRadius,
    required this.bounces,
    required this.nearFalls,
  });

  factory CoinStyle.of(int number) {
    final r = Random(number);
    return CoinStyle(
      number: number,
      lift: 0.8 + 0.4 * r.nextDouble(),
      halfTurns: const [8, 10, 12][r.nextInt(3)],
      axisTilt: (r.nextDouble() - 0.5) * 0.5,
      spins: r.nextInt(3) == 0,
      spinDirection: r.nextBool() ? 1 : -1,
      spinTime: 1.5 + r.nextDouble(),
      rollRadius: 2 + 5 * r.nextDouble(),
      bounces: 1 + r.nextInt(3),
      nearFalls: 1 + r.nextInt(3),
    );
  }

  /// The variant numbers there are.
  static const int count = 10000;

  CoinStyle copyWith({bool? spins}) => CoinStyle(
    number: number,
    lift: lift,
    halfTurns: halfTurns,
    axisTilt: axisTilt,
    spins: spins ?? this.spins,
    spinDirection: spinDirection,
    spinTime: spinTime,
    rollRadius: rollRadius,
    bounces: bounces,
    nearFalls: nearFalls,
  );
}
