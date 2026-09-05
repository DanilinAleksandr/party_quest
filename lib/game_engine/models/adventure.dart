import '../unique_by_id.dart';
import 'adventure_node.dart';

/// A graph of [AdventureNode]s, fully describable as data — this is the
/// "приключение" the design doc asks for. It carries no rarity, weight, or
/// draw conditions of its own: those already exist on [GameCard], and an
/// adventure is entered via a card whose action is `StartAdventureAction`.
/// A witch's hut, a dragon's lair, and a tavern brawl are all just an
/// `Adventure` value with a different node graph — none of them are a
/// distinct Dart type.
final class Adventure {
  final String id;
  final String entryNodeId;
  final Map<String, AdventureNode> nodes;

  const Adventure({
    required this.id,
    required this.entryNodeId,
    required this.nodes,
  });

  AdventureNode node(String nodeId) {
    final found = nodes[nodeId];
    if (found == null) {
      throw StateError('Adventure "$id" has no node "$nodeId".');
    }
    return found;
  }

  factory Adventure.fromJson(Map<String, dynamic> json) {
    final nodeList = (json['nodes'] as List<dynamic>).map(
      (e) => AdventureNode.fromJson(e as Map<String, dynamic>),
    );
    return Adventure(
      id: json['id'] as String,
      entryNodeId: json['entryNodeId'] as String,
      nodes: uniqueById(
        nodeList,
        (n) => n.id,
        'adventure node (in "${json['id']}")',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'entryNodeId': entryNodeId,
    'nodes': nodes.values.map((n) => n.toJson()).toList(growable: false),
  };
}
