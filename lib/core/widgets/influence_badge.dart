import 'package:flutter/material.dart';

import '../../game_engine/logic/logic.dart';
import '../../game_engine/models/models.dart';
import '../constants/ally_flags.dart';
import '../theme/influence_source.dart';

/// One badge to render: which system, and what to write on it.
///
/// [text] is normally just `source.label` ("Предмет", "Мир"). It carries a
/// *specific* name only where that adds something the player can't already
/// read off the option itself — see [influenceTagsOf].
typedef InfluenceTag = ({InfluenceSource source, String text});

/// Which game systems are the *reason* [conditions] let something through,
/// and how to label each one.
///
/// This works at all because both choice filters — `GameController
/// ._filterCardChoices` and `AdventureEngine` — narrow a list down to the
/// eligible choices while handing the UI the original choice objects with
/// their conditions intact. So the dialog can ask "why did this survive?"
/// without the engine having to carry a flag for it. Nothing here touches
/// game state; it is pure presentation over data that already exists.
///
/// The switch is exhaustive over the sealed [GameCondition] hierarchy on
/// purpose (same reasoning `ContentValidator` documents): a new condition
/// type won't compile until someone decides whether it is a visible
/// influence, which is much better than silently never being badged.
///
/// **Naming policy.** The shared language is the *color and icon*, not the
/// word — so a badge can name a specific thing without breaking it. Only
/// [InfluenceSource.origin] does, and only from
/// [CurrentPlayerHasOriginCondition], for two reasons:
/// - Origin is the one source that is the player's *identity* rather than
///   something they hold or the world's state, so seeing "✦ Волчья кровь"
///   lands differently from "✦ Происхождение".
/// - It is also the one source a choice's own text almost never names,
///   because that text is written in-fiction ("стая узнаёт своих" never
///   says "Волчья кровь"). An item, by contrast, is usually named right in
///   the label ("Протянуть флягу"), so "Предмет" loses nothing.
///
/// [AnyPlayerHasOriginCondition] deliberately stays generic: it means
/// *somebody at the table* is that origin, which may well not be the player
/// this option belongs to — naming it there would misattribute.
///
/// **Three whole families are deliberately *not* badged**, because a badge
/// has to mean "this exists *because of* X" or the language becomes noise:
///
/// 1. *Absences and guards* — `currentPlayerMissingItem`,
///    `currentPlayerLacksOrigin`, `worldFlagUnset`, `notInBiome`,
///    `adventureNotCompleted` and friends. "You don't have one yet" is a
///    reason something is *offered*, not a system exerting influence, and
///    labelling it would actively mislead.
/// 2. *Ambient context already on screen* — `inBiome`, `inWeather`,
///    `inSeason` and their dwell-time variants. `BiomeBanner` already shows
///    the biome and the weather, and the season was announced in its own
///    scene. Nearly every card in the game is biome-gated, so badging these
///    would put a 🌍 pill on almost everything and teach the player to
///    ignore pills.
/// 3. *Table and pacing plumbing* — player counts, step thresholds, journey
///    phase, game mode.
///
/// Effects (`currentPlayerHasEffect`) are a genuine influence and are left
/// unbadged only because they'd need a sixth category that hasn't been
/// designed yet; adding one is a single case here plus an enum entry.
List<InfluenceTag> influenceTagsOf(
  List<GameCondition> conditions, {
  OriginCatalog? origins,
}) {
  // Keyed by source so one option never shows the same pill twice; the
  // first specific name found for a source wins.
  final found = <InfluenceSource, String>{};
  void add(InfluenceSource source, [String? text]) =>
      found.putIfAbsent(source, () => text ?? source.label);

  for (final condition in conditions) {
    switch (condition) {
      case CurrentPlayerHasOriginCondition c:
        add(InfluenceSource.origin, _originName(c.originId, origins));

      case AnyPlayerHasOriginCondition _:
        add(InfluenceSource.origin);

      case CurrentPlayerHasItemCondition _:
      case PartyHasItemCondition _:
      case AnyPlayerHasItemCondition _:
        add(InfluenceSource.item);

      case CurrentPlayerStatAtLeastCondition _:
      case AnyPlayerStatAtLeastCondition _:
        add(InfluenceSource.stat);

      // An alliance is just a world flag; `allyFlags` is what makes it
      // recognisable as one. Anything else remembered about the world is
      // world influence. Stays generic even though `allyFlags` knows the
      // ally's name: ally-gated content almost always names them in the
      // text already ("капитан узнаёт вас издалека"), so the naming rule
      // above doesn't apply.
      case WorldFlagSetCondition c:
        add(
          allyFlags.containsKey(c.flag)
              ? InfluenceSource.ally
              : InfluenceSource.world,
        );

      case AdventureCompletedCondition _:
      case MinimumStepsSinceFlagCondition _:
      case GlobalModifierAtLeastCondition _:
        add(InfluenceSource.world);

      // --- deliberately unbadged, see the doc comment above ---
      case PartyMissingItemCondition _:
      case CurrentPlayerMissingItemCondition _:
      case CurrentPlayerMissingEffectCondition _:
      case AnyPlayerMissingOriginCondition _:
      case CurrentPlayerOriginUnknownCondition _:
      case CurrentPlayerLacksOriginCondition _:
      case WorldFlagUnsetCondition _:
      case AdventureNotCompletedCondition _:
      case NotInBiomeCondition _:
      case NotInWeatherCondition _:
      case NotInSeasonCondition _:
      case LeaderIsUnsetCondition _:
      case InBiomeCondition _:
      case InWeatherCondition _:
      case InSeasonCondition _:
      case MinimumTurnsInBiomeCondition _:
      case MinimumTurnsInWeatherCondition _:
      case MinimumTurnsInTavernCondition _:
      case MinimumPlayersCondition _:
      case MaximumPlayersCondition _:
      case MinimumStepCondition _:
      case MaximumStepCondition _:
      case GameModeCondition _:
      case InPhaseCondition _:
      case CurrentPlayerHasEffectCondition _:
      case AnyPlayerHasEffectCondition _:
      case LeaderIsSetCondition _:
        break;
    }
  }

  // Enum order, so a given combination always reads the same way.
  return [
    for (final source in InfluenceSource.values)
      if (found.containsKey(source)) (source: source, text: found[source]!),
  ];
}

