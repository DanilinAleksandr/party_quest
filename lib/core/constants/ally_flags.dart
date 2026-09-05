/// World flags that mark a standing alliance with an NPC.
///
/// Allies are not a separate engine concept — they're ordinary
/// `WorldState` flags that content already sets (`pirate_captain.json`,
/// `desert_warlord.json`). This map is what makes them *recognisable as
/// alliances* to the presentation layer, and it is the single source of
/// truth for that: `computeResultEntries` reads it to raise a
/// `ResultKind.allyGained` card, and `influencesOf` reads it to tell an
/// ally-gated choice apart from any other world-flag-gated one.
///
/// Adding a future ally is one entry here and nothing else — the result
/// card and the 🔵 influence badge both start working for it at once.
/// Deliberately lives in `core/constants` rather than next to either
/// consumer, since `core/` may not depend on `features/`.
const Map<String, ({String name, String description})> allyFlags = {
  'captain_ally': (
    name: 'Капитан пиратов',
    description:
        'Теперь капитан относится к вашей компании как к друзьям. '
        'В будущих событиях он может помочь, открыть новые варианты выбора '
        'или изменить развитие некоторых приключений.',
  ),
  'warlord_ally': (
    name: 'Военачальник пустыни',
    description:
        'Военачальник признал вас союзниками. В будущих событиях его '
        'покровительство может открыть новые варианты выбора или уберечь '
        'от опасности.',
  ),
  'paladin_ally': (
    name: 'Орден',
    description:
        'Орден держит за вас слово. Его заставы и братья на дорогах '
        'встречают вас как своих — и там, где чужому не поверят, вам '
        'поверят.',
  ),
  'circle_ally': (
    name: 'Ведьмовской круг',
    description:
        'Круг считает вас своими. Травницы, знахарки и лесной люд помогут '
        'вам там, где чужому не откроют дверь, — но набожные и орденские '
        'станут смотреть косо.',
  ),
};
