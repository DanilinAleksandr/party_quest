/// One weighted option inside a [RandomNode] — e.g. the witch's hut example
/// from the design doc: entering could lead to "witch home" (weight 20),
/// "empty house" (30), "found a chest" (15), "found a potion" (15), or "a
/// trap" (20), picked the same weighted-random way cards are drawn.
final class WeightedNodeRef {
  final String nodeId;
  final int weight;

  const WeightedNodeRef({required this.nodeId, required this.weight});

  factory WeightedNodeRef.fromJson(Map<String, dynamic> json) =>
      WeightedNodeRef(
        nodeId: json['nodeId'] as String,
        weight: json['weight'] as int,
      );

  Map<String, dynamic> toJson() => {'nodeId': nodeId, 'weight': weight};
}

/// Where an [AdventureNode] or [AdventureChoice] leads next.
///
/// This is the whole "цепочка событий" (event chain) primitive: a node
/// doesn't need bespoke code to lead somewhere else, loop, branch randomly,
/// or end the story — it just names one of these three destinations. A
/// "small adventure" and a "unique legendary scenario" differ only in how
/// many nodes are wired together this way, never in what code runs them.
sealed class NodeDestination {
  const NodeDestination();

  factory NodeDestination.fromJson(Map<String, dynamic> json) {
    final kind = json['destination'] as String;
    return switch (kind) {
      'goToNode' => GoToNode(nodeId: json['nodeId'] as String),
      'randomNode' => RandomNode(
        options: (json['options'] as List<dynamic>)
            .map((e) => WeightedNodeRef.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      ),
      'endAdventure' => const EndAdventure(),
      _ => throw FormatException('Unknown node destination kind: $kind'),
    };
  }

  Map<String, dynamic> toJson();
}

/// Always moves to the same, specific next node.
final class GoToNode extends NodeDestination {
  final String nodeId;

  const GoToNode({required this.nodeId});

  @override
  Map<String, dynamic> toJson() => {
    'destination': 'goToNode',
    'nodeId': nodeId,
  };
}

/// Moves to one of several nodes, weighted-random — the branching-without-
/// a-player-choice mechanic ("Войти → случайно: ведьма дома / дом пуст /
/// ...").
final class RandomNode extends NodeDestination {
  final List<WeightedNodeRef> options;

  const RandomNode({required this.options});

  @override
  Map<String, dynamic> toJson() => {
    'destination': 'randomNode',
    'options': options.map((o) => o.toJson()).toList(growable: false),
  };
}

/// Ends the adventure, returning control to the normal turn flow.
final class EndAdventure extends NodeDestination {
  const EndAdventure();

  @override
  Map<String, dynamic> toJson() => {'destination': 'endAdventure'};
}