/// Just the systems involved, without labels — for classification and tests.
List<InfluenceSource> influencesOf(List<GameCondition> conditions) =>
    [for (final tag in influenceTagsOf(conditions)) tag.source];

/// `Origin.name` already carries its own emoji, so it needs no decoration.
/// Falls back to the generic word when the catalog is absent or doesn't know
/// the id — a missing flavor lookup must never cost the player the badge.
String? _originName(String originId, OriginCatalog? origins) {
  if (origins == null || !origins.contains(originId)) return null;
  return origins.byId(originId).name;
}

/// One small pill naming the system behind something.
///
/// Built from the same vocabulary every other pill in the app uses (a
/// rounded 20 container, background at 0.14 alpha, border at 0.4 — see
/// `EventParticipantBanner`), so it reads as part of the existing interface
/// rather than a new decoration.
class InfluenceBadge extends StatelessWidget {
  final InfluenceTag tag;

  const InfluenceBadge({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tag.source.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tag.source.icon, size: 12, color: color),
          const SizedBox(width: 4),
          // Origin names run to ~27 characters ("👑 Наследник древних
          // королей"), so the text yields rather than overflowing on a
          // narrow phone. It is allowed a second line before it is allowed
          // an ellipsis: a name cut mid-word ("👑 Наследник древн…") is
          // worse than a slightly taller pill, and the badge sits on its
          // own line above the button anyway, so growing costs nothing.
          Flexible(
            child: Text(
              tag.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              // Stays `labelSmall`. Raising it to `labelMedium` buys one
              // logical pixel of height (11sp → 12sp) and costs the
              // no-truncation guarantee above: the longest origin name then
              // needs a third line to avoid an ellipsis. Not worth it.
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Every system behind one option/event, laid out in a row that wraps.
/// Renders nothing at all when [tags] is empty, so callers can drop it in
/// unconditionally.
class InfluenceBadgeRow extends StatelessWidget {
  final List<InfluenceTag> tags;

  const InfluenceBadgeRow({super.key, required this.tags});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [for (final tag in tags) InfluenceBadge(tag: tag)],
    );
  }
}

/// One dialog action: the choice's button, with its influence badges just
/// above it.
///
/// The badges sit *outside* the button rather than inside on purpose — a
/// `FilledButton` is already a solid block of accent color, and tinted pills
/// on top of that go muddy at this size. Above the button they keep full
/// contrast while staying unambiguously attached to the option they explain.
///
/// Emphasis follows the same signal: an option a system opened for *this*
/// party is filled, an option anyone would have is outlined. A card can
/// offer up to fourteen choices, and a stack of that many identical solid
/// blocks gives the eye nothing to sort by — the rare option should not
/// look exactly like "пройти мимо". Both button themes already share the
/// same padding and corner radius (see `AppTheme`), so this changes only
/// emphasis, never layout.
///
/// Labels are left-aligned because 58% of them run past 40 characters and
/// wrap to two or three lines; centered wrapped text inside a button is
/// slower to scan than a flush left edge shared by every option.
class InfluenceGatedAction extends StatelessWidget {
  final String label;
  final List<InfluenceTag> tags;
  final VoidCallback onPressed;

  const InfluenceGatedAction({
    super.key,
    required this.label,
    required this.tags,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(label, textAlign: TextAlign.start);
    const alignLeft = Alignment.centerLeft;

    if (tags.isEmpty) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(alignment: alignLeft),
        child: text,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: InfluenceBadgeRow(tags: tags),
        ),
        FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(alignment: alignLeft),
          child: text,
        ),
      ],
    );
  }
}
