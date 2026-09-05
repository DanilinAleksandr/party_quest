import '../../../game_engine/models/models.dart';

/// What kind of change a [ResultEntry] represents — drives the icon/title
/// `GameResultCard` shows for it. Kept separate from presentation (no
/// `Color`/`IconData` here) so this stays plain application-layer data, the
/// same way the rest of `result_diff.dart` has no Flutter dependency.
enum ResultKind {
  itemGained,
  itemLost,
  effectGained,
  effectLost,
  statChanged,
  originRevealed,
  leaderChanged,
  partyItemGained,
  partyItemLost,
  allyGained,
}

/// One real change from a resolved card/adventure — shown as its own
/// "карточка результата" moment (see `showGameResultCard`), never bundled
/// with others into a single toast line. `computeResultEntries` produces a
/// list of these; the UI walks through them one at a time.
class ResultEntry {
  final ResultKind kind;

  /// Whose result this is — null for a whole-party change (a shared item,
  /// a leader handoff with no single "about" player).
  final String? playerName;

  /// The specific thing: an item/effect/origin name, or a formatted stat
  /// delta like "Сила +2".
  final String headline;

  /// Present only when the underlying thing has a rarity (items, origins)
  /// — drives `RarityFrame`'s glow on the result card. Null for effects,
  /// stat changes, and leader changes, none of which have one.
  final Rarity? rarity;

  /// True for a curse/loss/negative-delta entry — lets the card pick a
  /// warning color instead of a positive one for kinds that can go either
  /// way (`effectGained`, `statChanged`).
  final bool isNegative;

  /// One extra line of context shown under the headline — currently only
  /// `allyGained` uses this, to say *what the alliance means* rather than
  /// just naming the ally, per the user's explicit ask that the player
  /// never has to guess why a change mattered. Null for every other kind.
  final String? description;

  const ResultEntry({
    required this.kind,
    this.playerName,
    required this.headline,
    this.rarity,
    this.isNegative = false,
    this.description,
  });
}
