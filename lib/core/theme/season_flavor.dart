import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';

/// Icon/label/color/narration per [Season] — mirrors `weather_flavor.dart`'s
/// shape. Unlike weather there is no compact banner chip for season (see
/// `BiomeBanner`'s doc comment): these are used by `SeasonRevealDialog`
/// only, the one moment the season is ever announced directly.
IconData seasonIcon(Season season) => switch (season) {
  Season.spring => Icons.local_florist_outlined,
  Season.summer => Icons.wb_sunny_outlined,
  Season.autumn => Icons.eco_outlined,
  Season.winter => Icons.ac_unit,
};

String seasonLabel(Season season) => switch (season) {
  Season.spring => 'Весна',
  Season.summer => 'Лето',
  Season.autumn => 'Осень',
  Season.winter => 'Зима',
};

Color seasonColor(Season season) => switch (season) {
  Season.spring => const Color(0xFF7CB88A),
  Season.summer => const Color(0xFFD9A441),
  Season.autumn => const Color(0xFFC9713F),
  Season.winter => const Color(0xFF6FA8C9),
};

/// A short, present-tense line read once, right as the party leaves the
/// prologue — see `SeasonRevealDialog`. Deliberately narrative rather than
/// a dry label ("Сезон: Зима"), per the user's own worked examples.
String seasonRevealNarration(Season season) => switch (season) {
  Season.spring =>
    'Воздух пахнет мокрой землёй и молодой листвой. Путешествие начинается весной.',
  Season.summer =>
    'Полуденное солнце обещает долгий погожий сезон. Путешествие начинается летом.',
  Season.autumn =>
    'Осенний ветер гонит по дороге первые опавшие листья... Путешествие начинается осенью.',
  Season.winter => 'Ночь выдалась морозной. Путешествие начинается зимой.',
};
