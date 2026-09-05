/// One remembered line of the party's own story — "Летопись путешествия."
/// Unlike [JourneyLogEntry] (a structured record stamped automatically for
/// every resolved card, answering "what happened mechanically"), this
/// answers "what will the table actually remember" — so it's deliberately
/// just the player-facing phrase, already worded, stamped only at content
/// authors' explicit discretion (`AddChronicleEntryAction`) rather than
/// derived from anything automatically.
final class ChronicleEntry {
  final String text;

  const ChronicleEntry({required this.text});
}
