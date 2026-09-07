import 'package:flutter/material.dart';

import '../../../../core/theme/steel_palette.dart';
import '../../../../core/widgets/line_icons.dart';

/// The one thing a player touches every turn.
///
/// Drawn as a button that is already slightly recessed before anyone
/// touches it — dark at the top edge, a hairline of light along the bottom
/// — so pressing it deepens something that already has depth rather than
/// flattening something that had none. Flutter has no inset shadow, so both
/// edges are painted as short gradient strips inside the clip.
///
/// Deliberately *not* `TactilePressButton`. That widget holds the action
/// back until its press finishes playing, which is right for the two words
/// on the title screen — pressed once, at the start of an evening. This
/// button is pressed twenty times a match, and the same delay stops reading
/// as weight and starts reading as lag. Here the plate answers the finger
/// on contact and the step fires on release.
///
/// [onPressed] is null while a card is open or the match is over; the whole
/// plate dims and stops responding, which is the same statement the old
/// disabled `FilledButton` made, without the Material chrome.
class TakeStepButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const TakeStepButton({super.key, required this.onPressed});

  @override
  State<TakeStepButton> createState() => _TakeStepButtonState();
}

class _TakeStepButtonState extends State<TakeStepButton> {
  bool _held = false;

  void _setHeld(bool held) {
    if (_held == held || widget.onPressed == null) return;
    setState(() => _held = held);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.onPressed != null;
    // No animation controller: the plate is either being held or it is not,
    // and the state flips on the same frame as the touch.
    final dim = (_held ? 0.72 : 1.0) * (enabled ? 1.0 : 0.45);

    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => _setHeld(true),
        onTapUp: (_) => _setHeld(false),
        onTapCancel: () => _setHeld(false),
        behavior: HitTestBehavior.opaque,
        child: Transform.scale(
          scale: _held ? 0.98 : 1,
          child: ClipRRect(
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
          ),
        ),
      ),
    );
  }
}
