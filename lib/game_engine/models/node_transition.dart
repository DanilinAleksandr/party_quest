import 'game_action.dart';
import 'node_destination.dart';

/// What happens when a node is left via a specific route: run [actions]
/// (may be empty — "not every decision has to have an effect"), then move
/// [to] the resulting [NodeDestination].
final class NodeTransition {
  final List<GameAction> actions;
  final NodeDestination to;

  const NodeTransition({this.actions = const [], required this.to});

  factory NodeTransition.fromJson(Map<String, dynamic> json) => NodeTransition(
    actions: GameAction.listFromJson(json['actions'] as List<dynamic>?),
    to: NodeDestination.fromJson(json['to'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'actions': GameAction.listToJson(actions),
    'to': to.toJson(),
  };
}
