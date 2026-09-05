import 'adventure_choice.dart';
import 'game_action.dart';
import 'node_destination.dart';

/// One situation inside an [Adventure]: some text, optionally some actions
/// that just happen on arrival (no player input), and then either a set of
/// player [choices] or an [autoTransition] that moves on by itself
/// (including a weighted-random branch, for "случайные переходы").
///
/// A node with neither [choices] nor [autoTransition] is a dead end by
/// omission — `AdventureEngine` treats that as an implicit
/// [EndAdventure] rather than soft-locking the player, but a content author
/// should still normally set one explicitly.
final class AdventureNode {
  final String id;
  final String text;
  final List<GameAction> onEnterActions;
  final List<AdventureChoice> choices;
  final NodeDestination? autoTransition;

  const AdventureNode({
    required this.id,
    required this.text,
    this.onEnterActions = const [],
    this.choices = const [],
    this.autoTransition,
  });

  bool get hasChoices => choices.isNotEmpty;

  /// Used by `AdventureEngine` to cache, in `GameState`, the same node with
  /// only the choices the player is currently eligible to see — so the
  /// index the UI shows always lines up with the index `resolveChoice`
  /// receives.
  AdventureNode withChoices(List<AdventureChoice> choices) => AdventureNode(
    id: id,
    text: text,
    onEnterActions: onEnterActions,
    choices: choices,
    autoTransition: autoTransition,
  );

  factory AdventureNode.fromJson(Map<String, dynamic> json) => AdventureNode(
    id: json['id'] as String,
    text: json['text'] as String,
    onEnterActions: GameAction.listFromJson(
      json['onEnterActions'] as List<dynamic>?,
    ),
    choices: (json['choices'] as List<dynamic>? ?? const [])
        .map((e) => AdventureChoice.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    autoTransition: json['autoTransition'] == null
        ? null
        : NodeDestination.fromJson(
            json['autoTransition'] as Map<String, dynamic>,
          ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'onEnterActions': GameAction.listToJson(onEnterActions),
    'choices': choices.map((c) => c.toJson()).toList(growable: false),
    if (autoTransition != null) 'autoTransition': autoTransition!.toJson(),
  };
}
