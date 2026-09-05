import 'origin_category.dart';
import 'rarity.dart';
import 'stat_type.dart';

/// A player's hidden background — see the design doc's Origin/Background
/// system. Origins are never chosen at setup: every player starts
/// "Неизвестный" and a rare in-game event (`RevealOriginAction`) is what
/// attaches one permanently, mid-game.
///
/// [category] is which of the three senses this origin belongs to — see
/// `OriginCategory`. [rarity] is a separate axis: how rare the *reveal*
/// is and how deep its world impact runs. Within [OriginCategory.lifePath]
/// and [OriginCategory.trueNature], higher rarity does **not** mean a
/// bigger [statModifiers] — the stat nudge stays the same small
/// +1/+1/-1 scale at every tier — it means the reveal itself gets rarer
/// and more narratively significant, and [Rarity.legendary] origins are
/// the extreme case: they can *only* be granted from inside a specific
/// one-of-a-kind legendary adventure (see e.g. `dragon.json`), never from
/// an ordinary card, so most players will never see one even across
/// dozens of matches. [OriginCategory.hardPast] origins break that
/// balance on purpose — see [statModifiers].
///
/// [statModifiers] is the *only* direct mechanical weight an origin
/// carries. For [OriginCategory.lifePath]/[OriginCategory.trueNature] it's
/// a small permanent +1/+1/-1-scale nudge; for [OriginCategory.hardPast]
/// it's allowed to be net negative — a real, unbalanced cost, because the
/// payoff for those origins is paid in narrative access instead of stats.
/// Applied once by `RevealOriginAction`. Everything else an origin does —
/// a small atmospheric reaction to a specific biome or neutral event, an
/// extra choice, a friendlier or warier NPC, an exclusive branch in a
/// legendary adventure — comes from ordinary content
/// (`GameCard`/`AdventureChoice`) gated with
/// `AnyPlayerHasOriginCondition`/`CurrentPlayerHasOriginCondition` and
/// targeted with `HasOriginParticipant`, the same "define once, react via
/// ordinary conditions" pattern every other system in this engine uses.
/// There is no separate "origin modifier" system beyond that one
/// permanent stat nudge.
final class Origin {
  final String id;
  final String name;
  final String description;
  final OriginCategory category;
  final Rarity rarity;
  final Map<StatType, int> statModifiers;

  const Origin({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.rarity,
    this.statModifiers = const {},
  });

  factory Origin.fromJson(Map<String, dynamic> json) => Origin(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    category: OriginCategory.fromJson(json['category'] as String),
    rarity: Rarity.fromJson(json['rarity'] as String),
    statModifiers: (json['statModifiers'] as Map<String, dynamic>? ?? const {})
        .map((k, v) => MapEntry(StatType.fromJson(k), v as int)),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category.toJson(),
    'rarity': rarity.toJson(),
    'statModifiers': statModifiers.map((k, v) => MapEntry(k.toJson(), v)),
  };
}
