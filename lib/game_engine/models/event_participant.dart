import 'stat_type.dart';

/// Who a [GameCard]'s event is "about" — resolved once per party step by
/// `ParticipantResolver`, before the card is shown, into whichever player(s)
/// `ActionTarget.currentPlayer`/`.secondaryPlayer`/etc. then refer to for
/// that one card's actions.
///
/// The party no longer takes turns; every step is one event, and the event
/// itself decides who it involves — that's what this models. Most variants
/// resolve automatically (random pick, whoever has the highest strength,
/// whoever's holding a given item); [ChosenParticipant] is the one that
/// needs the table to pick by hand, and covers both "a volunteer steps
/// forward" and "the group chooses" — mechanically identical, the card's
/// own title/description carries the framing.
sealed class EventParticipant {
  const EventParticipant();

  factory EventParticipant.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    return switch (kind) {
      'randomPlayer' => const RandomPlayerParticipant(),
      'twoRandomPlayers' => const TwoRandomPlayersParticipant(),
      'wholeGroup' => const WholeGroupParticipant(),
      'maxStat' => MaxStatParticipant(stat: StatType.fromJson(json['stat'] as String)),
      'minStat' => MinStatParticipant(stat: StatType.fromJson(json['stat'] as String)),
      'hasItem' => HasItemParticipant(itemId: json['itemId'] as String),
      'hasOrigin' => HasOriginParticipant(originId: json['originId'] as String),
      'unknownOrigin' => const UnknownOriginParticipant(),
      'chosen' => const ChosenParticipant(),
      'previousParticipant' => const PreviousParticipant(),
      'previousWinner' => const PreviousWinner(),
      'previousLoser' => const PreviousLoser(),
      'leader' => const LeaderParticipant(),
      _ => throw FormatException('Unknown event participant kind: $kind'),
    };
  }

  Map<String, dynamic> toJson();
}

/// One uniformly random player from the whole party — the default when a
/// [GameCard] doesn't specify a [participant], which is what keeps every
/// card authored before this system existed working unchanged.
final class RandomPlayerParticipant extends EventParticipant {
  const RandomPlayerParticipant();

  @override
  Map<String, dynamic> toJson() => {'kind': 'randomPlayer'};
}

/// Two distinct random players — resolves to `ActionTarget.currentPlayer`
/// and `ActionTarget.secondaryPlayer`. For an asymmetric outcome between the
/// two (a contest, a duel), pair this with `StartDuelAction`-style
/// winner/loser actions; for a symmetric one (both get cursed), target each
/// one directly.
final class TwoRandomPlayersParticipant extends EventParticipant {
  const TwoRandomPlayersParticipant();

  @override
  Map<String, dynamic> toJson() => {'kind': 'twoRandomPlayers'};
}

/// No individual is singled out — for cards that only ever target
/// `ActionTarget.allPlayers`.
final class WholeGroupParticipant extends EventParticipant {
  const WholeGroupParticipant();

  @override
  Map<String, dynamic> toJson() => {'kind': 'wholeGroup'};
}

/// The player with the highest [stat] — ties broken randomly.
final class MaxStatParticipant extends EventParticipant {
  final StatType stat;

  const MaxStatParticipant({required this.stat});

  @override
  Map<String, dynamic> toJson() => {'kind': 'maxStat', 'stat': stat.toJson()};
}

/// The player with the lowest [stat] — ties broken randomly.
final class MinStatParticipant extends EventParticipant {
  final StatType stat;

  const MinStatParticipant({required this.stat});

  @override
  Map<String, dynamic> toJson() => {'kind': 'minStat', 'stat': stat.toJson()};
}

/// A random player among those holding [itemId]. Falls back to a random
/// player from the whole party if nobody holds it, so a draw never gets
/// stuck — content authors should usually also gate the card itself with
/// `anyPlayerHasItem` so this only comes up when it makes sense.
final class HasItemParticipant extends EventParticipant {
  final String itemId;

  const HasItemParticipant({required this.itemId});

  @override
  Map<String, dynamic> toJson() => {'kind': 'hasItem', 'itemId': itemId};
}

/// A random player among those with [originId] as their `Player.originId`.
/// Falls back to a random player from the whole party if nobody has that
/// origin, so a draw never gets stuck — pair with `AnyPlayerHasOriginCondition`
/// on the card itself so this only comes up when it's actually relevant
/// ("Рептилия увидела тёплую реку").
final class HasOriginParticipant extends EventParticipant {
  final String originId;

  const HasOriginParticipant({required this.originId});

  @override
  Map<String, dynamic> toJson() => {'kind': 'hasOrigin', 'originId': originId};
}

/// A random player among those who still have no revealed `Player
/// .originId` — the participant half of the origin-reveal mechanism (see
/// `RevealOriginAction`, `AnyPlayerMissingOriginCondition`). Falls back to a
/// random player from the whole party if everyone's origin is already
/// known, which shouldn't come up in practice since a reveal card should
/// always be gated on `AnyPlayerMissingOriginCondition` too.
final class UnknownOriginParticipant extends EventParticipant {
  const UnknownOriginParticipant();

  @override
  Map<String, dynamic> toJson() => {'kind': 'unknownOrigin'};
}

/// The table picks who this is about — a volunteer, or a player the group
/// names by discussion. Suspends the step until `GameController
/// .resolveParticipant` is called with the chosen player's id.
final class ChosenParticipant extends EventParticipant {
  const ChosenParticipant();

  @override
  Map<String, dynamic> toJson() => {'kind': 'chosen'};
}

/// Whoever the *previous* event was about — see
/// `WorldState.previousParticipantId`. Lets a card build on the one before
/// it ("тот, кто открывал сундук ранее..."). Falls back to a random player
/// on the very first step of a game, when there is no previous event yet.
final class PreviousParticipant extends EventParticipant {
  const PreviousParticipant();

  @override
  Map<String, dynamic> toJson() => {'kind': 'previousParticipant'};
}

/// The winner of the most recent `StartDuelAction` — see
/// `WorldState.previousWinnerId`. Falls back to a random player if no duel
/// has happened yet this game.
final class PreviousWinner extends EventParticipant {
  const PreviousWinner();

  @override
  Map<String, dynamic> toJson() => {'kind': 'previousWinner'};
}

/// The loser of the most recent `StartDuelAction` — see
/// `WorldState.previousLoserId`. Falls back to a random player if no duel
/// has happened yet this game.
final class PreviousLoser extends EventParticipant {
  const PreviousLoser();

  @override
  Map<String, dynamic> toJson() => {'kind': 'previousLoser'};
}

/// Whoever currently holds the party's temporary leader role — see
/// `WorldState.leaderId`. Not a permanent seat: it only changes when some
/// event applies `SetLeaderAction`, and stays with that player across
/// however many steps until another event hands it off. Falls back to a
/// random player if nobody has been made leader yet — content that should
/// only fire once a leader genuinely exists should gate on
/// `LeaderIsSetCondition` rather than rely on that fallback.
final class LeaderParticipant extends EventParticipant {
  const LeaderParticipant();

  @override
  Map<String, dynamic> toJson() => {'kind': 'leader'};
}
