import 'card_type.dart';
import 'rarity.dart';

/// One resolved step's entry in `GameState.journeyLog` — a structured
/// record, not just a display string, so the journal UI can grow icons,
/// filtering, rarity highlighting, and a "show details" tap without another
/// round of engine changes. Nothing in the engine reacts to this (same
/// category as `WorldState.flags`'s "just memory" fields) — it exists
/// purely to answer "what happened so far" for the UI layer (the journey
/// log sheet, the win screen's derived statistics).
final class JourneyLogEntry {
  final String text;
  final CardType type;
  final Rarity? rarity;
  final String? biomeId;
  final String? relatedPlayerId;

  const JourneyLogEntry({
    required this.text,
    required this.type,
    this.rarity,
    this.biomeId,
    this.relatedPlayerId,
  });
}
