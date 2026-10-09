import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';
import '../theme/app_colors.dart';
import 'line_icons.dart';

/// One inventory item, tinted by [InventoryItem.rarity] via [RarityFrame]'s
/// same color ramp (without the full glow treatment — that's reserved for
/// bigger moments, an inventory row would be noisy with a dozen pulsing
/// chips). A rarer item still reads as visibly more valuable at a glance.
///
/// An aura shows only once the party noticed it on a close look (see
/// `ItemAura.known`): a word, «холодит» or «греет», and never what it does.
/// An aura nobody noticed shows nothing at all.
class ItemChip extends StatelessWidget {
  final InventoryItem item;

  const ItemChip({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.rarityColor(item.rarity);
    final borderAlpha = AppColors.glowFor(item.rarity).borderAlpha;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: borderAlpha)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A drawn flask rather than Material's cardboard box: the party
          // carries things a traveller carries, and the box icon reads as
          // warehouse software.
          LineIcon(shape: LineIconShape.flask, size: 15, color: color),
          const SizedBox(width: 6),
          Text(item.name, style: Theme.of(context).textTheme.labelMedium),
          // An aura the party noticed before taking the thing, and only that:
          // what it does stays unnamed until a shaman names it.
          if (item.aura?.known ?? false) ...[
            const SizedBox(width: 6),
            Text(
              item.aura!.curse ? 'холодит' : 'греет',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
