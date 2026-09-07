import 'package:flutter/material.dart';

import '../../../../core/constants/ally_flags.dart';
import '../../../../core/constants/world_state_labels.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/game_labels.dart';
import '../../../../core/theme/influence_source.dart';
import '../../../../core/theme/steel_palette.dart';
import '../../../../core/widgets/rarity_frame.dart';
import '../../../../core/widgets/stat_chip.dart';
import '../../../../game_engine/models/models.dart';

/// The full picture of one character, opened by tapping their card in the
/// roster.
///
/// This exists so the game screen doesn't have to. During a match the roster
/// shows only *that something is there* (see `PlayerStatusPanel`); the
/// moment a player asks "почему у меня появился этот вариант?" or "откуда
/// этот эффект?", this is where the answer lives — descriptions, durations,
/// what an ally actually does for you.
///
/// Written to read like a dossier rather than a data dump: sections in a
/// fixed narrative order (кто ты → что ты умеешь → что на тебе → что у тебя
/// → что о вас помнит мир), and every entry pairs a name with a sentence
/// instead of a bare value.
///
/// [partyInventory] and [worldState] are party-wide, not this player's — see
/// the note on `_PartySection`. They're passed in anyway because the
/// question the sheet answers ("почему это происходит со мной?") is very
/// often answered by something the whole party owns or did.
Future<void> showPlayerProfileSheet({
  required BuildContext context,
  required Player player,
  required Origin? origin,
  required List<InventoryItem> partyInventory,
  required WorldState worldState,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _PlayerProfile(
      player: player,
      origin: origin,
      partyInventory: partyInventory,
      worldState: worldState,
    ),
  );
}

class _PlayerProfile extends StatelessWidget {
  final Player player;
  final Origin? origin;
  final List<InventoryItem> partyInventory;
  final WorldState worldState;

  const _PlayerProfile({
    required this.player,
    required this.origin,
    required this.partyInventory,
    required this.worldState,
  });

  @override
  Widget build(BuildContext context) {
    final allies = [
      for (final entry in allyFlags.entries)
        if (worldState.flag(entry.key)) entry.value,
    ];
    final worldStates = [
      for (final entry in worldStateLabels.entries)
        if (worldState.flag(entry.key)) entry.value,
    ];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            _Header(player: player, origin: origin),
            const SizedBox(height: 24),
            _OriginSection(origin: origin),
            const SizedBox(height: 24),
            _StatsSection(stats: player.stats),
            if (player.activeEffects.isNotEmpty) ...[
              const SizedBox(height: 24),
              _EffectsSection(player: player),
            ],
            if (player.inventory.isNotEmpty || partyInventory.isNotEmpty) ...[
              const SizedBox(height: 24),
              _ItemsSection(personal: player.inventory, party: partyInventory),
            ],
            if (allies.isNotEmpty || worldStates.isNotEmpty) ...[
              const SizedBox(height: 24),
              _PartySection(allies: allies, worldStates: worldStates),
            ],
          ],
        ),
      ),
    );
  }
}

/// Portrait, name, and — once it is known — the origin as an epithet under
/// the name.
///
/// The epithet used to be left out deliberately, because repeating the
/// origin here and again in the section below read as a stutter. It earns
/// its place now that the two are shaped differently: this is a title the
/// character carries, in small caps under their name, while the section
/// below is the explanation. Before the reveal there is no line at all —
/// not a placeholder, which would be a worse stutter than the one avoided.
class _Header extends StatelessWidget {
  final Player player;
  final Origin? origin;

