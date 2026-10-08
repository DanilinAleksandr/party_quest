import 'dart:math';

import 'player.dart';
import 'stat_type.dart';

/// How drunk a character is, as the table is told it — never as a number.
///
/// Every threshold, shift and rate lives in this file, so tuning after a
/// playtest is one place to look.
enum IntoxicationLevel {
  sober,
  tipsy,
  drunk,
  wasted;

  static IntoxicationLevel of(double intoxication) {
    if (intoxication >= kWastedAt) return wasted;
    if (intoxication >= kDrunkAt) return drunk;
    if (intoxication >= kTipsyAt) return tipsy;
    return sober;
  }

  static IntoxicationLevel fromJson(String value) =>
      IntoxicationLevel.values.byName(value);

  String toJson() => name;

  /// The word the table sees beside a name. Sober says nothing at all.
  String? get word => switch (this) {
    sober => null,
    tipsy => 'навеселе',
    drunk => 'пьян',
    wasted => 'в стельку',
  };
}

/// Thresholds on `Player.intoxication`, in drinks.
///
/// «Навеселе» begins with the first drink at any age: it is the faint end
/// of the scale, so that one drink stays one for as long as it is meant to
/// — even an old hand's three-quarters of one, which a threshold at a full
/// drink never showed at all. Age still decides how soon the drink tells
/// further up the scale.
const double kTipsyAt = 0.15;
const double kDrunkAt = 3;
const double kWastedAt = 5;

/// At this many drinks a character is out cold for [kPassOutCards] cards.
const double kPassOutAt = 7;
const int kPassOutCards = 3;

/// A party of one has nobody to carry on while its only player sleeps, so
/// the scale stops just short of passing out.
const double kSoloCap = 6.9;

/// What wears off on each of a character's own turns — a card about them —
/// and how much faster a night at the fire does it.
///
/// Counted on their own turns rather than on every card the party plays:
/// at a table of five a card-by-card tick took a drink away before its
/// drinker had a turn to be tipsy in. At this rate one drink holds
/// «навеселе» for five of the drinker's own turns even at the oldest age
/// (0.75 → 0.15), and at the fire it still takes three.
const double kSoberingPerTurn = 0.15;
const int kRestSoberingFactor = 2;

/// The hangover is an ordinary effect with a duration, so it expires and
/// shows the way every other effect does; what it does to the stats is
/// read from here, like the levels' shifts.
const String kHangoverEffectId = 'effect_hangover';

/// How old a character is, as far as the drink is concerned — the only
/// thing age does. Older drinks more before it shows but pays longer for
/// it; younger shows it at once and shakes it off. Shown at the table as a
/// number only, never as the bracket.
enum AgeBracket {
  young,
  mature,
  elder;

  static AgeBracket of(int age) {
    if (age >= kElderFrom) return elder;
    if (age >= kMatureFrom) return mature;
    return young;
  }

  static AgeBracket fromJson(String value) => AgeBracket.values.byName(value);

  String toJson() => name;
}

/// Every character is a grown-up: this is a game about drinking, and no
/// age below [kMinAge] can ever be rolled.
const int kMinAge = 20;
const int kMaxAge = 65;

/// Where the brackets begin: young 20–29, mature 30–49, elder 50–65.
const int kMatureFrom = 30;
const int kElderFrom = 50;

/// The age of a character with none on record — a save from before ages,
/// or a test that does not care. Mature, so nothing about the drink moves.
const int kDefaultAge = 35;

/// What one drink amounts to, by bracket. Applies to every `drink` — «Для
/// храбрости» and the hair of the dog alike; sobering and the thresholds
/// do not change.
const Map<AgeBracket, double> kDrinkFactor = {
  AgeBracket.young: 1.3,
  AgeBracket.mature: 1.0,
  AgeBracket.elder: 0.75,
};

/// How many cards the hangover lasts, by bracket. What it does to the stats
/// is the same for everybody — see [kHangoverShifts].
const Map<AgeBracket, int> kHangoverCards = {
  AgeBracket.young: 3,
  AgeBracket.mature: 6,
  AgeBracket.elder: 9,
};

/// The party's ages, one per player, from the match's seed. A generator of
/// their own rather than draws from the match's shared one, so adding ages
/// shifted none of the cards, duels and season an existing seed replays.
List<int> rollAges(int matchSeed, int count) {
  final random = Random(matchSeed ^ 0x0A6E5EED);
  return [
    for (var i = 0; i < count; i++)
      kMinAge + random.nextInt(kMaxAge - kMinAge + 1),
  ];
}

