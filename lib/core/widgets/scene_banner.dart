import 'package:flutter/material.dart';

import '../theme/steel_palette.dart';
import 'line_icons.dart';

/// The header scene every "where are we" banner is built from.
///
/// It is a *scene*, not a label: light falling from the upper left, and a
/// suggestion of trunks or standing stones rising out of the floor. The
/// bars are deliberately not an illustration of anything — at this size a
/// literal drawing of a forest would read as clip art, while vertical marks
/// dissolving upward read as depth.
///
/// Extracted so the prologue gets the same scene as a biome rather than a
/// thinner cousin of it. "You have not left yet" is a chapter of the
/// journey like any other, and drawing it in a different visual language
/// made the first minute of a match look like a different app.
///
/// No colour varies by location on purpose. Every chapter wears the same
/// steel, and what tells them apart is the drawn mark, the title, and the
/// line underneath — a per-biome tint would put six more competing hues
/// next to a rarity ramp that needs to stay the loudest colour on screen.
class SceneBanner extends StatelessWidget {
  final LineIconShape icon;
  final String title;

  /// The atmosphere line under the title — a sensory sentence, not a
  /// description of mechanics.
  final String subtitle;

  /// Optional "• icon label" after the title. Deliberately secondary
  /// (muted, smaller): where the party is stays the main fact, and this
  /// only describes its current state.
  final IconData? trailingIcon;
  final String? trailingLabel;

  /// A floor, not a fixed height. A short line should still get a scene
  /// worth looking at; a long one — the atmosphere line composes a season
  /// phrase with a weather phrase, so it runs to four lines in the worst
  /// case the content actually produces — must not be cut off with an
  /// ellipsis. The banner grows past this instead.
  static const double minHeight = 176;

  /// Sky above the text. Also what keeps the title off the top edge once
  /// the banner does grow: at [minHeight] the block simply sits lower.
  static const EdgeInsets _contentPadding = EdgeInsets.fromLTRB(18, 60, 18, 16);

  const SceneBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingIcon,
    this.trailingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Stack(
            // Every decorative layer is Positioned.fill, so the *text* is
            // the only child that decides how tall the banner is; the
            // scene then stretches to whatever that came out as.
            alignment: Alignment.bottomLeft,
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF181B20), Color(0xFF14161A)],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.65, -0.85),
                      radius: 1.15,
                      colors: [Color(0x389CA3AF), Color(0x009CA3AF)],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: 0.62,
                    child: ShaderMask(
                      // dstIn keeps the bars only where the mask is opaque, so
                      // they stand solid on the floor and dissolve upward.
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.white, Color(0x00FFFFFF)],
                        stops: [0.1, 1],
                      ).createShader(bounds),
                      // Size.infinite, not the default: a childless CustomPaint
                      // prefers Size.zero, and the loose width it gets here
                      // would collapse it to nothing at all.
                      child: const CustomPaint(
                        size: Size.infinite,
                        painter: _StandingBarsPainter(),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  // Floor darkening, so the title never has to compete with
                  // the texture behind it.
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xE014161A), Color(0x0014161A)],
                      stops: [0, 0.62],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: _contentPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        LineIcon(
                          shape: icon,
                          size: 27,
                          color: SteelPalette.textLow,
                          strokeWidth: 1.4,
                        ),
                        const SizedBox(width: 11),
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 25,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.25,
                              color: SteelPalette.textHigh,
                            ),
                          ),
                        ),
                        if (trailingIcon != null && trailingLabel != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            trailingIcon,
                            size: 14,
                            color: SteelPalette.steel,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            trailingLabel!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: SteelPalette.steel,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      // No maxLines: the banner grows to fit the line
                      // instead of the line being cut to fit the banner.
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        height: 1.35,
                        fontStyle: FontStyle.italic,
                        color: SteelPalette.textLow.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical marks at a steady interval — trunks, columns, standing stones,
/// depending on where the party is. Never varied per location: the moment
/// they try to depict a specific place they stop being texture.
class _StandingBarsPainter extends CustomPainter {
  const _StandingBarsPainter();

  static const double _spacing = 26;
  static const double _width = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x66000000);
    for (var x = _spacing / 2; x < size.width; x += _spacing) {
      canvas.drawRect(Rect.fromLTWH(x, 0, _width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
