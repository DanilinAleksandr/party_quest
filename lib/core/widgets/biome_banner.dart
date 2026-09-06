import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';
import '../theme/biome_flavor.dart';
import '../theme/steel_palette.dart';
import '../theme/weather_flavor.dart';
import 'line_icons.dart';

/// Full-width header showing the party's current "chapter" — the biome was
/// tracked in `WorldState` from the very first biome wave but never actually
/// shown anywhere in the UI until now. Pure presentation: reads [biome] for
/// its name and [biomeAtmosphere] for a short sensory line (a pure function
/// of [Biome.id] and, now, [weather] — the same forest reads as a different
/// place in sun, rain, fog, or at night, purely through this one line) —
/// never touches the engine.
///
/// It is a *scene*, not a label: light falling from the upper left, and a
/// suggestion of trunks or standing stones rising out of the floor. The
/// bars are deliberately not an illustration of anything — at this size a
/// literal drawing of a forest would read as clip art, while vertical marks
/// dissolving upward read as depth.
///
/// The biome's own colour is gone from here on purpose. Every biome now
/// wears the same steel, and what tells them apart is the drawn mark, the
/// name, and the line underneath — a per-biome tint would put six more
/// competing hues next to a rarity ramp that needs to stay the loudest
/// colour on the screen.
///
/// [weather] is optional and, when given, appended after the biome name as
/// a small "• icon label" — deliberately secondary (muted colour, smaller
/// icon) since biome is always the main fact and weather just describes its
/// current state, not a chapter of its own.
///
/// [season] is optional too and feeds only into the subtitle line (composed
/// together with [weather] by [biomeAtmosphere]) — deliberately no separate
/// icon/chip for it in the compact row: the season was already announced
/// once, as its own scene, when the party left the prologue (see
/// `SeasonRevealDialog`), so repeating it here as a badge would be a
/// redundant "setting" rather than atmosphere. The subtitle line is where it
/// keeps showing up, quietly, for the rest of the match.
class BiomeBanner extends StatelessWidget {
  final Biome biome;
  final Weather? weather;
  final Season? season;

  static const double _height = 176;

  const BiomeBanner({
    super.key,
    required this.biome,
    this.weather,
    this.season,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atmosphere = biomeAtmosphere(biome.id, weather, season);
    final subtitle = atmosphere.isEmpty ? biome.description : atmosphere;
    final muted = SteelPalette.textLow.withValues(alpha: 0.72);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: _height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF181B20), Color(0xFF14161A)],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.65, -0.85),
                  radius: 1.15,
                  colors: [Color(0x389CA3AF), Color(0x009CA3AF)],
                ),
              ),
            ),
            Align(
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
            const DecoratedBox(
              // Floor darkening, so the name never has to compete with the
              // texture behind it.
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xE014161A), Color(0x0014161A)],
                  stops: [0, 0.62],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        LineIcon(
                          shape: biomeLineIcon(biome.id),
                          size: 27,
                          color: SteelPalette.textLow,
                          strokeWidth: 1.4,
                        ),
                        const SizedBox(width: 11),
                        Flexible(
                          child: Text(
                            biome.name,
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
                        if (weather != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            weatherIcon(weather!),
                            size: 14,
                            color: SteelPalette.steel,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            weatherLabel(weather!),
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
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        height: 1.35,
                        fontStyle: FontStyle.italic,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vertical marks at a steady interval — trunks, columns, standing stones,
/// depending on where the party is. Never varied per biome: the moment they
/// try to depict a specific place they stop being texture.
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
