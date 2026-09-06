import 'package:flutter/material.dart';

/// The main menu's own palette — "forged steel".
///
/// Deliberately literal hexes instead of `ColorScheme` lookups: the menu is
/// the one screen that is pure branding rather than gameplay UI, and its
/// design is specified against these exact values. Everything else in the
/// app keeps pulling colors from the theme.
///
/// No gold here, on purpose. `AppColors.rarityColor(Rarity.legendary)` owns
/// that hue, and it earns its meaning inside the game by being the colour
/// of the rarest thing a player can find. A title screen that spends it on
/// decoration devalues it before the first card is drawn.
abstract final class MainMenuPalette {
  /// Near-black with a cold blue-grey cast, so the steel above it reads as
  /// lit metal rather than as beige paper.
  static const Color background = Color(0xFF14161A);

  /// The one accent: rules, lozenges, and the light that pools behind the
  /// title.
  static const Color steel = Color(0xFF9CA3AF);

  /// The two ends of the title's metal gradient — bright where the light
  /// hits, dimmer where the letterform falls away.
  static const Color titleHigh = Color(0xFFEDEFF2);
  static const Color titleLow = Color(0xFFD8DCE0);
}
