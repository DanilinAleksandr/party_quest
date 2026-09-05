import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';
import '../theme/app_colors.dart';

/// Answers playtest note #3 ("кто участник события?") right at the top of
/// the card/adventure dialog, before the description — a small avatar+name
/// row for the one or two players the event is about, or a "🌍 Вся
/// компания" pill when it targets everyone.
///
/// Deliberately dumb: it takes the already-resolved player(s) rather than an
/// [EventParticipant], since resolution already happened before the dialog
/// was shown (`GameState.currentPlayer`/`.secondaryPlayer`) — this widget
/// only has to render the outcome.
class EventParticipantBanner extends StatelessWidget {
  /// Null renders the "🌍 Вся компания" pill instead of any player badges.
  final List<Player>? players;

  const EventParticipantBanner({super.key, required this.players});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final players = this.players;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: players == null
            ? _pill(
                theme,
                color: theme.colorScheme.primary,
                child: Text(
                  '🌍 Вся компания',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final player in players) _playerBadge(theme, player),
                ],
              ),
      ),
    );
  }

  Widget _playerBadge(ThemeData theme, Player player) {
    final color = AppColors.playerAvatarColor(player.id);
    return _pill(
      theme,
      color: color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: color.withValues(alpha: 0.3),
            child: Text(
              player.name.isEmpty ? '?' : player.name[0].toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            player.name,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(ThemeData theme, {required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}
