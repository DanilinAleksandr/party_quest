import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/steel_palette.dart';

/// Central Material 3 theme. All screens pull colors/typography from here
/// rather than hardcoding them, so the visual identity can change in one
/// place later.
///
/// Design direction: "forged steel" — a cold grey seed carries the whole
/// `ColorScheme`, matching the screens that have already been drawn by hand
/// against `SteelPalette`. [dark] is the signature look the app is designed
/// around. [light] exists for `ThemeMode.system` users but isn't the visual
/// target — it derives from the same seed rather than a separate palette,
/// so the two never drift.
///
/// Deliberately no warm gold in the base palette. That hue belongs to
/// `AppColors.rarityColor(Rarity.legendary)`, and it earns its meaning by
/// being the colour of the rarest thing a player can find — a chrome that
/// spends it everywhere devalues it before the first card is drawn. The
/// seed is the same grey `SteelPalette.steelDim` uses, so the screens that
/// have not been redrawn yet at least sit in the right temperature instead
/// of staying visibly bronze next to the ones that have.
///
/// Two type faces, not one: [_displayFont] (Alegreya — a literary, dramatic
/// serif with full Cyrillic support) carries headings/titles, where the
/// fantasy identity actually matters; [_bodyFont] is a plain humanist sans,
/// because body text gets read out loud at a table over drinks and has to
/// stay effortless.
///
/// The display face must cover Cyrillic: this game is written in Russian,
/// and a Latin-only face silently falls back to the system sans for every
/// heading — which is exactly what Cinzel, the previous choice, did.
abstract final class AppTheme {
  static const Color _seedColor = Color(0xFF6B7280);

  /// The same cold hue as `SteelPalette.steel`, taken far enough down the
  /// ramp to carry white text and to stay readable *as* text on a pale
  /// surface. It lives here rather than in `SteelPalette` because that table
  /// describes the dark screens that are drawn by hand, and nothing there is
  /// ever painted on white.
  static const Color _lightAccent = Color(0xFF505A63);

  static final TextTheme _displayFont = GoogleFonts.alegreyaTextTheme();
  static final TextTheme _bodyFont = GoogleFonts.nunitoTextTheme();

  static TextTheme _blendedTextTheme(TextTheme base) => _bodyFont
      .apply(
        bodyColor: base.bodyLarge?.color,
        displayColor: base.displayLarge?.color,
      )
      .copyWith(
        displayLarge: _displayFont.displayLarge?.copyWith(
          color: base.displayLarge?.color,
        ),
        displayMedium: _displayFont.displayMedium?.copyWith(
          color: base.displayMedium?.color,
        ),
        displaySmall: _displayFont.displaySmall?.copyWith(
          color: base.displaySmall?.color,
        ),
        headlineLarge: _displayFont.headlineLarge?.copyWith(
          color: base.headlineLarge?.color,
        ),
        headlineMedium: _displayFont.headlineMedium?.copyWith(
          color: base.headlineMedium?.color,
        ),
        headlineSmall: _displayFont.headlineSmall?.copyWith(
          color: base.headlineSmall?.color,
        ),
        titleLarge: _displayFont.titleLarge?.copyWith(
          color: base.titleLarge?.color,
          fontWeight: FontWeight.w600,
        ),
      );

  /// The seed alone does not get the accent grey, so `primary` is set by
  /// hand.
  ///
  /// `ColorScheme.fromSeed` reads a seed as a *hue* and rebuilds its chroma
  /// from Material's own tonal palettes — a muted grey goes in and a tone
  /// with enough saturation to work as a Material accent comes out, which
  /// against these near-black surfaces reads plainly blue. That is one
  /// colour, but it is the colour of every filled dialog button, every
  /// outlined choice label, the dialog shell's default accent and the
  /// journal icon, so it was the only blue left in the game.
  ///
  /// Overriding `primary` rather than `filledButtonTheme` is what makes this
  /// a single edit: the outlined choices in a card dialog take their label
  /// colour from `primary` too, and a filled-button-only fix would have left
  /// them blue beside newly grey buttons.
  ///
  /// The two brightnesses need different greys, because the accent is both
  /// filled behind text and drawn as text. [SteelPalette.steel] is pale
  /// enough to carry a dark label and to read against a near-black dialog;
  /// on a light scheme it would have to survive white on top of it *and*
  /// stay legible on a pale surface, which no single tone that light can do
  /// — hence [_lightAccent]. Dark is the look the game is designed around;
  /// light exists for `ThemeMode.system` and only has to stay legible.
  static ColorScheme _colorSchemeFor(Brightness brightness) {
    final seeded = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    return brightness == Brightness.dark
        ? seeded.copyWith(
            primary: SteelPalette.steel,
            onPrimary: SteelPalette.background,
          )
        : seeded.copyWith(primary: _lightAccent, onPrimary: Colors.white);
  }

  static ThemeData _themeFor(Brightness brightness) {
    final colorScheme = _colorSchemeFor(brightness);
    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

    return base.copyWith(
      textTheme: _blendedTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: _displayFont.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainerHighest,
        shape: StadiumBorder(
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }

  static ThemeData get light => _themeFor(Brightness.light);

  static ThemeData get dark => _themeFor(Brightness.dark);
}
