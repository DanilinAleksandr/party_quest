import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dialog_shell.dart';
import '../../../../game_engine/models/models.dart';

/// Shown when a drawn card's event needs the table to pick a player by hand
/// (a volunteer, or someone the group names) — see `ChosenParticipant`. The
/// card's own title/description carries the framing ("Кто идёт к
/// ведьме?"), this dialog just turns that into a tap. Not dismissible by
/// tapping outside — the step cannot proceed until someone is picked.
Future<void> showParticipantSelectionDialog({
  required BuildContext context,
  required GameCard card,
  required List<Player> players,
  required void Function(String playerId) onSelect,
}) {
  return showAppDialog<void>(
    context: context,
    icon: Icons.how_to_vote_outlined,
    title: card.title,
    barrierDismissible: false,
    content: Text(
      card.description,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge,
    ),
    actions: [
      for (final player in players)
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onSelect(player.id);
          },
          icon: CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.playerAvatarColor(
              player.id,
            ).withValues(alpha: 0.3),
            child: Text(
              player.name.isEmpty ? '?' : player.name[0].toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.playerAvatarColor(player.id),
              ),
            ),
          ),
          label: Text(player.name),
        ),
    ],
  );
}
