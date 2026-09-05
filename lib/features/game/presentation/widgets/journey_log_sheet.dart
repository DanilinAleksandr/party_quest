import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/card_type_style.dart';
import '../../../../game_engine/models/models.dart';

/// A scrollable recap of every step resolved so far this match — reads
/// `GameState.journeyLog` (oldest first), shown newest-first since that's
/// what a player checking mid-game actually wants to see.
Future<void> showJourneyLogSheet({
  required BuildContext context,
  required List<JourneyLogEntry> journeyLog,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final entries = journeyLog.reversed.toList();
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.menu_book_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text('Журнал путешествия', style: theme.textTheme.titleLarge),
                  ],
                ),
              ),
              Flexible(
                child: entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        child: Text(
                          'Путешествие только начинается — записей пока нет.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const Divider(height: 20),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final color = entry.rarity != null
                              ? AppColors.rarityColor(entry.rarity!)
                              : cardTypeColor(entry.type);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  cardTypeIcon(entry.type),
                                  size: 16,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  entry.text,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );
}
