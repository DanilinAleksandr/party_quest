import '../context/game_context.dart';
import '../models/models.dart';

/// The outcome of resolving a [GameCard]'s [EventParticipant]: either the
/// context now has the right player(s) set as `currentPlayer`/
/// `secondaryPlayer`, or the table needs to pick one by hand first.
sealed class ParticipantResolution {
  const ParticipantResolution();
}

final class ResolvedParticipant extends ParticipantResolution {
  final GameContext context;

  const ResolvedParticipant(this.context);
}

final class NeedsManualPick extends ParticipantResolution {
  const NeedsManualPick();
}

/// Turns a [GameCard]'s [EventParticipant] into a concrete player (or two),
/// by setting `GameState.currentPlayerIndex`/`secondaryPlayerIndex` — the
/// same mechanism `ActionExecutor.executeAsPlayer` already uses to make a
/// duel's winner/loser stand in for "the current player" while their
/// actions run. Nothing downstream (`ActionTarget`, `GameCondition`) needs
/// to know a selection even happened.
final class ParticipantResolver {
  const ParticipantResolver();

  ParticipantResolution resolve(
    EventParticipant participant,
    GameContext context,
  ) {
    return switch (participant) {
      RandomPlayerParticipant() => ResolvedParticipant(_pickRandom(context)),
      TwoRandomPlayersParticipant() => ResolvedParticipant(
        _pickTwoRandom(context),
      ),
      WholeGroupParticipant() => ResolvedParticipant(_setPrimary(context, 0)),
      MaxStatParticipant(stat: final stat) => ResolvedParticipant(
        _pickByStat(context, stat, highest: true),
      ),
      MinStatParticipant(stat: final stat) => ResolvedParticipant(
        _pickByStat(context, stat, highest: false),
      ),
      HasItemParticipant(itemId: final itemId) => ResolvedParticipant(
        _pickHolder(context, itemId),
      ),
      HasOriginParticipant(originId: final originId) => ResolvedParticipant(
        _pickByOrigin(context, originId),
      ),
      UnknownOriginParticipant() => ResolvedParticipant(
        _pickUnknownOrigin(context),
      ),
      ChosenParticipant() => const NeedsManualPick(),
      PreviousParticipant() => ResolvedParticipant(
        _pickByRememberedId(context, context.state.worldState.previousParticipantId),
      ),
      PreviousWinner() => ResolvedParticipant(
        _pickByRememberedId(context, context.state.worldState.previousWinnerId),
      ),
      PreviousLoser() => ResolvedParticipant(
        _pickByRememberedId(context, context.state.worldState.previousLoserId),
      ),
      LeaderParticipant() => ResolvedParticipant(
        _pickByRememberedId(context, context.state.worldState.leaderId),
      ),
    };
  }

  /// Applies a table-picked player id for a [ChosenParticipant] event —
  /// called by `GameController.resolveParticipant` once the group has
  /// decided. A no-op (returns [context] unchanged) if the id doesn't match
  /// any player, which can't happen from the UI but keeps this safe to call
  /// directly in tests.
  GameContext resolveChosen(String playerId, GameContext context) {
    final index = context.players.indexWhere((p) => p.id == playerId);
    if (index == -1) return context;
    return _setPrimary(context, index);
  }

  GameContext _pickRandom(GameContext context) =>
      _setPrimary(context, context.random.nextInt(context.players.length));

  GameContext _pickTwoRandom(GameContext context) {
    final players = context.players;
    if (players.length < 2) return _setPrimary(context, 0);

    final firstIndex = context.random.nextInt(players.length);
    var secondIndex = context.random.nextInt(players.length - 1);
    if (secondIndex >= firstIndex) secondIndex += 1;

    return context.withState(
      context.state.copyWith(
        currentPlayerIndex: firstIndex,
        secondaryPlayerIndex: secondIndex,
      ),
    );
  }

  GameContext _pickByStat(
    GameContext context,
    StatType stat, {
    required bool highest,
  }) {
    final players = context.players;
    final values = players.map((p) => p.stats.valueOf(stat)).toList();
    final best = highest
        ? values.reduce((a, b) => a > b ? a : b)
        : values.reduce((a, b) => a < b ? a : b);
    final candidates = [
      for (var i = 0; i < players.length; i++)
        if (values[i] == best) i,
    ];
    return _setPrimary(context, candidates[context.random.nextInt(candidates.length)]);
  }

  /// Resolves a remembered player id (previous participant/winner/loser, or
  /// the current leader) — falling back to a random player when there's no
  /// history yet (`rememberedId` is null) or the remembered player somehow
  /// isn't in this match, the same "never blocks a draw" precedent
  /// [_pickHolder] sets for `HasItemParticipant`.
  GameContext _pickByRememberedId(GameContext context, String? rememberedId) {
    if (rememberedId == null) return _pickRandom(context);
    final index = context.players.indexWhere((p) => p.id == rememberedId);
    if (index == -1) return _pickRandom(context);
    return _setPrimary(context, index);
  }

  GameContext _pickHolder(GameContext context, String itemId) {
    final players = context.players;
    final holders = [
      for (var i = 0; i < players.length; i++)
        if (players[i].inventory.any((item) => item.id == itemId)) i,
    ];
    final pool = holders.isEmpty
        ? [for (var i = 0; i < players.length; i++) i]
        : holders;
    return _setPrimary(context, pool[context.random.nextInt(pool.length)]);
  }

  GameContext _pickByOrigin(GameContext context, String originId) {
    final players = context.players;
    final matching = [
      for (var i = 0; i < players.length; i++)
        if (players[i].originId == originId) i,
    ];
    final pool = matching.isEmpty
        ? [for (var i = 0; i < players.length; i++) i]
        : matching;
    return _setPrimary(context, pool[context.random.nextInt(pool.length)]);
  }

  GameContext _pickUnknownOrigin(GameContext context) {
    final players = context.players;
    final unrevealed = [
      for (var i = 0; i < players.length; i++)
        if (players[i].originId == null) i,
    ];
    final pool = unrevealed.isEmpty
        ? [for (var i = 0; i < players.length; i++) i]
        : unrevealed;
    return _setPrimary(context, pool[context.random.nextInt(pool.length)]);
  }

  GameContext _setPrimary(GameContext context, int index) => context.withState(
    context.state.copyWith(
      currentPlayerIndex: index,
      clearSecondaryPlayer: true,
    ),
  );
}
