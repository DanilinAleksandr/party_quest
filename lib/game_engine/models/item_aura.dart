import 'stat_type.dart';

/// What a found thing may carry without anyone seeing it: a curse or a
/// blessing. It is decided as the card that shows the find is drawn — so a
/// close look can see it before anyone takes it — and goes with the thing
/// into the taker's bag. It works through the stats a check reads and
/// through the drink, never through what the screen shows: the profile
/// says luck 5 while the coin is weighed against less.
enum AuraKind {
  /// Takes a point of luck every few of the holder's own turns.
  luckDrain(curse: true),

  /// A drink goes to the head harder.
  heavyHead(curse: true),

  /// The drink wears off slower.
  longHangover(curse: true),

  /// Quietly takes points off one stat.
  quietWeakness(curse: true),

  /// A drink goes to the head lighter.
  lightHead(curse: false),

  /// Gives a point of luck every three of the holder's own turns.
  quietLuck(curse: false),

  /// No hangover comes.
  noHangover(curse: false),

  /// Quietly adds points to one stat.
  quietStrength(curse: false);

  final bool curse;
  const AuraKind({required this.curse});

  static const curses = [luckDrain, heavyHead, longHangover, quietWeakness];
  static const blessings = [lightHead, quietLuck, noHangover, quietStrength];

  /// The blessing a shaman's re-enchanting turns this curse into.
  AuraKind get mirror => switch (this) {
    luckDrain => quietLuck,
    heavyHead => lightHead,
    longHangover => noHangover,
    quietWeakness => quietStrength,
    _ => this,
  };

  /// Whether the aura needs a stat to work on.
  bool get onStat => this == quietWeakness || this == quietStrength;

  static AuraKind fromJson(String v) => AuraKind.values.byName(v);
}

/// What a close look at a find came to notice about its aura — see
/// `inspectFind`. A knowing choice ("Взять — пусть холодит") waits for it.
enum AuraNotice {
  none,
  curse,
  blessing;

  static AuraNotice fromJson(String v) => AuraNotice.values.byName(v);
}

/// How often a find carries an aura, decided as its card is drawn.
const double kCurseChance = 0.12;
const double kBlessingChance = 0.03;

/// The taker's true luck at or below which a curse takes its heavy form.
const int kHeavyCurseLuck = -1;

/// The stats a weakness or a strength can sit on: luck has its own drain
/// and its own gift.
const List<StatType> kAuraStats = [
  StatType.strength,
  StatType.charisma,
  StatType.endurance,
  StatType.attentiveness,
  StatType.cunning,
];

final class ItemAura {
  final AuraKind kind;

  /// The heavy form of a curse: decided by the taker's luck as they take
  /// the thing. Blessings have no heavy form.
  final bool heavy;

  /// The stat a weakness or a strength sits on.
  final StatType? stat;

  /// The holder's own turns counted since the thing was taken, and the
  /// luck drained or given so far — kept on the thing, so it goes when the
  /// thing goes.
  final int turns;
  final int accrued;

  /// Noticed on a close look before the thing was taken: the party knows
  /// it is cursed or blessed — not how; only a shaman can name it.
  final bool known;

  const ItemAura({
    required this.kind,
    this.heavy = false,
    this.stat,
    this.turns = 0,
    this.accrued = 0,
    this.known = false,
  });

  bool get curse => kind.curse;

  /// Every how many own turns the luck moves, and how far it may go.
  int get period => kind == AuraKind.luckDrain && heavy ? 2 : 3;
  int get cap => kind == AuraKind.luckDrain && heavy ? 10 : 5;

  /// One more of the holder's own turns.
  ItemAura tick() {
    final t = turns + 1;
    var a = accrued;
    if (t % period == 0) {
      if (kind == AuraKind.luckDrain && -a < cap) a -= 1;
      if (kind == AuraKind.quietLuck && a < cap) a += 1;
    }
    return copyWith(turns: t, accrued: a);
  }

  /// What the aura does to the stats a check reads.
  Map<StatType, int> get shifts => switch (kind) {
    AuraKind.luckDrain ||
    AuraKind.quietLuck => accrued == 0 ? const {} : {StatType.luck: accrued},
    AuraKind.quietWeakness => {stat!: heavy ? -3 : -2},
    AuraKind.quietStrength => {stat!: 2},
    _ => const {},
  };

  /// What one drink amounts to, as a multiplier.
  double get drinkFactor => switch (kind) {
    AuraKind.heavyHead => heavy ? 2 : 1.5,
    AuraKind.lightHead => 0.5,
    _ => 1,
  };

  /// How much slower the drink wears off, as a divisor.
  double get soberDivisor =>
      kind == AuraKind.longHangover ? (heavy ? 3 : 2) : 1;

  bool get blocksHangover => kind == AuraKind.noHangover;

  ItemAura copyWith({
    AuraKind? kind,
    bool? heavy,
    int? turns,
    int? accrued,
    bool? known,
  }) => ItemAura(
    kind: kind ?? this.kind,
    heavy: heavy ?? this.heavy,
    stat: stat,
    turns: turns ?? this.turns,
    accrued: accrued ?? this.accrued,
    known: known ?? this.known,
  );

  factory ItemAura.fromJson(Map<String, dynamic> json) => ItemAura(
    kind: AuraKind.fromJson(json['kind'] as String),
    heavy: json['heavy'] as bool? ?? false,
    stat: json['stat'] == null
        ? null
        : StatType.values.byName(json['stat'] as String),
    turns: json['turns'] as int? ?? 0,
    accrued: json['accrued'] as int? ?? 0,
    known: json['known'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    if (heavy) 'heavy': true,
    if (stat != null) 'stat': stat!.name,
    if (turns != 0) 'turns': turns,
    if (accrued != 0) 'accrued': accrued,
    if (known) 'known': true,
  };
}
