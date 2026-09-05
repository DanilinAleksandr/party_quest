import 'package:flutter/material.dart';

import '../../../../core/theme/main_menu_palette.dart';

/// The struck-coin emblem at the top of the main menu: an outer ring, an
/// inner ring lit from slightly above centre, and a die showing five.
///
/// Deliberately *not* built on `RarityFrame`/`AppLogo`: that frame's
/// pulsing gold glow is reserved for the origin reveal — the single most
/// valuable moment in a campaign — and spending it on the menu would train
/// players to read the pulse as decoration before they ever earn it. Here
/// the glow is static.
///
/// The die is the same mark as the launcher icon, so the thing players tap
/// on the home screen and the thing they see one second later are one
/// object.
class MainMenuMedallion extends StatelessWidget {
  /// Diameter of the outer ring. Everything inside is a ratio of it, so the
  /// emblem scales as one piece.
  final double size;

  const MainMenuMedallion({super.key, this.size = 196});

  @override
  Widget build(BuildContext context) {
    const gold = MainMenuPalette.gold;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MainMenuPalette.medallionFill,
          border: Border.all(color: gold.withValues(alpha: 0.85)),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: 0.22),
              blurRadius: size * 0.224,
            ),
          ],
        ),
        child: Center(
          child: SizedBox.square(
            dimension: size * 0.867,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: gold.withValues(alpha: 0.34)),
                gradient: RadialGradient(
                  // Offset above centre so the coin reads as lit from
                  // above rather than self-luminous.
                  center: const Alignment(0, -0.35),
                  radius: 0.85,
                  colors: [
                    gold.withValues(alpha: 0.10),
                    gold.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Center(child: _Die(size: size * 0.398)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded square showing the classic five-pip face.
class _Die extends StatelessWidget {
  final double size;

  const _Die({required this.size});

  @override
  Widget build(BuildContext context) {
    const gold = MainMenuPalette.gold;
    final pip = size * 0.115;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.205),
        border: Border.all(color: gold.withValues(alpha: 0.9), width: 1.5),
        // Flutter has no inset shadow. The same "the rim is lit from
        // inside" effect comes from a gradient that brightens outwards.
        gradient: RadialGradient(
          radius: 0.9,
          colors: [gold.withValues(alpha: 0), gold.withValues(alpha: 0.13)],
          stops: const [0.55, 1],
        ),
      ),
      child: Column(
        children: [
          _pipRow(const [true, false, true], pip),
          _pipRow(const [false, true, false], pip),
          _pipRow(const [true, false, true], pip),
        ],
      ),
    );
  }

  Widget _pipRow(List<bool> pips, double pipSize) => Expanded(
    child: Row(
      children: [
        for (final filled in pips)
          Expanded(
            child: Center(
              child: filled
                  ? Container(
                      width: pipSize,
                      height: pipSize,
                      decoration: const BoxDecoration(
                        color: MainMenuPalette.gold,
                        shape: BoxShape.circle,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    ),
  );
}
