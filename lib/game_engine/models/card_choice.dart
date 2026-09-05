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
  final List<GameCondition> conditions;
  final List<GameAction> actions;

  const CardChoice({
    required this.label,
    this.conditions = const [],
    this.actions = const [],
  });

  factory CardChoice.fromJson(Map<String, dynamic> json) => CardChoice(
    label: json['label'] as String,
    conditions: GameCondition.listFromJson(
      json['conditions'] as List<dynamic>?,
    ),
    actions: GameAction.listFromJson(json['actions'] as List<dynamic>?),
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'conditions': GameCondition.listToJson(conditions),
    'actions': GameAction.listToJson(actions),
  };
}
