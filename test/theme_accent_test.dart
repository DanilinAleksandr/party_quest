import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:drinking_quest/app/theme/app_theme.dart';
import 'package:drinking_quest/core/theme/steel_palette.dart';

/// WCAG relative luminance, so the two accents can be checked against what
/// actually sits on top of them rather than by eye.
double _luminance(Color color) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // Only the colours are under test, but reading them builds the whole
  // theme, and that pulls in `google_fonts` — which would otherwise go to
  // the network for a face this test does not care about.
  //
  // These are `testWidgets` for the same reason: with fetching off,
  // google_fonts reports the missing face as an asynchronous error, and the
  // widget binding is what absorbs it instead of failing whichever plain
  // `test` happens to be running at the time.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('the accent colour', () {
    testWidgets('is steel, not the blue the seed generates', (tester) async {
      // `ColorScheme.fromSeed` rebuilds chroma from Material's tonal
      // palettes, so the muted grey seed still comes back saturated enough
      // to read as blue. Everything with an accent — filled buttons,
      // outlined choice labels, the dialog shell's default — goes through
      // `primary`, which is why it is set by hand.
      expect(AppTheme.dark.colorScheme.primary, SteelPalette.steel);

      // Light mode cannot use the same tone — see the contrast tests below —
      // so it is checked for what actually matters: a cold grey has almost
      // no spread between its channels, and the generated accent it replaces
      // had roughly three times this much.
      for (final theme in [AppTheme.dark, AppTheme.light]) {
        final p = theme.colorScheme.primary;
        final spread =
            [p.r, p.g, p.b].reduce(math.max) - [p.r, p.g, p.b].reduce(math.min);
        expect(spread, lessThan(0.12), reason: '${theme.brightness} accent');
      }
    });

    testWidgets('carries its own foreground at readable contrast', (
      tester,
    ) async {
      // The reason the two brightnesses cannot share one grey: whatever
      // `onPrimary` is has to survive on top of a filled button.
      for (final theme in [AppTheme.dark, AppTheme.light]) {
        final scheme = theme.colorScheme;
        expect(
          _contrast(scheme.primary, scheme.onPrimary),
          greaterThan(4.5),
          reason: 'onPrimary on a filled button in ${scheme.brightness}',
        );
      }
    });

    testWidgets('stays legible as a label on the surface behind it', (
      tester,
    ) async {
      // Outlined buttons and the dialog shell's icon draw `primary` directly
      // onto a surface instead of filling with it.
      for (final theme in [AppTheme.dark, AppTheme.light]) {
        final scheme = theme.colorScheme;
        expect(
          _contrast(scheme.primary, scheme.surfaceContainerHigh),
          greaterThan(4.5),
          reason: 'choice label on a dialog in ${scheme.brightness}',
        );
      }
    });
  });
}
