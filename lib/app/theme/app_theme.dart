import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central Material 3 theme. All screens pull colors/typography from here
/// rather than hardcoding them, so the visual identity can change in one
/// place later.
///
/// Design direction: "dark fantasy, muted" — a dark, warm-bronze seed carries
/// the whole `ColorScheme` (the "adventurer's camp" feel), while [dark] is
/// the signature look the app is designed around. [light] exists for
/// `ThemeMode.system` users but isn't the visual target — it derives from
/// the same seed rather than a separate palette, so the two never drift.
///
/// Two type faces, not one: [_displayFont] (Cinzel — a carved, classical
/// feel without tipping into "old scroll" pastiche) carries headings/titles,
/// where the fantasy identity actually matters; [_bodyFont] is a plain
/// humanist sans, because body text gets read out loud at a table over
/// drinks and has to stay effortless.
abstract final class AppTheme {
  static const Color _seedColor = Color(0xFFB0793F);

  static final TextTheme _displayFont = GoogleFonts.cinzelTextTheme();
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

  static ThemeData _themeFor(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
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
