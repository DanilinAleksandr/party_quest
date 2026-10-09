import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/card_type_style.dart';
import '../../../../core/theme/steel_palette.dart';
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
/// [adventureNames] does the same for a remembered adventure — see
/// `rememberedAdventureNames`.
/// What the current player can do for themselves on this card, without
/// answering it — see `GameController.drinkForCourage`/`useItem`.
///
/// [tooDrunk] replaces the drink with a short "Тебе хватит" rather than
/// hiding it, so the player learns why it is gone.
typedef PersonalActionsView = ({
  bool canDrink,
  bool tooDrunk,
  List<InventoryItem> items,
});

/// The dialog's live state: the card as it currently stands — its choices
/// narrowed again after a personal action — and what the player may still
/// do for themselves.
typedef CardDialogView = ({GameCard card, PersonalActionsView? personal});

Future<void> showCardResolutionDialog({
  required BuildContext context,
  required GameCard card,
  required List<Player>? participants,
  required void Function(int? choiceIndex) onResolve,
  OriginCatalog? origins,
  Map<String, String>? adventureNames,
  ValueListenable<CardDialogView>? live,
  VoidCallback? onDrinkForCourage,
  void Function(String itemId)? onUseItem,
  void Function(int choiceIndex)? onInspect,
}) {
  final cardTags = influenceTagsOf(
    card.conditions,
    origins: origins,
    adventureNames: adventureNames,
  );
  final view = live ?? ValueNotifier((card: card, personal: null));

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
    // One live block rather than a fixed list: a drink for courage can open
    // a choice that was not there a moment ago, and the buttons have to
    // show it without the dialog closing and reopening.
    actions: [
      ValueListenableBuilder<CardDialogView>(
        valueListenable: view,
        builder: (context, view, _) {
          final current = view.card;
          final buttons = current.hasChoices
              ? [
                  for (var i = 0; i < current.choices.length; i++)
                    if (current.choices[i].inspect)
                      // A look before deciding, not a decision: the dialog
                      // stays, and comes back without it.
                      LookCloserButton(
                        label: current.choices[i].label,
                        onPressed: onInspect == null
                            ? null
                            : () => onInspect(i),
                      )
                    else
                      InfluenceGatedAction(
                        label: current.choices[i].label,
                        tags: influenceTagsOf(
                          current.choices[i].conditions,
                          origins: origins,
                          adventureNames: adventureNames,
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
                ];
          final personal = view.personal;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (personal != null)
                _PersonalActionsRow(
                  view: personal,
                  onDrink: onDrinkForCourage,
                  onUseItem: onUseItem,
                ),
              for (final button in buttons) ...[
                button,
                if (button != buttons.last) const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    ],
  );
}

/// The player's own moves on a card, above its choices and set apart from
/// them: small, outlined, and worded as things the character does rather
/// than answers to the scene.
class _PersonalActionsRow extends StatelessWidget {
  final PersonalActionsView view;
  final VoidCallback? onDrink;
  final void Function(String itemId)? onUseItem;

  const _PersonalActionsRow({
    required this.view,
    required this.onDrink,
    required this.onUseItem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[
      if (view.canDrink)
        _PersonalChip(
          icon: Icons.sports_bar_outlined,
          label: 'Для храбрости',
          onPressed: onDrink,
        )
      else if (view.tooDrunk)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Тебе хватит',
            style: theme.textTheme.labelMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      for (final item in view.items)
        _PersonalChip(
          icon: Icons.science_outlined,
          label: item.name,
          onPressed: onUseItem == null ? null : () => onUseItem!(item.id),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: chips,
      ),
    );
  }
}

/// The look of a move made before deciding — a closer look, a drink for
/// courage: outlined in a lighter steel than the choices, with an icon, so
/// it reads as something to do first rather than an answer to the scene.
ButtonStyle beforeDecidingStyle(BuildContext context, {bool compact = false}) =>
    OutlinedButton.styleFrom(
      foregroundColor: SteelPalette.textHigh,
      side: BorderSide(
        color: SteelPalette.steel.withValues(alpha: 0.75),
        width: 1.2,
      ),
      backgroundColor: SteelPalette.steel.withValues(alpha: 0.08),
      visualDensity: compact ? VisualDensity.compact : null,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
          : null,
      textStyle: compact ? Theme.of(context).textTheme.labelMedium : null,
    );

/// «Рассмотреть поближе» and its kind, as a full-width button among the
/// choices.
class LookCloserButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const LookCloserButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.search, size: 18),
    label: Text(label),
    style: beforeDecidingStyle(context),
  );
}

class _PersonalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _PersonalChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: beforeDecidingStyle(context, compact: true),
    );
  }
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
