import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../core/theme/main_menu_palette.dart';
import '../../../core/theme/main_menu_taglines.dart';
import 'widgets/main_menu_medallion.dart';

const double _medallionSize = 196;
const double _rosetteSize = 320;
const EdgeInsets _screenPadding = EdgeInsets.fromLTRB(40, 74, 40, 44);
const double _taglineMaxWidth = 300;

/// The title screen. Everything here is branding rather than gameplay UI, so
/// it is the one place in the app that paints against literal values from
/// [MainMenuPalette] instead of the `ColorScheme`.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  /// Rolled once per visit to the menu, not per rebuild — a line that
  /// changed on every frame would read as a glitch, not as flavour.
  late final String _tagline = randomMainMenuTagline();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MainMenuPalette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _BackgroundGlow(),
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
        const _Emblem(),
        const SizedBox(height: 34),
        Padding(
          // Nudged by one letter-space: the trailing tracking on the last
          // glyph of each line otherwise pushes centred text visibly left.
          padding: const EdgeInsets.only(left: 2.4),
          child: Text(
            'АЛКО\nКВЕСТ',
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium?.copyWith(
              fontSize: 40,
              height: 1.08,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
              color: MainMenuPalette.parchment,
              shadows: [
                const Shadow(
                  color: Color(0xB3000000),
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
                Shadow(
                  color: MainMenuPalette.gold.withValues(alpha: 0.22),
                  blurRadius: 26,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const _DiamondDivider(),
        const SizedBox(height: 16),
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
              color: MainMenuPalette.taglineTint.withValues(alpha: 0.8),
            ),
          ),
        ),
        // Minimum air between the emblem block and the menu, kept even on a
        // screen too short for the [Spacer] to contribute anything.
        const SizedBox(height: 48),
        const Spacer(),
        _MenuItem(
          title: 'Новая игра',
          subtitle: 'собрать компанию и выйти на дорогу',
          active: true,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.gameSetup),
        ),
        const SizedBox(height: 12),
        _MenuItem(
          title: 'Настройки',
          active: false,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.settings),
        ),
      ],
    );
  }
}

/// Layered lighting for the whole screen: a warm glow above the emblem, a
/// fainter one rising from the floor, and a vignette that pulls the corners
/// back down into the dark.
class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.72),
              radius: 1.05,
              colors: [
                Color(0x33D4A94C),
                Color(0x1A653E10),
                Color(0x00100C08),
              ],
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
                  colors: [Color(0x1FD4A94C), Color(0x00D4A94C)],
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

/// The medallion with the faint seal engraved behind it.
class _Emblem extends StatelessWidget {
  const _Emblem();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: _medallionSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // The rings are wider than the coin, so they are allowed to
          // overflow their slot instead of reserving layout space and
          // pushing the title down.
          OverflowBox(
            maxWidth: _rosetteSize,
            maxHeight: _rosetteSize,
            child: CustomPaint(
              size: Size.square(_rosetteSize),
              painter: _RosettePainter(),
            ),
          ),
          MainMenuMedallion(size: _medallionSize),
        ],
      ),
    );
  }
}

/// Concentric hairlines and rim notches — the same notches struck into the
/// launcher icon, faint enough here to read as texture rather than as a
/// second object competing with the coin.
class _RosettePainter extends CustomPainter {
  const _RosettePainter();

  static const List<double> _radii = [0.35, 0.415, 0.475, 0.5];
  static const List<double> _alphas = [0.09, 0.065, 0.05, 0.04];
  static const int _notchCount = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final span = size.shortestSide;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < _radii.length; i++) {
      ring.color = MainMenuPalette.gold.withValues(alpha: _alphas[i]);
      canvas.drawCircle(center, span * _radii[i], ring);
    }

    final notch = Paint()
      ..color = MainMenuPalette.gold.withValues(alpha: 0.07)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < _notchCount; i++) {
      final angle = i * 2 * math.pi / _notchCount;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * (span * 0.475),
        center + direction * (span * 0.5),
        notch,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Two tapering hairlines meeting at a small gold lozenge.
class _DiamondDivider extends StatelessWidget {
  const _DiamondDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Row(
        children: [
          const Expanded(child: _DividerLine(fadesInwards: true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Transform.rotate(
              angle: math.pi / 4,
              child: const SizedBox.square(
                dimension: 5,
                child: ColoredBox(color: MainMenuPalette.gold),
              ),
            ),
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
      MainMenuPalette.gold.withValues(alpha: 0),
      MainMenuPalette.gold.withValues(alpha: 0.55),
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

/// One plate in the menu. [active] is the whole difference between the
/// primary and the secondary entry — same shape, different amount of light,
/// so the eye lands on «Новая игра» without «Настройки» having to look
/// disabled.
class _MenuItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool active;
  final VoidCallback onTap;

  const _MenuItem({
    required this.title,
    required this.active,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    const gold = MainMenuPalette.gold;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(16);
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: active
                ? gold.withValues(alpha: 0.32)
                : MainMenuPalette.muted.withValues(alpha: 0.12),
          ),
          gradient: active
              ? LinearGradient(
                  colors: [
                    gold.withValues(alpha: 0.14),
                    gold.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.78],
                )
              : null,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: active ? 20 : 18,
              horizontal: 18,
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: active ? 34 : 24,
                  decoration: BoxDecoration(
                    color: active
                        ? gold
                        : MainMenuPalette.muted.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: gold.withValues(alpha: 0.55),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: active
                            ? textTheme.titleLarge?.copyWith(
                                fontSize: 21,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.26,
                                color: MainMenuPalette.parchment,
                              )
                            : textTheme.titleLarge?.copyWith(
                                fontSize: 16,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                color: MainMenuPalette.muted.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            height: 1.25,
                            color: MainMenuPalette.taglineTint.withValues(
                              alpha: 0.66,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ExcludeSemantics(
                  // Decorative: read aloud, "›" is noise on top of a button
                  // that already announces its own label.
                  child: Text(
                    '›',
                    style: TextStyle(
                      fontSize: active ? 22 : 20,
                      height: 1,
                      color: active
                          ? gold
                          : MainMenuPalette.muted.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
