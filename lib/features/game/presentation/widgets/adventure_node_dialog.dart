import 'package:flutter/material.dart';

import '../../../../core/widgets/app_dialog_shell.dart';
import '../../../../core/widgets/event_participant_banner.dart';
import '../../../../core/widgets/influence_badge.dart';
import '../../../../game_engine/logic/logic.dart';
import '../../../../game_engine/models/models.dart';

/// Presents one step of an adventure. `AdventureEngine` only ever hands the
/// UI a node that has at least one eligible choice — nodes with no player
/// input auto-cascade inside the engine and are never shown — so, unlike
/// [showCardResolutionDialog], there is no "just an OK button" case here.
///
/// Deliberately styled apart from an ordinary event card — a fixed
/// "storybook" amber/parchment accent and book icon — so a multi-step
/// adventure reads as a different *kind* of moment at a glance, not just
/// another card.
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
  OriginCatalog? origins,
}) {
  return showAppDialog<void>(
    context: context,
    icon: Icons.auto_stories_outlined,
    title: 'Приключение',
    accentColor: const Color(0xFFC9954B),
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
          tags: influenceTagsOf(node.choices[i].conditions, origins: origins),
          onPressed: () {
            Navigator.of(context).pop();
            onChoice(i);
          },
        ),
    ],
  );
}
