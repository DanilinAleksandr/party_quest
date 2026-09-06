import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../core/theme/main_menu_taglines.dart';
import '../../../core/theme/steel_palette.dart';
import '../../../core/widgets/tactile_press_button.dart';

const EdgeInsets _screenPadding = EdgeInsets.fromLTRB(40, 96, 40, 64);
const double _taglineMaxWidth = 300;

/// The title screen. Everything here is branding rather than gameplay UI, so
/// it is the one place in the app that paints against literal values from
/// [SteelPalette] instead of the `ColorScheme`.
///
/// The composition is deliberately quiet: light, air and one weighty title,
/// with no frame, plate or ornament anywhere. The menu entries are bare
/// words — what marks the primary one is a pair of small lozenges and more
/// light, not a container.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  /// Rolled once per visit to the menu, not per rebuild — a line that
  /// changed on every frame would read as a glitch, not as flavour.
  late final String _tagline = randomMainMenuTagline();

  /// Guards the whole menu, not one entry: a press takes most of a second
  /// to play out, which is long enough for a second tap to land on the
  /// *other* word and push two routes. Deliberately a plain field — nothing
  /// on screen is painted from it, so a `setState` would only cost a
  /// rebuild.
  bool _pressInFlight = false;

  bool _beginPress() {
    if (_pressInFlight) return false;
    _pressInFlight = true;
    return true;
  }

  void _go(String route) {
    if (!mounted) return;
    Navigator.of(context).pushNamed(route);
    // Released once the route is on its way, so the menu is live again by
    // the time the player comes back to it.
    _pressInFlight = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SteelPalette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _BackgroundLight(),
          SafeArea(
            child: LayoutBuilder(
              // The design is laid out for a tall phone. On a short screen —
              // or at a large system text scale — the content scrolls
              // instead of overflowing, while still filling the viewport
              // whenever there is room to spare.
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: _screenPadding,
                      child: _content(context, constraints.maxWidth),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, double availableWidth) {
    final textTheme = Theme.of(context).textTheme;
    // The tagline is held to [_taglineMaxWidth] so long lines break in the
    // middle instead of running the full width. Expressed as padding rather
    // than a `ConstrainedBox`, because a ConstrainedBox reports its
    // intrinsic height measured at the *incoming* width — it would promise
    // [IntrinsicHeight] one row and then wrap onto two.
    final taglineInset = math.max(
      0.0,
      (availableWidth - _screenPadding.horizontal - _taglineMaxWidth) / 2,
    );

    return Column(
      children: [
        const _EngravedTitle(),
        const SizedBox(height: 22),
        const _SteelDivider(),
        const SizedBox(height: 18),
        Padding(
          padding: EdgeInsets.only(
            left: taglineInset + 3.1,
            right: taglineInset,
          ),
          child: Text(
            _tagline.toUpperCase(),
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              fontSize: 11,
              height: 1.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 3.1,
              color: SteelPalette.textLow.withValues(alpha: 0.82),
            ),
          ),
        ),
        // Minimum air between the title block and the menu, kept even on a
        // screen too short for the [Spacer] to contribute anything.
        const SizedBox(height: 72),
        const Spacer(),
        _MenuItem(
          title: 'Новая игра',
          primary: true,
          beginPress: _beginPress,
          onActivate: () => _go(AppRoutes.gameSetup),
        ),
        const SizedBox(height: 10),
        _MenuItem(
          title: 'Настройки',
          primary: false,
          beginPress: _beginPress,
          onActivate: () => _go(AppRoutes.settings),
        ),
      ],
    );
  }
}

/// Cold light pooling behind the title and, more faintly, off the floor,
/// with the corners pulled back down into the dark.
class _BackgroundLight extends StatelessWidget {
  const _BackgroundLight();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.62),
              radius: 1.05,
              colors: [Color(0x339CA3AF), Color(0x129CA3AF), Color(0x0014161A)],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 0.42,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomCenter,
                  radius: 0.9,
                  colors: [Color(0x1A9CA3AF), Color(0x009CA3AF)],
                ),
              ),
              child: SizedBox.expand(),
            ),
          ),
        ),
        DecoratedBox(
          // Flutter has no inset box-shadow; a vignette is just a radial
          // gradient running the other way — clear in the middle, black at
          // the rim.
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1,
              colors: [Color(0x00000000), Color(0x80000000)],
              stops: [0.4, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// The title, cut from metal rather than filled with a colour.
///
/// Two shaders, nested, because they do different jobs:
///  * the inner one ([BlendMode.srcIn]) replaces the glyph colour with a
///    vertical light-to-shadow ramp, which is what makes the letters read
///    as a surface catching light from above;
///  * the outer one ([BlendMode.srcATop]) lays fine diagonal scoring over
///    whatever is already opaque — that is, over the glyphs and nothing
///    else. Drawn as a sibling instead, the hatching would show up as a
///    rectangle across the whole line box.
class _EngravedTitle extends StatelessWidget {
  const _EngravedTitle();

  /// One tile of the engraving, in logical pixels. The rect handed to
  /// `createShader` is what sets the period, so it is deliberately far
  /// smaller than the text: the gradient repeats across the glyphs instead
  /// of stretching once over them. Its width:height ratio is the angle.
  static const Rect _hatchTile = Rect.fromLTWH(0, 0, 9, 4.5);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium?.copyWith(
      fontSize: 40,
      height: 1.14,
      fontWeight: FontWeight.w700,
      letterSpacing: 6.4,
      color: Colors.white,
      // Kept deliberately light. A heavier drop shadow reads as a halo
      // around every glyph and muddies the metal ramp above it; this is
      // only here so the darkest part of the letterform still separates
      // from the background.
      shadows: const [
        Shadow(color: Color(0x8C000000), offset: Offset(0, 2), blurRadius: 7),
      ],
    );

    return Padding(
      // Nudged by one letter-space: the trailing tracking on the last glyph
      // of each line otherwise pushes centred text visibly left.
      padding: const EdgeInsets.only(left: 6.4),
      child: ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x00000000),
            Color(0x00000000),
            Color(0x30000000),
            Color(0x30000000),
            Color(0x00000000),
          ],
          stops: [0, 0.62, 0.64, 0.74, 0.76],
          tileMode: TileMode.repeated,
        ).createShader(_hatchTile),
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              SteelPalette.textHigh,
              SteelPalette.textLow,
              Color(0x9ED8DCE0),
            ],
            stops: [0, 0.55, 1],
          ).createShader(bounds),
          child: Text('АЛКО\nКВЕСТ', textAlign: TextAlign.center, style: style),
        ),
      ),
    );
  }
}

