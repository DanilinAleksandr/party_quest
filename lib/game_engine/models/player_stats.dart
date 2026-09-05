import 'stat_type.dart';

/// A player's characteristics, stored as a sparse map rather than fixed
/// fields. Unset stats default to 0. This is what lets [StatType] grow
/// without ever touching this class or any serialization code.
final class PlayerStats {
  final Map<StatType, int> _values;

  const PlayerStats([Map<StatType, int> values = const {}]) : _values = values;

  static const PlayerStats initial = PlayerStats();

  int valueOf(StatType type) => _values[type] ?? 0;

  PlayerStats modify(StatType type, int delta) {
    final next = Map<StatType, int>.of(_values);
    next[type] = (next[type] ?? 0) + delta;
    return PlayerStats(next);
  }

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    return PlayerStats(
      json.map((key, value) => MapEntry(StatType.fromJson(key), value as int)),
    );
  }

  Map<String, dynamic> toJson() =>
      _values.map((key, value) => MapEntry(key.toJson(), value));
}
