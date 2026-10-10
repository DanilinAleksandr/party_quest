import '../models/models.dart';

/// The odds of a gamble: a stat moves them, luck moves them a little more,
/// and neither decides. It stays a game of luck, not of builds — the best
/// at something still loses now and then, the weakest still wins.
///
/// Every value read is the stat a check reads (`Player.effectiveStat`):
/// the drink, the effects on, the others' shared effects and any unseen
/// aura, all in.

/// How far one point of a stat moves the odds, and how far a stat can move
/// them at most: 50 % ± 15 %. The step is set so that a player stronger
/// than four in five at a check stands at about 60–65 %, and the middle one
/// at 50 % — see the table in the PR that set it.
const double kStatStep = 0.10;
const double kStatSwing = 0.15;

/// The same for luck, on top: ± 10 % at most.
const double kLuckStep = 0.03;
const double kLuckSwing = 0.10;

/// The odds never go past these, whatever is stacked.
const double kOddsFloor = 0.25;
const double kOddsCeiling = 0.75;

double _clamp(double v, double lo, double hi) => v < lo
    ? lo
    : v > hi
    ? hi
    : v;

double _odds(int statDiff, int luckDiff, {required bool withStat}) {
  final stat = withStat
      ? _clamp(statDiff * kStatStep, -kStatSwing, kStatSwing)
      : 0.0;
  final luck = _clamp(luckDiff * kLuckStep, -kLuckSwing, kLuckSwing);
  return _clamp(0.5 + stat + luck, kOddsFloor, kOddsCeiling);
}

/// The odds that [player] passes a check on [stat] — against [against], a
/// scene's own number (an NPC's), 0 when it has none. Without a stat only
/// luck moves them.
double checkOdds(
  Player player,
  StatType? stat, {
  int against = 0,
  Iterable<Player> party = const [],
}) => _odds(
  stat == null ? 0 : player.effectiveStat(stat, party: party) - against,
  player.effectiveStat(StatType.luck, party: party),
  withStat: stat != null,
);

/// The odds that [challenger] wins a duel on [stat] against [opponent]: by
/// the difference, both in the stat and in luck. Symmetric — what one side
/// has, the other lacks.
double duelOdds(
  Player challenger,
  Player opponent,
  StatType? stat, {
  Iterable<Player> party = const [],
}) {
  int diff(StatType s) =>
      challenger.effectiveStat(s, party: party) -
      opponent.effectiveStat(s, party: party);
  return _odds(
    stat == null ? 0 : diff(stat),
    diff(StatType.luck),
    withStat: stat != null,
  );
}
