import '../context/game_context.dart';
import '../models/models.dart';
import 'adventure_engine.dart';

/// Interprets [GameAction]s against a [GameContext], producing a new
/// context. Every piece of data an action needs — the item/effect catalogs,
/// randomness, the current players — comes off [GameContext]; nothing here
/// is looked up from a constructor-injected dependency of its own, so
/// adding a new catalog or service to the engine never means changing
/// `ActionExecutor`'s constructor.
///
/// The `switch` in [execute] is exhaustive over the sealed [GameAction]
/// hierarchy: adding a new action subtype without adding a case here is a
/// compile error, not a silent no-op at runtime.
final class ActionExecutor {
  const ActionExecutor();

  GameContext executeAll(List<GameAction> actions, GameContext context) {
    var next = context;
    for (final action in actions) {
      next = execute(action, next);
    }
    return next;
  }

  GameContext execute(GameAction action, GameContext context) {
    return switch (action) {
      GiveItemAction a => _giveItem(a, context),
      TakeItemAction a => _takeItem(a, context),
      ApplyEffectAction a => _applyEffect(a, context),
      RemoveEffectAction a => _removeEffect(a, context),
      ModifyStatAction a => _modifyStat(a, context),
      StartDuelAction a => _startDuel(a, context),
      SetWorldFlagAction a => _setWorldFlag(a, context),
      ModifyGlobalModifierAction a => _modifyGlobalModifier(a, context),
      StartAdventureAction a => _startAdventure(a, context),
      SetBiomeAction a => _setBiome(a, context),
      SetPhaseAction a => _setPhase(a, context),
      SetLeaderAction a => _setLeader(a, context),
      RevealOriginAction a => _revealOrigin(a, context),
      AddChronicleEntryAction a => _addChronicleEntry(a, context),
      SetWeatherAction a => _setWeather(a, context),
    };
  }

  /// Runs [actions] with [playerId] standing in for `ActionTarget
  /// .currentPlayer`, without changing whose actual game turn it is
  /// afterwards. This is how a duel's winner/loser action lists, and an
  /// effect's reaction to a game event, resolve "the player this applies
  /// to" through the same targeting rules as every other action, instead of
  /// each needing its own bespoke target plumbing.
  GameContext executeAsPlayer(
    List<GameAction> actions,
    String playerId,
    GameContext context,
  ) {
    final originalIndex = context.state.currentPlayerIndex;
    final asPlayerIndex = context.players.indexWhere((p) => p.id == playerId);
    if (asPlayerIndex == -1) return context;

    var next = context.withState(
      context.state.copyWith(currentPlayerIndex: asPlayerIndex),
    );
    next = executeAll(actions, next);
    return next.withState(
      next.state.copyWith(currentPlayerIndex: originalIndex),
    );
  }

  List<Player> _resolveTargets(ActionTarget target, GameContext context) {
    switch (target) {
      case ActionTarget.currentPlayer:
        return [context.currentPlayer];
      case ActionTarget.allPlayers:
        return context.players;
      case ActionTarget.allOtherPlayers:
        return context.players
            .where((p) => p.id != context.currentPlayer.id)
            .toList();
      case ActionTarget.randomOtherPlayer:
        final others = context.players
            .where((p) => p.id != context.currentPlayer.id)
            .toList();
        if (others.isEmpty) return [context.currentPlayer];
        return [others[context.random.nextInt(others.length)]];
      case ActionTarget.secondaryPlayer:
        return [context.state.secondaryPlayer ?? context.currentPlayer];
      case ActionTarget.leftOfCurrentPlayer:
        return [_neighborOfCurrentPlayer(context, -1)];
      case ActionTarget.rightOfCurrentPlayer:
        return [_neighborOfCurrentPlayer(context, 1)];
    }
  }

  Player _neighborOfCurrentPlayer(GameContext context, int offset) {
    final players = context.players;
    final index =
        (context.state.currentPlayerIndex + offset) % players.length;
    return players[(index + players.length) % players.length];
  }

  /// Applies [update] to every player in [targets], then — once the new
  /// context exists — calls [onUpdated] for each of them so callers can
  /// emit an event carrying the *post-update* player and context.
  GameContext _updateTargets(
    GameContext context,
    List<Player> targets,
    Player Function(Player player) update, {
    void Function(Player updated, GameContext next)? onUpdated,
  }) {
    final targetIds = targets.map((p) => p.id).toSet();
    final updatedPlayers = context.players
        .map((p) => targetIds.contains(p.id) ? update(p) : p)
        .toList();
    final next = context.withState(
      context.state.copyWith(players: updatedPlayers),
    );

    if (onUpdated != null) {
      for (final player in updatedPlayers) {
        if (targetIds.contains(player.id)) onUpdated(player, next);
      }
    }
    return next;
  }

