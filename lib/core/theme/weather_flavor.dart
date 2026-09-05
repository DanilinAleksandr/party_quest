import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';

/// Compact icon+label per [Weather] — deliberately secondary to
/// [biomeAtmosphere]/`AppColors.biomeIcon`: weather describes what's
/// happening around the party right now, biome describes where they are,
/// and the banner keeps that hierarchy visually (smaller, muted, appended
/// after the biome name rather than given its own block).
IconData weatherIcon(Weather weather) => switch (weather) {
  Weather.sunny => Icons.wb_sunny_outlined,
  Weather.rain => Icons.water_drop_outlined,
  Weather.fog => Icons.blur_on,
  Weather.night => Icons.nightlight_round,
};

String weatherLabel(Weather weather) => switch (weather) {
  Weather.sunny => 'Солнечно',
  Weather.rain => 'Ливень',
  Weather.fog => 'Туман',
  Weather.night => 'Ночь',
};
