import '../../game_engine/models/models.dart';

/// A short, sensory atmosphere line per biome — deliberately distinct in
/// voice from `Biome.description` (which is thematic/expository, e.g.
/// "Неизвестность, дикость, магия..."): this is a punchier, present-tense
/// line meant for `BiomeBanner`. A pure function of `biome.id` and,
/// optionally, [season] and [weather] — so it only ever changes when the
/// party actually changes biome, or the fixed season/current weather are
/// first known, never on an unrelated rebuild.
///
/// Both [season] and [weather] are optional so every existing call site
/// (`TavernBanner`'s fixed `'tavern'` lookup, which has neither concept)
/// keeps working untouched. When authored lines exist for both, this
/// **composes** them — the season line first (season is the outermost,
/// longest-lasting layer: it never changes for the whole match), then the
/// weather line — rather than one silently hiding the other. That avoids
/// needing a full biome×season×weather phrase table (5×4×4 = 80 hand-written
/// lines) to get the combined effect the design asks for: two authored
/// sentences, each already complete on their own, read together as one
/// atmosphere line. Falls back to whichever half is actually authored, and
/// finally to the empty string for any id this hasn't been taught about
/// yet, so a new biome added as content never crashes the banner.
///
/// The whole point of pairing season/weather with biome here (rather than
/// just unlocking a few extra card choices) is mood: the same forest reads
/// as a different place in spring vs. winter, and again in sun vs. fog,
/// purely through this one line — no new mechanic, just a deeper flavor
/// table over what already exists.
String biomeAtmosphere(String biomeId, [Weather? weather, Season? season]) {
  final parts = <String>[];
  if (season != null) {
    final s = _seasonPhrases['$biomeId:${season.name}'];
    if (s != null) parts.add(s);
  }
  if (weather != null) {
    final w = _weatherPhrases['$biomeId:${weather.name}'];
    if (w != null) parts.add(w);
  }
  if (parts.isNotEmpty) return parts.join(' ');
  return _phrases[biomeId] ?? '';
}

const Map<String, String> _phrases = {
  'forest': 'Лес словно наблюдает за вами...',
  'desert': 'Воздух дрожит от жары.',
  'tavern': 'Смех, звон кружек и обещания, о которых пожалеют утром.',
  'graveyard': 'Тишина здесь тяжелее любого крика.',
  'mountains': 'Ветер несёт с вершин что-то похожее на предупреждение.',
  'coast': 'Море хранит свои тайны глубже, чем кажется.',
  'floodlands': 'Дороги нет. Вода стоит и никуда не спешит.',
};

const Map<String, String> _weatherPhrases = {
  'forest:sunny': 'Лес полон дневного света, тени коротки и почти не пугают.',
  'forest:rain': 'Дождь стучит по кронам, а тропа расползается под ногами.',
  'forest:fog': 'Туман глушит звуки — лес будто затаил дыхание.',
  'forest:night': 'Тьма между стволами гуще любой тени, и лес словно наблюдает за вами...',

  'desert:sunny': 'Воздух дрожит от жары, а горизонт плывёт маревом.',
  'desert:rain': 'Редкий дождь превращает песок в вязкую корку.',
  'desert:fog': 'Пыльная дымка стирает горизонт — не разобрать, где небо, где земля.',
  'desert:night': 'Ночной холод пустыни пробирает быстрее любого зверя.',

  'graveyard:sunny': 'Даже солнце здесь ложится неохотно, между покосившимися камнями.',
  'graveyard:rain': 'Дождь стекает по надгробиям, будто камни сами оплакивают себя.',
  'graveyard:fog': 'Туман стелется между могилами — тишина здесь тяжелее любого крика.',
  'graveyard:night': 'Ночью тишина здесь тяжелее любого крика — и, кажется, не только тишина.',

  'mountains:sunny': 'Снег на вершинах слепит в лучах солнца.',
  'mountains:rain': 'Дождь превращает тропы в скользкие ленты.',
  'mountains:fog': 'Туман скрывает обрывы — один неверный шаг решает всё.',
  'mountains:night': 'Ветер несёт с вершин что-то похожее на предупреждение.',

  'coast:sunny': 'Солнце дробится в волнах, и море кажется почти дружелюбным.',
  'coast:rain': 'Дождь сливается с солёными брызгами — не разобрать, где кончается море.',
  'coast:fog': 'Туман глотает горизонт, и шум прибоя доносится будто ниоткуда.',
  'coast:night': 'Море хранит свои тайны глубже, чем кажется — особенно в темноте.',
};

const Map<String, String> _seasonPhrases = {
  'forest:spring': 'Молодая листва ещё липкая на ощупь, а лес полон птичьего гомона.',
  'forest:summer': 'Кроны смыкаются плотным пологом, и в чаще держится густая зелёная тень.',
  'forest:autumn': 'Палая листва глушит шаги, а воздух пахнет прелью и дымом.',
  'forest:winter': 'Голые стволы скрипят на морозе, а снег между ними лежит нетронутым.',

  'desert:spring': 'После редких дождей пустыня на пару недель зеленеет колючей травой.',
  'desert:summer': 'Земля растрескалась от зноя, а марево над барханами не спадает даже к вечеру.',
  'desert:autumn': 'Жара понемногу отступает, но песок ещё держит дневное тепло всю ночь.',
  'desert:winter': 'По ночам пустыня выстывает почти до инея — редкий путник готов к этому.',

  'graveyard:spring': 'Между покосившимися крестами пробивается первая упрямая зелень.',
  'graveyard:summer': 'Раскалённый камень надгробий пышет жаром весь день напролёт.',
  'graveyard:autumn': 'Сухие стебли шуршат между могил при каждом порыве ветра.',
  'graveyard:winter': 'Снег ровным одеялом стирает границы между тропой и могилами.',

  'mountains:spring': 'Талые ручьи с грохотом несутся по камням, разбухшие от снега на вершинах.',
  'mountains:summer': 'Снег держится только на самых вершинах — тропы внизу наконец свободны.',
  'mountains:autumn': 'Камень под ногами покрывается ледяной коркой уже с раннего утра.',
  'mountains:winter': 'Перевалы завалены снегом по пояс, а тропы читаются с трудом.',

  'coast:spring': 'После зимних штормов на берег до сих пор выносит обломки и водоросли.',
  'coast:summer': 'Раскалённый песок и ленивый прибой делают берег почти курортным.',
  'coast:autumn': 'Шторма становятся всё чаще, а рыбацкие лодки — всё осторожнее.',
  'coast:winter': 'Ледяные брызги обжигают лицо, а причал понемногу обрастает наледью.',
};
