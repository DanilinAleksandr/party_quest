import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game_engine/data/content_providers.dart';
import '../../../game_engine/models/models.dart';

/// For every adventure, the titles of the cards that can begin it.
///
/// Adventures carry no title of their own. What the party knows one by is
/// the card that opened it, which is also the line the journey log keeps —
/// «Аня: Много людей у одной могилы» — so that title is the name.
Map<String, Set<String>> adventureEntryTitles(Iterable<GameCard> cards) {
  final titles = <String, Set<String>>{};

  void scan(GameCard card, List<GameAction> actions) {
    for (final action in actions) {
      switch (action) {
        case StartAdventureAction a:
          titles.putIfAbsent(a.adventureId, () => {}).add(card.title);
        case ChanceCheckAction a:
          scan(card, a.winnerActions);
          scan(card, a.loserActions);
        case StartDuelAction a:
          scan(card, a.winnerActions);
          scan(card, a.loserActions);
        default:
          break;
      }
    }
  }

  for (final card in cards) {
    scan(card, card.actions);
    for (final choice in card.choices) {
      scan(card, choice.actions);
    }
  }
  return titles;
}

/// Built once per content load rather than on every dialog.
final adventureEntryTitlesProvider = Provider<Map<String, Set<String>>>(
  (ref) => adventureEntryTitles(ref.watch(cardsProvider).valueOrNull ?? []),
);

/// The name this party knows each adventure by.
///
/// Most adventures have one way in, and its title is the name. A few have
/// several (the witches' circle has three), and there the journey log says
/// which one *this* party walked through — the name has to be the one they
/// saw, or the badge names a scene they never had. An adventure whose way in
/// cannot be told is left out, and its badge stays «Мир».
Map<String, String> rememberedAdventureNames(
  Map<String, Set<String>> entryTitles,
  List<JourneyLogEntry> journeyLog,
) {
  final names = <String, String>{};
  for (final MapEntry(key: id, value: titles) in entryTitles.entries) {
    if (titles.length == 1) {
      names[id] = titles.single;
      continue;
    }
    // Log lines read "Имя: Заголовок". The latest match wins, in the unlikely
    // case two ways in were both taken.
    for (final entry in journeyLog.reversed) {
      final title = titles.where((t) => entry.text.endsWith(': $t'));
      if (title.isNotEmpty) {
        names[id] = title.first;
        break;
      }
    }
  }
  return names;
}