  const _Header({required this.player, required this.origin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final origin = this.origin;
    // The ring is the only thing on the portrait that knows about rarity;
    // before the reveal it is plain steel rather than absent, so the shape
    // does not change when an origin lands.
    final ringColor = origin == null
        ? SteelPalette.steel.withValues(alpha: 0.4)
        : AppColors.rarityColor(origin.rarity);

    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF14171B),
            border: Border.all(color: ringColor),
          ),
          foregroundDecoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(0, -0.2),
              radius: 0.9,
              colors: [
                ringColor.withValues(alpha: 0.16),
                ringColor.withValues(alpha: 0),
              ],
            ),
          ),
          child: Text(
            player.name.isEmpty ? '?' : player.name[0].toUpperCase(),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 29,
              fontWeight: FontWeight.w600,
              color: SteelPalette.textHigh,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          player.name,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 27,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.81,
          ),
        ),
        if (origin != null) ...[
          const SizedBox(height: 7),
          Text(
            originDisplayName(origin.name).toUpperCase(),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              letterSpacing: 2.73,
              color: SteelPalette.textLow.withValues(alpha: 0.62),
            ),
          ),
        ],
      ],
    );
  }
}

/// Section heading: the title centred between two rules that fade out from
/// it. Every section in the sheet uses this one shape, so the eye can find
/// where a section starts without reading anything.
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(child: _Rule(color: color, fadesInwards: true)),
          const SizedBox(width: 12),
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 9),
          // Not `Flexible`: that would make the title share the row's free
          // space with the two rules three ways, and every heading wrapped
          // mid-word. Inflexible, it takes the width it needs and the rules
          // divide what is left — which is what "centred between two rules"
          // means. The titles are a fixed, short set, so one line is safe.
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.76,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _Rule(color: color, fadesInwards: false)),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final Color color;
  final bool fadesInwards;

  const _Rule({required this.color, required this.fadesInwards});

  @override
  Widget build(BuildContext context) {
    final colors = [color.withValues(alpha: 0), color.withValues(alpha: 0.45)];
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fadesInwards ? colors : colors.reversed.toList(),
        ),
      ),
    );
  }
}

/// A run of dossier entries strung on one vertical line.
///
/// The line is what makes five different sections read as one document
/// rather than five lists: blessings, curses, items, allies and world
/// memory all hang off the same rail, and only the colour of the marker
/// says which kind of thing an entry is.
class _Timeline extends StatelessWidget {
  final List<Widget> children;

  static const double _railX = 5.5;

  const _Timeline({required this.children});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: _railX,
          top: 6,
          bottom: 10,
          child: Container(
            width: 1,
            color: SteelPalette.steel.withValues(alpha: 0.2),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ],
    );
  }
}

/// One entry on the rail: a marker, a name with an optional muted
/// qualifier beside it, and a sentence under both. The uniform shape is
/// what keeps a long profile readable — the eye learns one row.
class _TimelineEntry extends StatelessWidget {
  final Color color;
  final String name;
  final String? qualifier;
  final String description;

