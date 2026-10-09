import '../../../game_engine/models/models.dart';

/// Fills the names a choice's outcome text asks for.
///
/// `{youngest}` is the youngest of the current player's companions — who
/// gets sent for water when the table says age is an argument. With nobody
/// else at the table it is the current player themself. Ties go to whoever
/// sits first, so the same table always sends the same person.
String fillOutcomeNames(String text, GameState state) {
  if (!text.contains('{youngest}')) return text;
  final current = state.currentPlayer;
  final others = state.players.where((p) => p.id != current.id).toList();
  final pool = others.isEmpty ? [current] : others;
  final youngest = pool.reduce((a, b) => b.age < a.age ? b : a);
  return text.replaceAll('{youngest}', youngest.name);
}
