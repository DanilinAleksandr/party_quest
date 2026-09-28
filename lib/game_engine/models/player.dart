import 'effect.dart';
import 'effect_polarity.dart';
import 'intoxication.dart';
import 'inventory_item.dart';
import 'player_stats.dart';

/// A player in the current match.
///
/// [blessings] and [curses] are *derived* from [activeEffects] rather than
/// stored as separate lists. Keeping one source of truth for "effects on
/// this player" avoids the two lists ever drifting out of sync with each
/// other — a blessing that turns into a curse (or vice versa) would
/// otherwise need to be moved between lists by hand everywhere it's
/// mutated.
///
/// [originId] is the player's optional background/character concept — see
/// `Origin`. Null means the player picked none at setup; origin-reactive
/// content (`AnyPlayerHasOriginCondition`/`HasOriginParticipant`) simply
/// never applies to them, the same way a player who never picked up an item
/// just never satisfies an item condition.
///
/// [intoxication] is how much the character has had, in drinks — see
/// `IntoxicationLevel` for what the table is told about it, which is never
/// the number. [wasDrunk] remembers the character got as far as drunk, so
/// coming back down below it brings the hangover; [passedOutCards] counts
/// down the cards a character sleeps through.
///
/// [age] is rolled at the start of a match, 20–65, and works only through
/// the drink — see `AgeBracket`.
final class Player {
  final String id;
  final String name;
  final String? originId;
  final int age;
  final List<InventoryItem> inventory;
  final PlayerStats stats;
  final List<GameEffect> activeEffects;
  final double intoxication;
  final bool wasDrunk;
  final int passedOutCards;

  const Player({
    required this.id,
    required this.name,
    this.originId,
    this.age = kDefaultAge,
    this.inventory = const [],
    this.stats = PlayerStats.initial,
    this.activeEffects = const [],
    this.intoxication = 0,
    this.wasDrunk = false,
    this.passedOutCards = 0,
  });

  List<GameEffect> get blessings => activeEffects
      .where((e) => e.polarity == EffectPolarity.positive)
      .toList(growable: false);

  List<GameEffect> get curses => activeEffects
      .where((e) => e.polarity == EffectPolarity.negative)
      .toList(growable: false);

  Player copyWith({
    String? id,
    String? name,
    String? originId,
    int? age,
    List<InventoryItem>? inventory,
    PlayerStats? stats,
    List<GameEffect>? activeEffects,
    double? intoxication,
    bool? wasDrunk,
    int? passedOutCards,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      originId: originId ?? this.originId,
      age: age ?? this.age,
      inventory: inventory ?? this.inventory,
      stats: stats ?? this.stats,
      activeEffects: activeEffects ?? this.activeEffects,
      intoxication: intoxication ?? this.intoxication,
      wasDrunk: wasDrunk ?? this.wasDrunk,
      passedOutCards: passedOutCards ?? this.passedOutCards,
    );
  }

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id: json['id'] as String,
    name: json['name'] as String,
    originId: json['originId'] as String?,
    age: json['age'] as int? ?? kDefaultAge,
    inventory: (json['inventory'] as List<dynamic>? ?? const [])
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    stats: json['stats'] == null
        ? PlayerStats.initial
        : PlayerStats.fromJson(json['stats'] as Map<String, dynamic>),
    activeEffects: (json['activeEffects'] as List<dynamic>? ?? const [])
        .map((e) => GameEffect.fromJson(e as Map<String, dynamic>))
        .toList(),
    intoxication: (json['intoxication'] as num?)?.toDouble() ?? 0,
    wasDrunk: json['wasDrunk'] as bool? ?? false,
    passedOutCards: json['passedOutCards'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'originId': originId,
    'age': age,
    'inventory': inventory.map((i) => i.toJson()).toList(),
    'stats': stats.toJson(),
    'activeEffects': activeEffects.map((e) => e.toJson()).toList(),
    'intoxication': intoxication,
    'wasDrunk': wasDrunk,
    'passedOutCards': passedOutCards,
  };
}
