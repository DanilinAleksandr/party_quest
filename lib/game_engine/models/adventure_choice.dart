import 'game_condition.dart';
import 'node_transition.dart';

/// One option a player can pick at an [AdventureNode].
///
/// [successChance] is what makes "иметь вероятность успеха" generic: a
/// choice with no [successChance] always takes [onSuccess]; one with a
/// chance rolls against it and takes [onFailure] instead on a miss. This is
/// how "sneak past the dragon" and "try to pick the lock" are expressed
/// without a bespoke skill-check system — they're both just a choice with a
/// probability and two possible transitions.
final class AdventureChoice {
  final String label;

  /// Every condition must hold for this choice to even be offered — reuses
  /// the same [GameCondition] system cards use, so "only show this option if
  /// the player already has a torch" needs no adventure-specific machinery.
  final List<GameCondition> conditions;

  final double? successChance;
  final NodeTransition onSuccess;

  /// Required in practice whenever [successChance] is set; if omitted on a
  /// choice that does have a chance, failure falls back to [onSuccess] so a
  /// content mistake degrades to "always succeeds" rather than crashing.
  final NodeTransition? onFailure;

  const AdventureChoice({
    required this.label,
    this.conditions = const [],
    this.successChance,
    required this.onSuccess,
    this.onFailure,
  });

  factory AdventureChoice.fromJson(Map<String, dynamic> json) =>
      AdventureChoice(
        label: json['label'] as String,
        conditions: GameCondition.listFromJson(
          json['conditions'] as List<dynamic>?,
        ),
        successChance: (json['successChance'] as num?)?.toDouble(),
        onSuccess: NodeTransition.fromJson(
          json['onSuccess'] as Map<String, dynamic>,
        ),
        onFailure: json['onFailure'] == null
            ? null
            : NodeTransition.fromJson(
                json['onFailure'] as Map<String, dynamic>,
              ),
      );

  Map<String, dynamic> toJson() => {
    'label': label,
    'conditions': GameCondition.listToJson(conditions),
    if (successChance != null) 'successChance': successChance,
    'onSuccess': onSuccess.toJson(),
    if (onFailure != null) 'onFailure': onFailure!.toJson(),
  };
}