/// How each level shifts the stats a check reads. Luck is never touched —
/// it was only just made scarce, and a drink is not a way back to it.
const Map<IntoxicationLevel, Map<StatType, int>> kIntoxicationShifts = {
  IntoxicationLevel.sober: {},
  IntoxicationLevel.tipsy: {StatType.charisma: 1},
  IntoxicationLevel.drunk: {
    StatType.charisma: 1,
    StatType.strength: 1,
    StatType.attentiveness: -1,
    StatType.cunning: -1,
  },
  IntoxicationLevel.wasted: {
    StatType.charisma: 1,
    StatType.strength: 1,
    StatType.attentiveness: -2,
    StatType.cunning: -2,
    StatType.endurance: -1,
  },
};

const Map<StatType, int> kHangoverShifts = {
  StatType.attentiveness: -1,
  StatType.charisma: -1,
  StatType.endurance: -1,
};

/// The stats a check reads, derived on top of the base ones.
///
/// Derived rather than written into `PlayerStats`, so nothing ever has to be
/// "given back" when a character sobers up: the shift simply stops being
/// derived. Origins, by contrast, write their nudge into the base stats once
/// at the reveal — they are permanent, and this is not.
extension IntoxicationOf on Player {
  IntoxicationLevel get intoxicationLevel => IntoxicationLevel.of(intoxication);

  bool get isHungover => activeEffects.any((e) => e.id == kHangoverEffectId);

  bool get isPassedOut => passedOutCards > 0;

  AgeBracket get ageBracket => AgeBracket.of(age);

  /// What one drink amounts to for this character.
  double get drinkFactor => kDrinkFactor[ageBracket]!;

  /// How many cards this character's hangover lasts.
  int get hangoverCards => kHangoverCards[ageBracket]!;

  /// The hangover just applied from the catalog, set to this character's
  /// length of it.
  Player withHangoverForAge() => copyWith(
    activeEffects: [
      for (final e in activeEffects)
        e.id == kHangoverEffectId
            ? e.copyWith(duration: hangoverCards, remainingTurns: hangoverCards)
            : e,
    ],
  );

  /// Every shift in force right now, level and hangover together.
  Map<StatType, int> get intoxicationShifts {
    final shifts = <StatType, int>{...kIntoxicationShifts[intoxicationLevel]!};
    if (isHungover) {
      for (final MapEntry(key: stat, value: delta) in kHangoverShifts.entries) {
        shifts[stat] = (shifts[stat] ?? 0) + delta;
      }
    }
    shifts.removeWhere((_, delta) => delta == 0);
    return shifts;
  }

  /// What this character's own effects shift, for as long as they are on.
  Map<StatType, int> get effectStatShifts =>
      _sum([for (final e in activeEffects) e.statShifts]);

  /// What the others at the table put on this character — [party] is the
  /// whole table; this character's own effects in it are skipped.
  Map<StatType, int> partyShiftsFrom(Iterable<Player> party) => _sum([
    for (final p in party)
      if (p.id != id)
        for (final e in p.activeEffects) e.partyStatShifts,
  ]);

  /// The stat a check reads: the base, the drink, this character's effects,
  /// and — given the [party] — what the others' effects share with them.
  int effectiveStat(StatType stat, {Iterable<Player> party = const []}) =>
      stats.valueOf(stat) +
      (intoxicationShifts[stat] ?? 0) +
      (effectStatShifts[stat] ?? 0) +
      (partyShiftsFrom(party)[stat] ?? 0);

  /// The one word for the roster card: asleep, then drunk, then hungover.
  String? get conditionWord {
    if (isPassedOut) return 'спит';
    final word = intoxicationLevel.word;
    if (word != null) return word;
    if (isHungover) return 'похмелье';
    return null;
  }
}

Map<StatType, int> _sum(Iterable<Map<StatType, int>> all) {
  final total = <StatType, int>{};
  for (final shifts in all) {
    for (final MapEntry(key: stat, value: delta) in shifts.entries) {
      total[stat] = (total[stat] ?? 0) + delta;
    }
  }
  total.removeWhere((_, delta) => delta == 0);
  return total;
}
