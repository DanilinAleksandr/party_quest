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
const double kTipsyAt = 1;
const double kDrunkAt = 3;
const double kWastedAt = 5;

/// At this many drinks a character is out cold for [kPassOutCards] cards.
const double kPassOutAt = 7;
const int kPassOutCards = 3;

/// A party of one has nobody to carry on while its only player sleeps, so
/// the scale stops just short of passing out.
const double kSoloCap = 6.9;

/// What wears off per card played, and how much faster a night at the fire
/// does it.
const double kSoberingPerCard = 0.1;
const int kRestSoberingFactor = 3;

/// The hangover is an ordinary effect with a duration, so it expires and
/// shows the way every other effect does; what it does to the stats is
/// read from here, like the levels' shifts.
const String kHangoverEffectId = 'effect_hangover';

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

  int effectiveStat(StatType stat) =>
      stats.valueOf(stat) + (intoxicationShifts[stat] ?? 0);

  /// The one word for the roster card: asleep, then drunk, then hungover.
  String? get conditionWord {
    if (isPassedOut) return 'спит';
    final word = intoxicationLevel.word;
    if (word != null) return word;
    if (isHungover) return 'похмелье';
    return null;
  }
}
