import '../context/game_context.dart';
import '../models/models.dart';
import 'action_executor.dart';
import 'random_provider.dart';

/// Walks an [Adventure]'s node graph on the current player's behalf.
///
/// [enter] auto-cascades through nodes — running `onEnterActions`, following
/// `autoTransition`s (including weighted-random branches) — until it either
/// reaches a node with player-facing choices (where it stops and records
/// that in [GameState.pendingAdventureNode] for the UI) or reaches an
/// [EndAdventure]. [resolveChoice] continues the same cascade after the
/// player picks an option, rolling [AdventureChoice.successChance] if the
/// choice has one.
///
/// This is the entire "цепочка событий" mechanism: nothing here knows or
/// cares whether it's walking a one-node "you found a coin" or a
/// twelve-node legendary saga — both are the same graph traversal.
final class AdventureEngine {
  final ActionExecutor executor;

  const AdventureEngine(this.executor);

  GameContext enter(Adventure adventure, GameContext context) {
    return _advance(adventure, adventure.node(adventure.entryNodeId), context);
  }

  /// [presentedNode] must be the node the UI actually showed the player
  /// (i.e. `GameState.pendingAdventureNode`), since [choiceIndex] indexes
  /// into its already-filtered choice list.
  GameContext resolveChoice(
    Adventure adventure,
    AdventureNode presentedNode,
    int choiceIndex,
    GameContext context,
  ) {
    if (choiceIndex < 0 || choiceIndex >= presentedNode.choices.length) {
      return context;
    }

    final choice = presentedNode.choices[choiceIndex];
    final succeeded =
        choice.successChance == null ||
        context.random.nextDouble() < choice.successChance!;
    final transition = succeeded
        ? choice.onSuccess
        : (choice.onFailure ?? choice.onSuccess);

    final next = executor.executeAll(transition.actions, context);
    return _resolveDestination(adventure, transition.to, next);
  }

  GameContext _advance(
    Adventure adventure,
    AdventureNode node,
    GameContext context,
  ) {
    final next = executor.executeAll(node.onEnterActions, context);

    if (node.hasChoices) {
      final eligibleChoices = node.choices
          .where((choice) => _conditionsHold(choice.conditions, next))
          .toList();
      // No eligible choices would soft-lock the player at a dialog with no
      // buttons; treat it the same as an authored dead end.
      if (eligibleChoices.isEmpty) return _endAdventure(adventure, next);

      return next.withState(
        next.state.copyWith(
          activeAdventureId: adventure.id,
          pendingAdventureNode: node.withChoices(eligibleChoices),
        ),
      );
    }

    if (node.autoTransition != null) {
      return _resolveDestination(adventure, node.autoTransition!, next);
    }

    return _endAdventure(adventure, next);
  }

  GameContext _resolveDestination(
    Adventure adventure,
    NodeDestination destination,
    GameContext context,
  ) {
    return switch (destination) {
      GoToNode d => _advance(adventure, adventure.node(d.nodeId), context),
      RandomNode d => _advance(
        adventure,
        adventure.node(_pickWeightedNode(d.options, context.random)),
        context,
      ),
      EndAdventure _ => _endAdventure(adventure, context),
    };
  }

  bool _conditionsHold(List<GameCondition> conditions, GameContext context) =>
      conditions.every((condition) => condition.isSatisfied(context));

  String _pickWeightedNode(
    List<WeightedNodeRef> options,
    RandomProvider random,
  ) {
    final totalWeight = options.fold<int>(
      0,
      (sum, option) => sum + option.weight,
    );
    var roll = random.nextInt(totalWeight);
    for (final option in options) {
      if (roll < option.weight) return option.nodeId;
      roll -= option.weight;
    }
    return options.last.nodeId;
  }

  GameContext _endAdventure(Adventure adventure, GameContext context) {
    final worldState = context.state.worldState.withCompletedAdventure(
      adventure.id,
    );
    return context.withState(
      context.state.copyWith(
        worldState: worldState,
        clearActiveAdventure: true,
      ),
    );
  }
}
