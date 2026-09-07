import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/game_labels.dart';
import '../../../../core/theme/steel_palette.dart';
import '../../../../game_engine/models/models.dart';

/// The full-screen moment when a player's origin surfaces.
///
/// Every playtest audit this project has run said the same thing: the
/// reveal is the best moment in a match and the most under-shown. It used
/// to be a half-second scale flash inside a roster card the size of a
/// business card. Now the game stops.
///
/// Deliberately not dismissible by time, swipe or barrier — the table
/// decides when to move on, because the point is that everyone looks at
/// the phone at once. There is no automatic timeout to race a conversation.
///
/// **No numbers.** `Origin.statModifiers` exists and is not on this screen.
/// An origin is who someone turns out to be, not a build, and printing
/// "+1 / -1" under the name would answer a question nobody at the table is
/// asking at that second.
class OriginRevealScreen extends StatelessWidget {
  final String playerName;
  final Origin origin;

  const OriginRevealScreen({
    super.key,
    required this.playerName,
    required this.origin,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = AppColors.rarityColor(origin.rarity);
    final glow = AppColors.glowFor(origin.rarity);

    return Scaffold(
      backgroundColor: SteelPalette.background,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _RevealBackground(color: color),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(34, 40, 34, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The block is centred in whatever is left above the
                    // hint rather than pinned to the top with a free
                    // `Spacer` under it. A Spacer hands every extra
                    // millimetre of a taller phone to the gap above the
                    // hint, which is how the mock's compact composition
                    // turned into a lonely line in the far corner on a
                    // real device. Centred, the extra height is split.
                    Expanded(
                      child: Center(
                        // Scrolls rather than overflows if the text is
                        // long or the system font is scaled up.
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                playerName.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 3.3,
                                  color: SteelPalette.textLow.withValues(
                                    alpha: 0.66,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              // A thread running from the player down into the
                              // medallion: this is *their* thing, not an announcement.
                              Container(
                                width: 1,
                                height: 22,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      SteelPalette.steel.withValues(
                                        alpha: 0.15,
                                      ),
                                      color.withValues(alpha: 0.9),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              _Medallion(
                                origin: origin,
                                color: color,
                                glow: glow,
                              ),
                              const SizedBox(height: 30),
                              Text(
                                _displayName(origin.name),
                                textAlign: TextAlign.center,
                                style: textTheme.headlineMedium?.copyWith(
                                  fontSize: 34,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.02,
                                  color: SteelPalette.textHigh,
                                  shadows: [
                                    const Shadow(
                                      color: Color(0xB3000000),
                                      offset: Offset(0, 2),
                                      blurRadius: 10,
                                    ),
                                    Shadow(
                                      color: color.withValues(alpha: 0.35),
                                      blurRadius: 24,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _RarityLine(origin: origin, color: color),
                              const SizedBox(height: 22),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 300,
                                ),
                                child: Text(
                                  origin.description,
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontSize: 14,
                                    height: 1.5,
                                    fontStyle: FontStyle.italic,
                                    color: SteelPalette.textLow.withValues(
                                      alpha: 0.82,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'НАЖМИТЕ, ЧТОБЫ ПРОДОЛЖИТЬ',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.07,
                        color: SteelPalette.textLow.withValues(alpha: 0.66),
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

/// Origin names carry a leading emoji in content (`🐉 Драконорождённый`) —
/// it was the icon, back when there was no icon. Stripped here only, so
/// the drawn mark in the medallion isn't doubled by a tiny cartoon of
/// itself; every other screen still shows the name exactly as authored.
String _displayName(String name) {
  final firstSpace = name.indexOf(' ');
  if (firstSpace <= 0) return name;
  final head = name.substring(0, firstSpace);
  final isEmoji = head.runes.every((r) => r > 0x2000);
  return isEmoji ? name.substring(firstSpace + 1) : name;
}

/// Three static layers: rarity-tinted light above, a fainter pool below,
/// and corners pulled back into the dark. Nothing here animates — the only
/// movement on this screen belongs to the legendary pulse, so it stays the
/// thing the eye catches.
class _RevealBackground extends StatelessWidget {
  final Color color;

  const _RevealBackground({required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.55),
              radius: 1.05,
              colors: [
                color.withValues(alpha: 0.22),
                color.withValues(alpha: 0.07),
                SteelPalette.background.withValues(alpha: 0),
              ],
              stops: const [0, 0.42, 1],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 0.4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomCenter,
                  radius: 0.9,
                  colors: [
                    color.withValues(alpha: 0.1),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1,
              colors: [Color(0x00000000), Color(0x8C000000)],
              stops: [0.4, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// The struck disc holding the origin's mark.
///
/// **Rarity lives in the rings, not in the coin.** The border colour, its
/// alpha, the strength of the glow and the legendary pulse all scale; the
/// face and the mark inside stay the same steel at every tier. Tinting the
/// fill and the icon too made the whole disc one flat colour, which reads
/// as "this thing is gold" rather than "this thing is *rimmed* in gold" —
/// and it left common origins looking like a mistake instead of a quieter
/// version of the same object.
///
/// The pulse on the legendary tier is the same one [RarityFrame] runs — a
/// looping [TweenAnimationBuilder] that flips its target on `onEnd`, driven
/// off the same [AppColors.glowFor] spec — rather than a second animation
/// with its own timing. One ramp, one source of truth: if the legendary
/// glow is ever retuned, both move together.
class _Medallion extends StatefulWidget {
  final Origin origin;
  final Color color;
  final RarityGlow glow;

  const _Medallion({
    required this.origin,
    required this.color,
    required this.glow,
  });

  @override
  State<_Medallion> createState() => _MedallionState();
}

class _MedallionState extends State<_Medallion> {
  bool _glowUp = true;

  @override
  Widget build(BuildContext context) {
    final glow = widget.glow;
    if (!glow.pulse) return _disc(glow.shadowAlpha);

    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: _glowUp ? glow.shadowAlpha * 0.45 : glow.shadowAlpha,
        end: _glowUp ? glow.shadowAlpha : glow.shadowAlpha * 0.45,
      ),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeInOut,
      onEnd: () => setState(() => _glowUp = !_glowUp),
      builder: (context, shadowAlpha, _) => _disc(shadowAlpha),
    );
  }

  /// Fixed, and deliberately smaller than the 198 the mock specified. The
  /// mock's frame is wider than a real phone, so the same constant came out
  /// noticeably heavier on device; these keep the proportion the design
  /// actually shows. Nothing here reads [MediaQuery] — the disc must not
  /// grow with the screen.
  static const double _outer = 176;
  static const double _inner = 148;
  static const double _mark = 55;

  Widget _disc(double shadowAlpha) {
    final color = widget.color;
    final glow = widget.glow;
    return Container(
      width: _outer,
      height: _outer,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Opaque, and stated as the gradient's own ends rather than as a
        // `color:` underneath it — a BoxDecoration carrying both ignores
        // the colour, which left the face translucent and let the
        // rarity-tinted light behind the screen shine straight through it.
        // Neutral either way: a hint of light off the top of the metal,
        // the same on a common origin as on a legendary one.
        gradient: const RadialGradient(
          center: Alignment(0, -0.25),
          radius: 0.85,
          colors: [Color(0xFF1B2026), Color(0xFF101317)],
        ),
        border: Border.all(color: color.withValues(alpha: glow.borderAlpha)),
        boxShadow: glow.blurRadius == 0
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: shadowAlpha),
                  blurRadius: glow.blurRadius,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: Container(
        width: _inner,
        height: _inner,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: glow.borderAlpha * 0.45),
          ),
        ),
        child: SvgPicture.asset(
          'assets/icons/origins/${widget.origin.id}.svg',
          width: _mark,
          height: _mark,
          colorFilter: const ColorFilter.mode(
            SteelPalette.textLow,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

/// "легендарное · истинная природа", flanked by two short rules.
class _RarityLine extends StatelessWidget {
  final Origin origin;
  final Color color;

  const _RarityLine({required this.origin, required this.color});

  @override
  Widget build(BuildContext context) {
    final label =
        '${rarityLabel(origin.rarity)} · '
                '${originCategoryLabel(origin.category)}'
            .toUpperCase();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Rule(color: color, fadesInwards: true),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.4,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _Rule(color: color, fadesInwards: false),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  final Color color;
  final bool fadesInwards;

  const _Rule({required this.color, required this.fadesInwards});

  @override
  Widget build(BuildContext context) {
    final colors = [color.withValues(alpha: 0), color.withValues(alpha: 0.65)];
    return Container(
      width: 34,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fadesInwards ? colors : colors.reversed.toList(),
        ),
      ),
    );
  }
}

/// Shows the reveal and resolves once the table taps to move on.
///
/// A plain opaque route rather than a dialog: this is a scene, not a
/// question, and it should own the whole screen including the space a
/// dialog would leave showing the game behind it.
Future<void> showOriginRevealScreen(
  BuildContext context, {
  required String playerName,
  required Origin origin,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder(
      opaque: true,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) =>
          OriginRevealScreen(playerName: playerName, origin: origin),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}
