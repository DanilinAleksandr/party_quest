import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/steel_palette.dart';
import '../../../../core/widgets/app_dialog_shell.dart';
import '../../../../core/widgets/event_participant_banner.dart';
import '../../../../core/widgets/influence_badge.dart';
import '../../../../game_engine/logic/logic.dart';
import '../../../../game_engine/models/models.dart';

/// The mark of an adventure with none of its own.
const IconData kAdventureFallbackIcon = Icons.auto_stories_outlined;

/// Presents one step of an adventure. `AdventureEngine` only ever hands the
/// UI a node that has at least one eligible choice — nodes with no player
/// input auto-cascade inside the engine and are never shown — so, unlike
/// [showCardResolutionDialog], there is no "just an OK button" case here.
///
/// Styled apart from an ordinary event card, which takes its type's colour:
/// an adventure is headed by its own name, [title], and its own mark,
/// [iconAsset] (see `kAdventureIcons`), in steel — the colour of the rest
/// of the interface. Gold is the palette's colour for rarity and nothing
/// else, so an adventure is gold only when the card that opened it was
/// legendary ([rarity]). The book is left only for one without a mark.
///
/// [participants] is who the adventure's originating card resolved to
/// (unchanged for the whole adventure) — null means "the whole party", see
/// [EventParticipantBanner].
///
/// Options carry [InfluenceBadge]s for whatever unlocked them, exactly as in
/// the card dialog — this is where they matter most, since an adventure's
/// branches are the densest concentration of origin/item/stat-gated choices
/// in the game.

Future<void> showAdventureNodeDialog({
  required BuildContext context,
  required AdventureNode node,
  required List<Player>? participants,
  required void Function(int choiceIndex) onChoice,
  required String title,
  String? iconAsset,
  Rarity? rarity,
  OriginCatalog? origins,
  Map<String, String>? adventureNames,
}) {
  return showAppDialog<void>(
    context: context,
    icon: kAdventureFallbackIcon,
    iconAsset: iconAsset,
    title: title,
    accentColor: rarity == Rarity.legendary
        ? AppColors.rarityColor(Rarity.legendary)
        : SteelPalette.steel,
    barrierDismissible: false,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EventParticipantBanner(players: participants),
        Text(
          node.text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
    actions: [
      for (var i = 0; i < node.choices.length; i++)
        InfluenceGatedAction(
          label: node.choices[i].label,
          tags: influenceTagsOf(
            node.choices[i].conditions,
            origins: origins,
            adventureNames: adventureNames,
          ),
          onPressed: () {
            Navigator.of(context).pop();
            onChoice(i);
          },
        ),
    ],
  );
}
