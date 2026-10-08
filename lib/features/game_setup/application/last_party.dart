import 'package:shared_preferences/shared_preferences.dart';

/// The names of the party that last set out, in their order — offered again
/// on the next «Новая игра».
///
/// The same people usually sit at the same table. Taking someone out of
/// the list is one tap; typing everybody in again every evening was the
/// chore a playtest complained about.
///
/// A store that cannot be read or written (as under tests) only means the
/// list starts empty, as it does on a first launch.
abstract final class LastParty {
  static const _key = 'last_party';

  static Future<List<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(List<String> names) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, names);
    } catch (_) {
      // Remembering failed; the match itself goes ahead all the same.
    }
  }
}
