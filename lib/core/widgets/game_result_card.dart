import 'package:flutter/material.dart';

import '../../features/game/application/result_entry.dart';
import '../theme/app_colors.dart';

/// Identifies the result card's content container — lets tests find "is a
/// result card open" the same way `appDialogContentKey` does for the
/// story dialogs, without matching on the "Продолжить" button text (which
/// several other dialogs could plausibly reuse).
const Key gameResultCardKey = Key('game_result_card');

/// Shows one [ResultEntry] as its own full "карточка результата" moment —
/// icon, category title, who it happened to (if anyone in particular), the
/// headline (item/effect/origin name, or a stat delta), and a single
/// "Продолжить" button. Answers the playtest note that small toasts made
/// rewards easy to miss: every real change now gets a moment a player has
/// to actively acknowledge, the same weight a card/adventure dialog gets.
///
/// Callers walk a `List<ResultEntry>` and `await` this once per entry, so
/// several changes from one event show up as a short sequence of these
/// cards rather than a single crowded screen — "каждая награда ощущается
/// как отдельный момент."
Future<void> showGameResultCard(BuildContext context, ResultEntry entry) {
  final style = _styleFor(entry.kind, entry.isNegative);
  final accentColor = entry.rarity != null
      ? AppColors.rarityColor(entry.rarity!)
      : style.color;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final theme = Theme.of(context);
      final borderRadius = BorderRadius.circular(20);
      final inner = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.16),
            ),
            child: Icon(style.icon, color: accentColor, size: 32),
          ),
          const SizedBox(height: 16),
          Text(style.title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          if (entry.playerName != null) ...[
            const SizedBox(height: 4),
            Text(
              entry.playerName!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            entry.headline,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (entry.description != null) ...[
            const SizedBox(height: 8),
            Text(
              entry.description!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Продолжить'),
            ),
          ),
        ],
      );

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              key: gameResultCardKey,
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: borderRadius,
              elevation: 8,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  border: Border.all(color: accentColor.withValues(alpha: 0.55)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: inner,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ResultStyle {
  final IconData icon;
  final String title;
  final Color color;

  const _ResultStyle({required this.icon, required this.title, required this.color});
}

_ResultStyle _styleFor(ResultKind kind, bool isNegative) {
  return switch (kind) {
    ResultKind.itemGained => const _ResultStyle(
      icon: Icons.card_giftcard,
      title: '🎁 Получен предмет',
      color: AppColors.positiveEffectColor,
    ),
    ResultKind.itemLost => const _ResultStyle(
      icon: Icons.remove_circle_outline,
      title: 'Предмет потерян',
      color: Color(0xFF9AA0A6),
    ),
    ResultKind.effectGained => isNegative
        ? const _ResultStyle(
            icon: Icons.dangerous_outlined,
            title: '⚠ Получено проклятие',
            color: AppColors.negativeEffectColor,
          )
        : const _ResultStyle(
            icon: Icons.auto_awesome,
            title: '✨ Получено благословение',
            color: AppColors.positiveEffectColor,
          ),
    ResultKind.effectLost => const _ResultStyle(
      icon: Icons.clear,
      title: 'Эффект закончился',
      color: Color(0xFF9AA0A6),
    ),
    ResultKind.statChanged => isNegative
        ? const _ResultStyle(
            icon: Icons.trending_down,
            title: 'Характеристика изменилась',
            color: AppColors.negativeEffectColor,
          )
        : const _ResultStyle(
            icon: Icons.trending_up,
            title: 'Характеристика изменилась',
            color: AppColors.positiveEffectColor,
          ),
    ResultKind.originRevealed => const _ResultStyle(
      icon: Icons.auto_awesome,
      title: '🌟 Раскрыто происхождение',
      color: Color(0xFFD4A94C),
    ),
    ResultKind.leaderChanged => const _ResultStyle(
      icon: Icons.emoji_events_outlined,
      title: '👑 Новый лидер компании',
      color: Color(0xFFD4A94C),
    ),
    ResultKind.partyItemGained => const _ResultStyle(
      icon: Icons.card_giftcard,
      title: '🎁 Компания получила предмет',
      color: AppColors.positiveEffectColor,
    ),
    ResultKind.partyItemLost => const _ResultStyle(
      icon: Icons.remove_circle_outline,
      title: 'Компания потеряла предмет',
      color: Color(0xFF9AA0A6),
    ),
    ResultKind.allyGained => const _ResultStyle(
      icon: Icons.handshake_outlined,
      title: '🤝 Новый союзник',
      color: AppColors.positiveEffectColor,
    ),
  };
}