/// Two tapering hairlines meeting at a small steel lozenge.
class _SteelDivider extends StatelessWidget {
  const _SteelDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Row(
        children: [
          const Expanded(child: _DividerLine(fadesInwards: true)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: _Lozenge(size: 5, glow: false),
          ),
          const Expanded(child: _DividerLine(fadesInwards: false)),
        ],
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  final bool fadesInwards;

  const _DividerLine({required this.fadesInwards});

  @override
  Widget build(BuildContext context) {
    final colors = [
      SteelPalette.steel.withValues(alpha: 0),
      SteelPalette.steel.withValues(alpha: 0.6),
    ];
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fadesInwards ? colors : colors.reversed.toList(),
        ),
      ),
    );
  }
}

/// A small square stood on its corner. [glow] is what separates the marks
/// flanking the primary entry from the inert one in the divider.
///
/// [press] is 0 at rest and 1 at the bottom of a press; it pulls both the
/// face and the halo down, so the mark drops away from the light along
/// with the word it flanks.
class _Lozenge extends StatelessWidget {
  final double size;
  final bool glow;
  final double press;

  const _Lozenge({required this.size, required this.glow, this.press = 0});

  @override
  Widget build(BuildContext context) {
    final faceAlpha = (glow ? 0.85 : 0.7) * (1 - 0.35 * press);
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: SteelPalette.steel.withValues(alpha: faceAlpha),
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: SteelPalette.steel.withValues(
                      alpha: 0.55 * (1 - 0.75 * press),
                    ),
                    blurRadius: 10 * (1 - 0.6 * press),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

/// One entry in the menu: a word, centred, with nothing drawn around it.
///
/// [primary] carries the whole distinction — size, brightness, and a pair
/// of lit lozenges. The generous padding is not decoration; it is the tap
/// target, which now has no plate to inherit one from.
///
/// A tap plays the press through and *then* navigates — see
/// [TactilePressButton], which owns the timing and the guard while this
/// widget decides what "pressed" looks like for a bare word.
class _MenuItem extends StatelessWidget {
  final String title;
  final bool primary;

  /// Asks the menu for permission to start. Returns false while another
  /// entry is mid-press, so a second tap cannot push a second route.
  final bool Function() beginPress;

  /// Called once the press has finished playing, not when the finger lands.
  final VoidCallback onActivate;

  const _MenuItem({
    required this.title,
    required this.primary,
    required this.beginPress,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return TactilePressButton(
      beginPress: beginPress,
      onPressed: onActivate,
      builder: (context, press) {
        final baseAlpha = primary ? 1.0 : 0.66;
        final color = (primary ? SteelPalette.textHigh : SteelPalette.textLow)
            .withValues(alpha: baseAlpha * (1 - 0.4 * press));
        final label = Text(
          title,
          textAlign: TextAlign.center,
          style: primary
              ? textTheme.titleLarge?.copyWith(
                  fontSize: 26,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3.64,
                  color: color,
                )
              : textTheme.titleLarge?.copyWith(
                  fontSize: 21,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 2.94,
                  color: color,
                ),
        );

        return Padding(
          // The padding is inside the press so it scales with the word —
          // and it is the tap target, since there is no plate to inherit
          // one from.
          padding: EdgeInsets.symmetric(
            vertical: primary ? 16 : 14,
            horizontal: 24,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: primary
                ? [
                    // The lozenges ride with the word rather than staying
                    // put: the three of them read as one surface.
                    _Lozenge(size: 4, glow: true, press: press),
                    // Tracking already pads the word's right edge, so the
                    // leading gap is the wider of the two.
                    const SizedBox(width: 18),
                    Flexible(child: label),
                    const SizedBox(width: 14),
                    _Lozenge(size: 4, glow: true, press: press),
                  ]
                : [Flexible(child: label)],
          ),
        );
      },
    );
  }
}
