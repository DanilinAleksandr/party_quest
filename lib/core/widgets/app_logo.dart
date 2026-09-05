import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';
import 'rarity_frame.dart';

/// Placeholder logo built from Material components. Swap the [Icon] for a
/// real image asset later without touching any screen that uses this
/// widget. Wrapped in a legendary-tier [RarityFrame] so the one branding
/// element in the whole app carries some of the same visual weight as the
/// game's rarest moments, instead of a bare `CircleAvatar`.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RarityFrame(
          rarity: Rarity.legendary,
          borderRadius: BorderRadius.circular(size),
          child: CircleAvatar(
            radius: size / 2,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.casino_rounded,
              size: size * 0.55,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Алко-Квест',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
