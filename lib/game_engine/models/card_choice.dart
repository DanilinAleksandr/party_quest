import 'game_action.dart';
import 'game_condition.dart';

/// One option a player can pick when a [GameCard] presents a decision. If a
/// card has no choices, its own `actions` run automatically instead.
///
/// [conditions] mirrors `AdventureChoice.conditions` — same [GameCondition]
/// system, same rule (every condition must hold for the option to appear).
/// This is what lets an item "open a new variant" of an ordinary card (a
/// ward amulet offering an escape option a curse card wouldn't otherwise
/// have), not just inside a multi-node adventure. `GameController` filters
/// a drawn card's choices down to the eligible ones before it ever reaches
/// the UI, the same way `AdventureEngine` does for a node's choices.
final class CardChoice {
  final String label;

  /// What the table is told happened once this option was taken — the other
  /// half of the sentence [label] starts. [label] is what a player *decides*
  /// to do; [outcome] is what comes of it.
  ///
  /// Null on most choices, and deliberately so: the field is meant to be
  /// filled in gradually, and a mandatory extra screen after every pick
  /// would cost more than the handful of empty ones it saves. A choice
  /// without it resolves exactly as it always has — the dialog closes and
  /// the effects speak for themselves.
  final String? outcome;

  final List<GameCondition> conditions;
  final List<GameAction> actions;

  const CardChoice({
    required this.label,
    this.outcome,
    this.conditions = const [],
    this.actions = const [],
  });

  factory CardChoice.fromJson(Map<String, dynamic> json) => CardChoice(
    label: json['label'] as String,
    outcome: json['outcome'] as String?,
    conditions: GameCondition.listFromJson(
      json['conditions'] as List<dynamic>?,
    ),
    actions: GameAction.listFromJson(json['actions'] as List<dynamic>?),
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    if (outcome != null) 'outcome': outcome,
    'conditions': GameCondition.listToJson(conditions),
    'actions': GameAction.listToJson(actions),
  };
}
