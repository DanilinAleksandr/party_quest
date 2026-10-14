import '../../game_engine/models/models.dart';

/// What an effect does and for how long, in the table's words, read off its
/// data rather than written by hand: «+1 к внимательности · на 4 карточки».
/// A description says what the moment is; this says what it is worth, and
/// cannot drift from what the engine actually does with it.
///
/// Empty for an effect that does nothing a check reads and has no end of
/// its own — there is nothing to add to its description.
String effectTerms(GameEffect effect) {
  final shifts = effect.id == kHangoverEffectId
      ? kHangoverShifts
      : effect.statShifts;
  final parts = <String>[
    for (final MapEntry(key: stat, value: delta) in shifts.entries)
      '${_signed(delta)} к ${_dative[stat]}',
    for (final MapEntry(key: stat, value: delta)
        in effect.partyStatShifts.entries)
      '${_signed(delta)} к ${_dative[stat]} всем остальным',
    if (effect.blocksNextNegativeEffect) 'гасит следующую беду',
  ];
  final length = _length(effect);
  if (length != null) parts.add(length);
  return parts.join(' · ');
}

String _signed(int delta) => delta > 0 ? '+$delta' : '−${-delta}';

String? _length(GameEffect effect) {
  if (effect.isIndefinite || !effect.autoExpire) {
    return effect.blocksNextNegativeEffect ? 'до первой беды' : null;
  }
  return 'на ${cardsWord(effect.duration)}';
}

/// «1 карточку», «3 карточки», «15 карточек».
String cardsWord(int n) {
  final ten = n % 10, hundred = n % 100;
  if (ten == 1 && hundred != 11) return '$n карточку';
  if (ten >= 2 && ten <= 4 && (hundred < 12 || hundred > 14)) {
    return '$n карточки';
  }
  return '$n карточек';
}

const Map<StatType, String> _dative = {
  StatType.strength: 'силе',
  StatType.luck: 'удаче',
  StatType.charisma: 'харизме',
  StatType.endurance: 'выносливости',
  StatType.attentiveness: 'внимательности',
  StatType.cunning: 'хитрости',
};
