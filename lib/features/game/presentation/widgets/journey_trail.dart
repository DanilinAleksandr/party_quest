import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/steel_palette.dart';

/// The party's progress as a trail of notches rather than a filled bar.
///
/// A progress bar says "you are 40% done", which is a fact about a number.
/// A row of marks says "you have walked these and those are still ahead",
/// which is a fact about a journey — and the brightest mark is the one just
/// cut, so the eye lands on where the party is standing now.
///
/// One notch per step only while that stays legible. Journeys run from 10
/// to 200 steps (`JourneyLengthConfig`), and 200 hairlines across a phone
/// would be a grey smear, so past what fits at [_minSegmentWidth] the
/// notches start standing for several steps each. The metaphor survives at
/// any length; the arithmetic quietly changes underneath.
class JourneyTrail extends StatelessWidget {
  final int partySteps;
  final int totalSteps;

  static const double _minSegmentWidth = 3;
  static const double _gap = 3;
  static const double _height = 6;

  const JourneyTrail({
    super.key,
    required this.partySteps,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fits =
                  ((constraints.maxWidth + _gap) / (_minSegmentWidth + _gap))
                      .floor();
              final segments = math.max(1, math.min(totalSteps, fits));
              // Floor, not round: a notch lights up when the party has
              // actually finished everything it stands for.
              final walked = (partySteps / totalSteps * segments).floor().clamp(
                0,
                segments,
              );

              return Row(
                children: [
                  for (var i = 0; i < segments; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    Expanded(child: _Notch(state: _stateOf(i, walked))),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$partySteps / $totalSteps',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.88,
            color: SteelPalette.textLow.withValues(alpha: 0.66),
          ),
        ),
      ],
    );
  }

  _NotchState _stateOf(int index, int walked) {
    if (index == walked - 1) return _NotchState.justWalked;
    if (index < walked) return _NotchState.walked;
    return _NotchState.ahead;
  }
}

enum _NotchState { walked, justWalked, ahead }

class _Notch extends StatelessWidget {
  final _NotchState state;

  const _Notch({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _NotchState.walked => SteelPalette.steel.withValues(alpha: 0.5),
      _NotchState.justWalked => SteelPalette.steel.withValues(alpha: 0.95),
      _NotchState.ahead => SteelPalette.textLow.withValues(alpha: 0.1),
    };
    return Container(
      height: JourneyTrail._height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
