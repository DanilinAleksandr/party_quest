import 'package:flutter/material.dart';

import '../../../../core/theme/steel_palette.dart';
import '../../../../core/widgets/line_icons.dart';
import '../../../../core/widgets/tactile_press_button.dart';

/// The one thing a player touches every turn.
///
/// Drawn as a button that is already slightly recessed before anyone
/// touches it — dark at the top edge, a hairline of light along the bottom
/// — so pressing it deepens something that already has depth rather than
/// flattening something that had none. Flutter has no inset shadow, so both
/// edges are painted as short gradient strips inside the clip.
///
/// [onPressed] is null while a card is open or the match is over; the whole
/// plate dims and the press stops responding, which is the same statement
/// the old disabled `FilledButton` made, without the Material chrome.
class TakeStepButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const TakeStepButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;

    return TactilePressButton(
      onPressed: onPressed,
      scaleDepth: 0.02,
      builder: (context, press) {
        // A plate this wide would look rubbery at the menu's depth, so it
        // travels less and pays for the rest of the press in light.
        final dim = (1 - 0.28 * press) * (enabled ? 1.0 : 0.45);
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: SteelPalette.steel.withValues(alpha: 0.34 * dim),
              ),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF15181C), Color(0xFF1C2024)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.black.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.05 * dim),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LineIcon(
                        shape: LineIconShape.die,
                        size: 21,
                        color: SteelPalette.textLow.withValues(
                          alpha: 0.72 * dim,
                        ),
                        strokeWidth: 1.3,
                      ),
                      const SizedBox(width: 13),
                      Text(
                        'СДЕЛАТЬ ШАГ',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 17,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3.06,
                          color: SteelPalette.textLow.withValues(
                            alpha: 0.8 * dim,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