  /// A [GiveItemAction]/[TakeItemAction]'s `target` only matters for
  /// personal items — a shared item has exactly one destination
  /// (`GameState.partyInventory`), the same for every card, so the item's
  /// own [ItemOwnership] decides where it goes rather than the action
  /// needing a separate "give it to the party" target/action type.
  GameContext _giveItem(GiveItemAction action, GameContext context) {
    final item = context.itemCatalog.byId(action.itemId);
    if (item.ownership == ItemOwnership.shared) {
      final state = context.state;
      return context.withState(
        state.copyWith(partyInventory: [...state.partyInventory, item]),
      );
    }

    final targets = _resolveTargets(action.target, context);
    return _updateTargets(
      context,
      targets,
      (p) => p.copyWith(inventory: [...p.inventory, item]),
      onUpdated: (updated, next) =>
          next.eventBus.emit(OnItemReceived(player: updated, item: item), next),
    );
  }

  GameContext _takeItem(TakeItemAction action, GameContext context) {
    final item = context.itemCatalog.byId(action.itemId);
    if (item.ownership == ItemOwnership.shared) {
      final inventory = [...context.state.partyInventory];
      final index = inventory.indexWhere((i) => i.id == action.itemId);
      if (index != -1) inventory.removeAt(index);
      return context.withState(
        context.state.copyWith(partyInventory: inventory),
      );
    }

    final targets = _resolveTargets(action.target, context);
    return _updateTargets(context, targets, (p) {
      final inventory = [...p.inventory];
      final index = inventory.indexWhere((i) => i.id == action.itemId);
      if (index != -1) inventory.removeAt(index);
      return p.copyWith(inventory: inventory);
    });
  }

  GameContext _applyEffect(ApplyEffectAction action, GameContext context) {
    final template = context.effectCatalog.byId(action.effectId);
    final targets = _resolveTargets(action.target, context);
    var next = context;

    for (final target in targets) {
      final player = next.players.firstWhere((p) => p.id == target.id);
      final wardCandidates = template.polarity == EffectPolarity.negative
          ? player.activeEffects.where((e) => e.blocksNextNegativeEffect)
          : const <GameEffect>[];
      final ward = wardCandidates.isEmpty ? null : wardCandidates.first;

      if (ward != null) {
        // The curse is absorbed instead of landing — the ward is consumed.
        final remaining = player.activeEffects
            .where((e) => e.id != ward.id)
            .toList();
        final updated = player.copyWith(activeEffects: remaining);
        next = _updateTargets(next, [target], (_) => updated);
        next.eventBus.emit(
          OnEffectExpired(player: updated, effect: ward),
          next,
        );
        continue;
      }

      // Re-applying an effect the player already has refreshes its timer
      // instead of stacking a duplicate.
      final effects =
          player.activeEffects.where((e) => e.id != template.id).toList()
            ..add(template.instantiate());
      final updated = player.copyWith(activeEffects: effects);
      next = _updateTargets(next, [target], (_) => updated);
      final applied = updated.activeEffects.firstWhere(
        (e) => e.id == template.id,
      );
      next.eventBus.emit(
        OnEffectApplied(player: updated, effect: applied),
        next,
      );
    }

    return next;
  }

  GameContext _removeEffect(RemoveEffectAction action, GameContext context) {
    final targets = _resolveTargets(action.target, context);
    return _updateTargets(context, targets, (p) {
      final effects = p.activeEffects
          .where((e) => e.id != action.effectId)
          .toList();
      return p.copyWith(activeEffects: effects);
    });
  }

  GameContext _modifyStat(ModifyStatAction action, GameContext context) {
    final targets = _resolveTargets(action.target, context);
    return _updateTargets(
      context,
      targets,
      (p) => p.copyWith(stats: p.stats.modify(action.stat, action.amount)),
    );
  }

  /// Also records [WorldState.previousWinnerId]/[previousLoserId] once the
  /// duel resolves — the mechanism behind `PreviousWinner`/`PreviousLoser`
  /// event participants ("победителя замечает торговец").
  GameContext _startDuel(StartDuelAction action, GameContext context) {
    final opponents = context.players
        .where((p) => p.id != context.currentPlayer.id)
        .toList();
    if (opponents.isEmpty) return context;

    final opponent = opponents[context.random.nextInt(opponents.length)];
    final currentPlayerWins = context.random.nextBool();
    final winner = currentPlayerWins ? context.currentPlayer : opponent;
    final loser = currentPlayerWins ? opponent : context.currentPlayer;

    var next = executeAsPlayer(action.winnerActions, winner.id, context);
    next = executeAsPlayer(action.loserActions, loser.id, next);

    final worldState = next.state.worldState.copyWith(
      previousWinnerId: winner.id,
      previousLoserId: loser.id,
    );
    return next.withState(next.state.copyWith(worldState: worldState));
  }