  const _TimelineEntry({
    required this.color,
    required this.name,
    required this.description,
    this.qualifier,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SizedBox(
              width: 12,
              height: 12,
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 9,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (qualifier != null)
                      Text(
                        // Upper-cased here rather than in the data: the
                        // same string is a sentence fragment elsewhere.
                        qualifier!.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: color.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OriginSection extends StatelessWidget {
  final Origin? origin;

  const _OriginSection({required this.origin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = InfluenceSource.origin.color;
    final origin = this.origin;

    if (origin == null) {
      return Column(
        children: [
          _SectionTitle(
            icon: Icons.help_outline,
            title: 'ПРОИСХОЖДЕНИЕ',
            color: accent,
          ),
          Text(
            // Same voice as "Происхождение забыто" on the game screen: the
            // character already *is* this, the table simply has not
            // remembered it yet. "Unknown" would describe a blank.
            'Кем ты был — забыто. Путешествие само выберет момент вспомнить.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    final rarityColor = AppColors.rarityColor(origin.rarity);
    final modifiers = origin.statModifiers.entries
        .where((entry) => entry.value != 0)
        .map(
          (entry) =>
              '${entry.value > 0 ? '+' : '−'}${entry.value.abs()} '
              '${StatChip.labelFor(entry.key)}',
        )
        .join(', ');

    return Column(
      children: [
        _SectionTitle(
          icon: InfluenceSource.origin.icon,
          title: 'ПРОИСХОЖДЕНИЕ',
          color: accent,
        ),
        RarityFrame(
          rarity: origin.rarity,
          borderRadius: BorderRadius.circular(14),
          // The fill sits *inside* the frame rather than being the frame's
          // padding. RarityFrame paints its glow behind a box with no
          // background of its own, so on the higher tiers the blur showed
          // straight through the card and turned the interior into a muddy
          // wash. An opaque inner surface keeps the glow outside, where it
          // belongs.
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF14171B),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  originDisplayName(origin.name),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${rarityLabel(origin.rarity)} · '
                          '${originCategoryLabel(origin.category)}'
                      .toUpperCase(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.7,
                    color: rarityColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  origin.description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (modifiers.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    height: 1,
                    color: rarityColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Оставило свой след: $modifiers.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  final PlayerStats stats;

  const _StatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = InfluenceSource.stat.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          icon: InfluenceSource.stat.icon,
          title: 'ХАРАКТЕРИСТИКИ',
          color: accent,
        ),
        // Every stat, including the zeroes the roster card hides — a
        // dossier's job is completeness, and "Хитрость 0" is itself an
        // answer to why a cunning-gated option never appears. A zero is
        // dimmed rather than dropped or flagged: it is still a fact about
        // the character, just not one doing any work today.
        for (final stat in StatType.values)
          _StatRow(stat: stat, value: stats.valueOf(stat), accent: accent),
        const SizedBox(height: 10),
        Text(
          'Проверки характеристик в событиях сравниваются с этими значениями.',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final StatType stat;
  final int value;
  final Color accent;

  const _StatRow({
    required this.stat,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alpha = value == 0 ? 0.45 : 0.9;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: SteelPalette.steel.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            StatChip.iconFor(stat),
            size: 16,
            color: accent.withValues(alpha: alpha),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              StatChip.labelFor(stat),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: SteelPalette.textLow.withValues(alpha: alpha),
              ),
            ),
          ),
          Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: SteelPalette.textHigh.withValues(alpha: alpha),
            ),
          ),
        ],
      ),
    );
  }
}

/// Blessings and curses in one section, split by polarity.
///
/// They are one system in the engine — `Player.blessings`/`curses` are
/// derived from `activeEffects` by `EffectPolarity`, there is no separate
/// "buff" list — so showing them as two independent sections would put the
/// same data on screen twice under different names.
class _EffectsSection extends StatelessWidget {
  final Player player;

  const _EffectsSection({required this.player});

  @override
  Widget build(BuildContext context) {
    final blessings = player.blessings;
    final curses = player.curses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (blessings.isNotEmpty) ...[
          _SectionTitle(
            icon: Icons.auto_awesome,
            title: 'БЛАГОСЛОВЕНИЯ',
            color: AppColors.positiveEffectColor,
          ),
          _Timeline(
            children: [
              for (final effect in blessings)
                _TimelineEntry(
                  color: AppColors.positiveEffectColor,
                  name: effect.name,
                  qualifier: _durationLabel(effect),
                  description: effect.description,
                ),
            ],
          ),
        ],
        if (curses.isNotEmpty) ...[
          if (blessings.isNotEmpty) const SizedBox(height: 10),
          _SectionTitle(
            icon: Icons.dangerous_outlined,
            title: 'ПРОКЛЯТИЯ',
            color: AppColors.negativeEffectColor,
          ),
          _Timeline(
            children: [
              for (final effect in curses)
                _TimelineEntry(
                  color: AppColors.negativeEffectColor,
                  name: effect.name,
                  qualifier: _durationLabel(effect),
                  description: effect.description,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// "Сколько ещё это на мне висит" is the single most common question about
/// an effect, and until now the answer existed only in the engine.
String _durationLabel(GameEffect effect) {
  if (effect.isIndefinite || !effect.autoExpire) return 'до конца путешествия';
  final turns = effect.remainingTurns;
  if (turns <= 1) return 'последний ход';
  return 'ещё $turns ${_turnWord(turns)}';
}

String _turnWord(int turns) {
  final lastTwo = turns % 100;
  final last = turns % 10;
  if (lastTwo >= 11 && lastTwo <= 14) return 'ходов';
  if (last == 1) return 'ход';
  if (last >= 2 && last <= 4) return 'хода';
  return 'ходов';
}

class _ItemsSection extends StatelessWidget {
  final List<InventoryItem> personal;
  final List<InventoryItem> party;

  const _ItemsSection({required this.personal, required this.party});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          icon: InfluenceSource.item.icon,
          title: 'ПРЕДМЕТЫ',
          color: InfluenceSource.item.color,
        ),
        _Timeline(
          children: [
            for (final item in personal) _itemEntry(item, shared: false),
            for (final item in party) _itemEntry(item, shared: true),
          ],
        ),
      ],
    );
  }

  /// Party gear is listed here too, marked as shared: the player asking
  /// "чем я могу заплатить?" needs both piles in one place, and
  /// `ItemOwnership` is exactly the distinction that decides whether an
  /// option is available to them personally.
  Widget _itemEntry(InventoryItem item, {required bool shared}) {
    final qualifier = [
      rarityLabel(item.rarity).toLowerCase(),
      if (shared) 'общее',
      if (item.isConsumable) 'одноразовый',
    ].join(' · ');

    return _TimelineEntry(
      color: AppColors.rarityColor(item.rarity),
      name: item.name,
      qualifier: qualifier,
      description: item.description,
    );
  }
}

/// Allies and world memory.
///
/// Deliberately headed as being about the whole party: these are
/// `WorldState` flags, identical for every player, so presenting them as
/// this character's possessions would be a lie — the pirate captain is
/// friends with the *company*, not with one of its members. They belong in
/// a personal dossier anyway, because "почему этот вариант появился" is
/// answered by them just as often as by anything the player owns.
class _PartySection extends StatelessWidget {
  final List<({String name, String description})> allies;
  final List<({String name, String description, WorldStanding standing})>
  worldStates;

  const _PartySection({required this.allies, required this.worldStates});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (allies.isNotEmpty) ...[
          _SectionTitle(
            icon: InfluenceSource.ally.icon,
            title: 'СОЮЗНИКИ КОМПАНИИ',
            color: InfluenceSource.ally.color,
          ),
          _Timeline(
            children: [
              for (final ally in allies)
                _TimelineEntry(
                  color: InfluenceSource.ally.color,
                  name: ally.name,
                  description: ally.description,
                ),
            ],
          ),
        ],
        if (worldStates.isNotEmpty) ...[
          if (allies.isNotEmpty) const SizedBox(height: 10),
          _SectionTitle(
            icon: InfluenceSource.world.icon,
            title: 'МИР ПОМНИТ',
            color: InfluenceSource.world.color,
          ),
          _Timeline(
            children: [
              for (final state in worldStates)
                _TimelineEntry(
                  color: switch (state.standing) {
                    WorldStanding.favorable => AppColors.positiveEffectColor,
                    WorldStanding.hostile => AppColors.negativeEffectColor,
                    WorldStanding.neutral => InfluenceSource.world.color,
                  },
                  name: state.name,
                  qualifier: switch (state.standing) {
                    WorldStanding.favorable => 'благосклонность',
                    WorldStanding.hostile => 'вражда',
                    WorldStanding.neutral => null,
                  },
                  description: state.description,
                ),
            ],
          ),
          Text(
            'Это память о всей компании — её знают и те, кого вы ещё не '
            'встречали.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
