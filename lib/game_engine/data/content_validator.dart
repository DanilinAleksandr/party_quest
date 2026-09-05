import '../../core/constants/game_constants.dart';
import '../logic/adventure_catalog.dart';
import '../logic/biome_catalog.dart';
import '../logic/effect_catalog.dart';
import '../logic/item_catalog.dart';
import '../logic/origin_catalog.dart';
import '../models/models.dart';

final class ContentValidationException implements Exception {
  final List<String> errors;

  const ContentValidationException(this.errors);

  @override
  String toString() =>
      'Content validation failed:\n${errors.map((e) => '  - $e').join('\n')}';
}

/// Cross-checks every id a card, item, effect, adventure, or biome
/// references against what was actually loaded, and flags structurally
/// invalid entries (duplicate card ids, non-positive weights, adventure
/// nodes/destinations that don't exist).
///
/// This exists because the failure mode without it is much worse than a
/// startup error: a typo'd `itemId` on one rare, low-weight card — or a
/// broken node reference three branches deep into a legendary adventure —
/// would sit unnoticed until that exact path is taken, possibly months
/// after release, in the middle of someone's game, as a crash `byId` has no
/// graceful way to recover from. Run once at startup, every broken
/// reference in a thousand-card, hundred-adventure pack is caught before a
/// single player sees it.
final class ContentValidator {
  const ContentValidator();

  List<String> validate({
    required List<GameCard> cards,
    required ItemCatalog itemCatalog,
    required EffectCatalog effectCatalog,
    required AdventureCatalog adventureCatalog,
    required BiomeCatalog biomeCatalog,
    required OriginCatalog originCatalog,
  }) {
    final errors = <String>[];
    final seenCardIds = <String>{};

    if (!biomeCatalog.contains(GameConstants.startingBiomeId)) {
      errors.add(
        'GameConstants.startingBiomeId "${GameConstants.startingBiomeId}" has no matching biome — every match would '
        'start in a biome that does not exist.',
      );
    }

    for (final card in cards) {
      if (!seenCardIds.add(card.id)) {
        errors.add('Duplicate card id: "${card.id}".');
      }
      if (card.weight <= 0) {
        errors.add(
          'Card "${card.id}" has a non-positive weight (${card.weight}).',
        );
      }

      final source = 'card "${card.id}"';
      _validateActions(
        card.actions,
        source,
        itemCatalog,
        effectCatalog,
        adventureCatalog,
        biomeCatalog,
        originCatalog,
        errors,
      );
      var hasUnconditionedChoice = false;
      for (final choice in card.choices) {
        final choiceSource = '$source choice "${choice.label}"';
        if (choice.conditions.isEmpty) hasUnconditionedChoice = true;
        _validateActions(
          choice.actions,
          choiceSource,
          itemCatalog,
          effectCatalog,
          adventureCatalog,
          biomeCatalog,
          originCatalog,
          errors,
        );
        for (final condition in choice.conditions) {
          _validateCondition(
            condition,
            choiceSource,
            itemCatalog,
            effectCatalog,
            adventureCatalog,
            biomeCatalog,
            originCatalog,
            errors,
          );
        }
      }
      if (card.hasChoices && !hasUnconditionedChoice) {
        errors.add(
          '$source has choices but none of them is unconditioned — if every choice\'s conditions ever fail at '
          'once, the player would see a dialog with no buttons.',
        );
      }
      for (final condition in card.conditions) {
        _validateCondition(
          condition,
          source,
          itemCatalog,
          effectCatalog,
          adventureCatalog,
          biomeCatalog,
          originCatalog,
          errors,
        );
      }
      if (card.participant case HasItemParticipant(itemId: final itemId)) {
        _requireItem(itemId, source, itemCatalog, errors);
      }
      if (card.participant case HasOriginParticipant(originId: final originId)) {
        _requireOrigin(originId, source, originCatalog, errors);
      }
    }

    for (final item in itemCatalog.all) {
      _validateActions(
        item.useActions,
        'item "${item.id}"',
        itemCatalog,
        effectCatalog,
        adventureCatalog,
        biomeCatalog,
        originCatalog,
        errors,
      );
    }

    for (final effect in effectCatalog.all) {
      for (final actions in effect.reactions.values) {
        _validateActions(
          actions,
          'effect "${effect.id}"',
          itemCatalog,
          effectCatalog,
          adventureCatalog,
          biomeCatalog,
          originCatalog,
          errors,
        );
      }
    }

    for (final adventure in adventureCatalog.all) {
      _validateAdventure(
        adventure,
        itemCatalog,
        effectCatalog,
        adventureCatalog,
        biomeCatalog,
        originCatalog,
        errors,
      );
    }

    return errors;
  }

