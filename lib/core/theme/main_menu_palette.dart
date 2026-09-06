import 'package:flutter/material.dart';

/// The main menu's own palette.
///
/// Deliberately literal hexes instead of `ColorScheme` lookups: the menu is
/// the one screen that is pure branding rather than gameplay UI, and its
/// design is specified against these exact values. Everything else in the
/// app keeps pulling colors from the theme.
///
/// [gold] is the same value as `AppColors.rarityColor(Rarity.legendary)` and
/// as the Android launcher icon — restated here rather than imported,
/// because on this screen it means "the game's gold", not "this thing is
/// legendary".
abstract final class MainMenuPalette {
  static const Color gold = Color(0xFFD4A94C);
  static const Color background = Color(0xFF100C08);
  static const Color medallionFill = Color(0xFF0D0B0A);
  static const Color parchment = Color(0xFFF6EADA);
  static const Color muted = Color(0xFFEBE1D8);
  static const Color taglineTint = Color(0xFFD2C4B9);
}
