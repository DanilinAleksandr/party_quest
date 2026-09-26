/// One remembered line of the party's own story — "Летопись путешествия."
/// Unlike [JourneyLogEntry] (a structured record stamped automatically for
/// every resolved card, answering "what happened mechanically"), this
/// answers "what will the table actually remember" — so it's deliberately
/// just the player-facing phrase, already worded, stamped only at content
/// authors' explicit discretion (`AddChronicleEntryAction`) rather than
/// derived from anything automatically.
///
/// [aside] is a line the game adds under an entry without touching its
/// words — so far only one: that whoever it was about was too far gone to
/// remember it.
final class ChronicleEntry {
  final String text;
  final String? aside;

  const ChronicleEntry({required this.text, this.aside});
}

/// The aside a chronicle entry gets when its player was wasted at the time.
const String kWastedChronicleAside =
    '…что было дальше, никто толком не помнит.';