  void _validateAdventure(
    Adventure adventure,
    ItemCatalog itemCatalog,
    EffectCatalog effectCatalog,
    AdventureCatalog adventureCatalog,
    BiomeCatalog biomeCatalog,
    OriginCatalog originCatalog,
    List<String> errors,
  ) {
    final source = 'adventure "${adventure.id}"';

    if (!adventure.nodes.containsKey(adventure.entryNodeId)) {
      errors.add(
        '$source has entryNodeId "${adventure.entryNodeId}" which does not exist.',
      );
    }

    _validateNoAutoTransitionCycles(adventure, errors);

    for (final node in adventure.nodes.values) {
      final nodeSource = '$source node "${node.id}"';
      _validateActions(
        node.onEnterActions,
        nodeSource,
        itemCatalog,
        effectCatalog,
        adventureCatalog,
        biomeCatalog,
        originCatalog,
        errors,
      );

      if (node.autoTransition != null) {
        _validateDestination(
          node.autoTransition!,
          adventure,
          nodeSource,
          errors,
        );
      }

      for (final choice in node.choices) {
        final choiceSource = '$nodeSource choice "${choice.label}"';
        for (final condition in choice.conditions) {
          _validateCondition(
            condition,
            choiceSource,
            itemCatalog,
            effectCatalog,
            adventureCatalog,
            biomeCatalog,
            originCatalog,
            errors,
          );
        }
        if (choice.successChance != null &&
            (choice.successChance! < 0 || choice.successChance! > 1)) {
          errors.add(
            '$choiceSource has an out-of-range successChance (${choice.successChance}); must be 0–1.',
          );
        }
        _validateTransition(
          choice.onSuccess,
          adventure,
          '$choiceSource (success)',
          itemCatalog,
          effectCatalog,
          adventureCatalog,
          biomeCatalog,
          originCatalog,
          errors,
        );
        if (choice.onFailure != null) {
          _validateTransition(
            choice.onFailure!,
            adventure,
            '$choiceSource (failure)',
            itemCatalog,
            effectCatalog,
            adventureCatalog,
            biomeCatalog,
            originCatalog,
            errors,
          );
        }
      }
    }
  }

  /// A node with choices always stops for player input, which breaks any
  /// cycle running through it — so the only way an adventure can loop
  /// forever with no chance for the player to intervene is a cycle made
  /// entirely of `autoTransition`-only nodes (no choices). `AdventureEngine`
  /// walks that chain recursively with no depth limit, so such a cycle
  /// would crash with a stack overflow the first time a player reached it,
  /// rather than erroring cleanly — exactly the kind of mistake this
  /// validator exists to catch before it ships.
  void _validateNoAutoTransitionCycles(
    Adventure adventure,
    List<String> errors,
  ) {
    final autoOnlyNodeIds = adventure.nodes.values
        .where((n) => !n.hasChoices && n.autoTransition != null)
        .map((n) => n.id)
        .toSet();

    Iterable<String> nextAutoOnlyIds(String nodeId) {
      final destination = adventure.nodes[nodeId]?.autoTransition;
      return switch (destination) {
        GoToNode d => [d.nodeId],
        RandomNode d => d.options.map((o) => o.nodeId),
        EndAdventure() || null => const [],
      };
    }

    final visited = <String>{};
    final onStack = <String>{};

    bool hasCycleFrom(String nodeId) {
      if (!autoOnlyNodeIds.contains(nodeId)) return false;
      if (onStack.contains(nodeId)) return true;
      if (!visited.add(nodeId)) return false;

      onStack.add(nodeId);
      final cycle = nextAutoOnlyIds(nodeId).any(hasCycleFrom);
      onStack.remove(nodeId);
      return cycle;
    }

    for (final nodeId in autoOnlyNodeIds) {
      if (hasCycleFrom(nodeId)) {
        errors.add(
          'Adventure "${adventure.id}" has a cycle of auto-transition-only nodes reachable from "$nodeId" — '
          'with no player choice anywhere in the loop, this recurses forever instead of ending.',
        );
        break;
      }
    }
  }

