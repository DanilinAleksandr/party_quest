import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';
import '../theme/app_colors.dart';

/// One active effect (blessing or curse), color-coded by
/// [EffectPolarity] — green for positive, red for negative — so a player's
/// panel reads at a glance instead of every effect looking identical bar an
/// icon swap.
class EffectChip extends StatelessWidget {
  final GameEffect effect;

  const EffectChip({super.key, required this.effect});

  @override
  Widget build(BuildContext context) {
    final positive = effect.polarity == EffectPolarity.positive;
    final color = positive
        ? AppColors.positiveEffectColor
        : AppColors.negativeEffectColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.auto_awesome : Icons.dangerous_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(effect.name, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
