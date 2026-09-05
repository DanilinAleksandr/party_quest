/// Who a [GameAction] applies to when a card, effect tick, or item use
/// resolves. Kept separate from the action itself so any action type can be
/// aimed at any target without duplicating targeting logic per action.
///
/// "Current player" no longer means "whose turn it is" — the party travels
/// together now. It means whichever player the current event's
/// `EventParticipant` selector resolved to (see `ParticipantResolver`),
/// scoped to just this one card's resolution.
enum ActionTarget {
  /// The player the current event's participant selector resolved to.
  currentPlayer,

  /// One random player other than the current player.
  randomOtherPlayer,

  /// Every player in the game, including the current player.
  allPlayers,

  /// Every player except the current player.
  allOtherPlayers,

  /// The second player picked by a `TwoRandomPlayersParticipant` selector —
  /// see `GameState.secondaryPlayerIndex`. Falls back to the current player
  /// if the event didn't resolve a second one.
  secondaryPlayer,

  /// The player seated to the left of the current player, wrapping around
  /// the table — for content like "игрок слева от выбранного".
  leftOfCurrentPlayer,

  /// The player seated to the right of the current player, wrapping around
  /// the table.
  rightOfCurrentPlayer;

  static ActionTarget fromJson(String value) =>
      ActionTarget.values.byName(value);

  String toJson() => name;
}