  void _validateTransition(
    NodeTransition transition,
    Adventure adventure,
    String source,
    ItemCatalog itemCatalog,
    EffectCatalog effectCatalog,
    AdventureCatalog adventureCatalog,
    BiomeCatalog biomeCatalog,
    OriginCatalog originCatalog,
    List<String> errors,
  ) {
    _validateActions(
      transition.actions,
      source,
      itemCatalog,
      effectCatalog,
      adventureCatalog,
      biomeCatalog,
      originCatalog,
      errors,
    );
    _validateDestination(transition.to, adventure, source, errors);
  }

  void _validateDestination(
    NodeDestination destination,
    Adventure adventure,
    String source,
    List<String> errors,
  ) {
    switch (destination) {
      case GoToNode d:
        if (!adventure.nodes.containsKey(d.nodeId)) {
          errors.add(
            '$source points to node "${d.nodeId}" which does not exist in adventure "${adventure.id}".',
          );
        }
      case RandomNode d:
        if (d.options.isEmpty) {
          errors.add('$source has a randomNode destination with no options.');
        }
        for (final option in d.options) {
          if (option.weight <= 0) {
            errors.add(
              '$source random option "${option.nodeId}" has a non-positive weight (${option.weight}).',
            );
          }
          if (!adventure.nodes.containsKey(option.nodeId)) {
            errors.add(
              '$source points to node "${option.nodeId}" which does not exist in adventure "${adventure.id}".',
            );
          }
        }
      case EndAdventure _:
        break;
    }
  }

  void _validateActions(
    List<GameAction> actions,
    String source,
    ItemCatalog itemCatalog,
    EffectCatalog effectCatalog,
    AdventureCatalog adventureCatalog,
    BiomeCatalog biomeCatalog,
    OriginCatalog originCatalog,
    List<String> errors,
  ) {
    for (final action in actions) {
      switch (action) {
        case GiveItemAction a:
          _requireItem(a.itemId, source, itemCatalog, errors);
        case TakeItemAction a:
          _requireItem(a.itemId, source, itemCatalog, errors);
        case ApplyEffectAction a:
          _requireEffect(a.effectId, source, effectCatalog, errors);
        case RemoveEffectAction a:
          _requireEffect(a.effectId, source, effectCatalog, errors);
        case ModifyStatAction _:
          break;
        case StartDuelAction a:
          _validateActions(
            a.winnerActions,
            '$source (duel winner)',
            itemCatalog,
            effectCatalog,
            adventureCatalog,
            biomeCatalog,
            originCatalog,
            errors,
          );
          _validateActions(
            a.loserActions,
            '$source (duel loser)',
            itemCatalog,
            effectCatalog,
            adventureCatalog,
            biomeCatalog,
            originCatalog,
            errors,
          );
        case SetWorldFlagAction _:
        case ModifyGlobalModifierAction _:
          break;
        case StartAdventureAction a:
          if (!adventureCatalog.contains(a.adventureId)) {
            errors.add(
              '$source references unknown adventure id "${a.adventureId}".',
            );
          }
        case SetBiomeAction a:
          _requireBiome(a.biomeId, source, biomeCatalog, errors);
        case SetPhaseAction _:
        case SetLeaderAction _:
          break;
        case RevealOriginAction a:
          _requireOrigin(a.originId, source, originCatalog, errors);
        case AddChronicleEntryAction _:
        case SetWeatherAction _:
          break;
      }
    }
  }

