import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/card_type_style.dart';
import '../../../../core/widgets/app_dialog_shell.dart';
import '../../../../core/widgets/event_participant_banner.dart';
import '../../../../core/widgets/influence_badge.dart';
import '../../../../game_engine/logic/logic.dart';
import '../../../../game_engine/models/models.dart';

/// Presents the drawn card. Cards without choices show a single
/// acknowledgement button; cards with choices show one button per
/// [CardChoice]. Not dismissible by tapping outside — the turn cannot
/// proceed until the player resolves the card.
///
/// [participants] is who the event was already resolved to before this
/// dialog opened (null means "the whole party") — see
/// [EventParticipantBanner].
///
/// Every option carries [InfluenceBadge]s for the systems that put it there
/// (see [influenceTagsOf]); the card itself carries them too, since a card
/// can be gated as a whole — `origin_reactions.json` and
/// `hard_past_reactions.json` cards only ever draw for one origin, and
/// "мир помнит" callbacks only for a party with the right history, neither
/// of which the player could otherwise know.
///
/// [origins] lets an origin badge name the origin itself ("✦ Волчья кровь")
/// instead of the category word. Optional: without it the badges still
/// appear, just generically — the catalog is flavor, never a gate.
Future<void> showCardResolutionDialog({
  required BuildContext context,
  required GameCard card,
  required List<Player>? participants,
  required void Function(int? choiceIndex) onResolve,
  OriginCatalog? origins,
}) {
  final cardTags = influenceTagsOf(card.conditions, origins: origins);

  return showAppDialog<void>(
    context: context,
    icon: cardTypeIcon(card.type),
    title: card.title,
    accentColor: _accentFor(card),
    rarity: card.rarity,
    barrierDismissible: false,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EventParticipantBanner(players: participants),
        if (cardTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InfluenceBadgeRow(tags: cardTags),
          ),
        // The scene text is left-aligned, not centered: descriptions run to
        // a median of ~134 characters and half of them are two paragraphs,
        // and centered body copy starts every line at a different x, so the
        // eye has to re-find the line start on each wrap. The title above
        // stays centered — it is a single-line heading, not body copy.
        // `double.infinity` makes the block fill the dialog so the alignment
        // is actually visible; without it a short description would still be
        // centered as a block by the surrounding Column.
        SizedBox(
          width: double.infinity,
          child: Text(
            card.description,
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    ),
    actions: card.hasChoices
        ? [
            for (var i = 0; i < card.choices.length; i++)
              InfluenceGatedAction(
                label: card.choices[i].label,
                tags: influenceTagsOf(
                  card.choices[i].conditions,
                  origins: origins,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onResolve(i);
                },
              ),
          ]
        : [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                onResolve(null);
              },
              child: const Text('Понятно'),
            ),
          ],
  );
}

/// Rarity dominates the accent for the tiers that are meant to feel like a
/// big deal — a legendary/epic card reads as "legendary/epic" first and
/// "curse/blessing/whatever" second. Below that, the card's [CardType]
/// carries the color, since most draws are ordinary and type is the more
/// useful signal moment to moment.
Color _accentFor(GameCard card) {
  if (AppColors.dominatesTypeAccent(card.rarity)) {
    return AppColors.rarityColor(card.rarity);
  }
  return cardTypeColor(card.type);
}
