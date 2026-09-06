import 'package:flutter/material.dart';

/// The "forged steel" palette — one table for every screen that has been
/// pulled out of the old Material brown and into the new look.
///
/// Deliberately literal hexes instead of `ColorScheme` lookups: these
/// screens are branding and atmosphere rather than generic Material
/// surfaces, and the design is specified against these exact values.
/// Dialogs and sheets still read from the theme.
///
/// No gold here, on purpose. `AppColors.rarityColor(Rarity.legendary)` owns
/// that hue, and it earns its meaning inside the game by being the colour
/// of the rarest thing a player can find. A chrome that spends it on
/// decoration devalues it before the first card is drawn — so rarity keeps
/// its full ramp, and everything around it goes grey.
abstract final class SteelPalette {
  /// Near-black with a cold blue-grey cast, so the steel above it reads as
  /// lit metal rather than as beige paper.
  static const Color background = Color(0xFF14161A);

  /// Panels that sit on top of [background] — player cards, the banner's
  /// darker end.
  static const Color surface = Color(0xFF1F2226);

  /// One step lighter again: chips and pills inside a [surface] panel.
  static const Color surfaceRaised = Color(0xFF23272C);

  /// The one accent: rules, lozenges, borders, and the light that pools
  /// behind a title.
  static const Color steel = Color(0xFF9CA3AF);

  /// The same accent turned down — icons and marks that should register
  /// without competing for attention.
  static const Color steelDim = Color(0xFF6B7280);

  /// The two ends of the type ramp: [textHigh] for the thing being named,
  /// [textLow] (usually at reduced alpha) for everything explaining it.
  static const Color textHigh = Color(0xFFEDEFF2);
  static const Color textLow = Color(0xFFD8DCE0);
}