  void _validateCondition(
    GameCondition condition,
    String source,
    ItemCatalog itemCatalog,
    EffectCatalog effectCatalog,
    AdventureCatalog adventureCatalog,
    BiomeCatalog biomeCatalog,
    OriginCatalog originCatalog,
    List<String> errors,
  ) {
    switch (condition) {
      case CurrentPlayerHasItemCondition c:
        _requireItem(c.itemId, source, itemCatalog, errors);
      case CurrentPlayerMissingItemCondition c:
        _requireItem(c.itemId, source, itemCatalog, errors);
      case PartyHasItemCondition c:
        _requireItem(c.itemId, source, itemCatalog, errors);
      case PartyMissingItemCondition c:
        _requireItem(c.itemId, source, itemCatalog, errors);
      case AnyPlayerHasItemCondition c:
        _requireItem(c.itemId, source, itemCatalog, errors);
      case CurrentPlayerHasEffectCondition c:
        _requireEffect(c.effectId, source, effectCatalog, errors);
      case CurrentPlayerMissingEffectCondition c:
        _requireEffect(c.effectId, source, effectCatalog, errors);
      case AnyPlayerHasEffectCondition c:
        _requireEffect(c.effectId, source, effectCatalog, errors);
      case CurrentPlayerHasOriginCondition c:
        _requireOrigin(c.originId, source, originCatalog, errors);
      case CurrentPlayerLacksOriginCondition c:
        _requireOrigin(c.originId, source, originCatalog, errors);
      case AnyPlayerHasOriginCondition c:
        _requireOrigin(c.originId, source, originCatalog, errors);
      case AdventureCompletedCondition c:
        if (!adventureCatalog.contains(c.adventureId)) {
          errors.add(
            '$source references unknown adventure id "${c.adventureId}".',
          );
        }
      case AdventureNotCompletedCondition c:
        if (!adventureCatalog.contains(c.adventureId)) {
          errors.add(
            '$source references unknown adventure id "${c.adventureId}".',
          );
        }
      case InBiomeCondition c:
        _requireBiome(c.biomeId, source, biomeCatalog, errors);
      case NotInBiomeCondition c:
        _requireBiome(c.biomeId, source, biomeCatalog, errors);
      case MinimumPlayersCondition _:
      case MaximumPlayersCondition _:
      case MinimumStepCondition _:
      case MaximumStepCondition _:
      case MinimumTurnsInBiomeCondition _:
      case MinimumTurnsInTavernCondition _:
      case MinimumStepsSinceFlagCondition _:
      case AnyPlayerMissingOriginCondition _:
      case CurrentPlayerOriginUnknownCondition _:
      case CurrentPlayerStatAtLeastCondition _:
      case AnyPlayerStatAtLeastCondition _:
      case LeaderIsSetCondition _:
      case LeaderIsUnsetCondition _:
      case GameModeCondition _:
      case InPhaseCondition _:
      case WorldFlagSetCondition _:
      case WorldFlagUnsetCondition _:
      case GlobalModifierAtLeastCondition _:
      case InWeatherCondition _:
      case NotInWeatherCondition _:
      case MinimumTurnsInWeatherCondition _:
      case InSeasonCondition _:
      case NotInSeasonCondition _:
        break;
    }
  }

  void _requireItem(
    String id,
    String source,
    ItemCatalog itemCatalog,
    List<String> errors,
  ) {
    if (!itemCatalog.contains(id)) {
      errors.add('$source references unknown item id "$id".');
    }
  }

  void _requireEffect(
    String id,
    String source,
    EffectCatalog effectCatalog,
    List<String> errors,
  ) {
    if (!effectCatalog.contains(id)) {
      errors.add('$source references unknown effect id "$id".');
    }
  }

  void _requireBiome(
    String id,
    String source,
    BiomeCatalog biomeCatalog,
    List<String> errors,
  ) {
    if (!biomeCatalog.contains(id)) {
      errors.add('$source references unknown biome id "$id".');
    }
  }

  void _requireOrigin(
    String id,
    String source,
    OriginCatalog originCatalog,
    List<String> errors,
  ) {
    if (!originCatalog.contains(id)) {
      errors.add('$source references unknown origin id "$id".');
    }
  }
}