  /// Also stamps `WorldState.flagSetAtStep` when [action] sets the flag
  /// true — the mechanism behind `MinimumStepsSinceFlagCondition` ("через
  /// несколько ходов"). A card doesn't need to know or care whether
  /// anything will ever check the delay; setting a flag is free to be as
  /// ordinary as any other action.
  GameContext _setWorldFlag(SetWorldFlagAction action, GameContext context) {
    var worldState = context.state.worldState.withFlag(
      action.flag,
      action.value,
    );
    if (action.value) {
      worldState = worldState.copyWith(
        flagSetAtStep: {
          ...worldState.flagSetAtStep,
          action.flag: context.state.partySteps,
        },
      );
    }
    return context.withState(context.state.copyWith(worldState: worldState));
  }

  GameContext _modifyGlobalModifier(
    ModifyGlobalModifierAction action,
    GameContext context,
  ) {
    final worldState = context.state.worldState.withModifier(
      action.key,
      action.amount,
    );
    return context.withState(context.state.copyWith(worldState: worldState));
  }

  /// Delegates to a freshly-built [AdventureEngine] rather than holding one
  /// as a field: [AdventureEngine] needs an [ActionExecutor] to run node and
  /// choice actions, and this keeps that a one-way dependency (executor →
  /// engine → executor-instance-passed-in) instead of a circular
  /// constructor dependency between the two classes.
  GameContext _startAdventure(
    StartAdventureAction action,
    GameContext context,
  ) {
    final adventure = context.adventureCatalog.byId(action.adventureId);
    return AdventureEngine(this).enter(adventure, context);
  }

  /// Validating the id via the catalog (rather than blindly writing the
  /// string) means a typo'd `biomeId` fails loudly the moment this action
  /// runs, the same safety net [_giveItem]/[_applyEffect] already get from
  /// `ItemCatalog.byId`/`EffectCatalog.byId`.
  ///
  /// Also clears every `lean_<biomeId>` global modifier — the naming
  /// convention road-event cards use to nudge which biome comes next (see
  /// `GlobalModifierAtLeastCondition` on the biased transition cards in
  /// `biome_transitions.json`) — so a nudge only ever influences the very
  /// next transition, not ones much later in the game.
  GameContext _setBiome(SetBiomeAction action, GameContext context) {
    context.biomeCatalog.byId(action.biomeId);
    final modifiers = Map<String, int>.from(context.state.worldState.modifiers);
    for (final biome in context.biomeCatalog.all) {
      modifiers.remove('lean_${biome.id}');
    }
    final worldState = context.state.worldState.copyWith(
      currentBiomeId: action.biomeId,
      turnsInCurrentBiome: 0,
      modifiers: modifiers,
    );
    return context.withState(context.state.copyWith(worldState: worldState));
  }

  GameContext _setPhase(SetPhaseAction action, GameContext context) {
    return context.withState(context.state.copyWith(phase: action.phase));
  }

  GameContext _setLeader(SetLeaderAction action, GameContext context) {
    final targets = _resolveTargets(action.target, context);
    if (targets.isEmpty) return context;
    final worldState = context.state.worldState.copyWith(
      leaderId: targets.first.id,
    );
    return context.withState(context.state.copyWith(worldState: worldState));
  }

  GameContext _revealOrigin(RevealOriginAction action, GameContext context) {
    final origin = context.originCatalog.byId(action.originId);
    final targets = _resolveTargets(action.target, context);
    return _updateTargets(context, targets, (p) {
      if (p.originId != null) return p;
      var stats = p.stats;
      for (final entry in origin.statModifiers.entries) {
        stats = stats.modify(entry.key, entry.value);
      }
      return p.copyWith(originId: origin.id, stats: stats);
    });
  }

  GameContext _addChronicleEntry(
    AddChronicleEntryAction action,
    GameContext context,
  ) {
    final player = _resolveTargets(action.target, context).first;
    final text = action.text.replaceAll('{player}', player.name);
    return context.withState(
      context.state.copyWith(
        chronicle: [...context.state.chronicle, ChronicleEntry(text: text)],
      ),
    );
  }

  GameContext _setWeather(SetWeatherAction action, GameContext context) {
    final worldState = context.state.worldState.copyWith(
      currentWeather: action.weather,
      turnsInCurrentWeather: 0,
    );
    return context.withState(context.state.copyWith(worldState: worldState));
  }
}
