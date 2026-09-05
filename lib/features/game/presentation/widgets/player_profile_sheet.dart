import 'package:flutter/material.dart';

import '../../../../core/constants/ally_flags.dart';
import '../../../../core/constants/world_state_labels.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/game_labels.dart';
import '../../../../core/theme/influence_source.dart';
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
            _Header(player: player),
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
              _ItemsSection(
                personal: player.inventory,
                party: partyInventory,
              ),
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

/// Avatar and name only. The origin deliberately isn't repeated here even
/// though it's the character's identity — it gets the whole section directly
/// below, and showing the name in both places made the top of the sheet read
/// as a stutter.
class _Header extends StatelessWidget {
  final Player player;

  const _Header({required this.player});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarColor = AppColors.playerAvatarColor(player.id);
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: avatarColor.withValues(alpha: 0.25),
          child: Text(
            player.name.isEmpty ? '?' : player.name[0].toUpperCase(),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: avatarColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(player.name, style: theme.textTheme.headlineSmall),
        ),
      ],
    );
  }
}

/// Section heading — an accent-tinted icon plus the title, the same shape
/// `JourneyLogSheet` uses for its own header, so the two sheets read as
/// parts of one interface.
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// One dossier entry: a name, an optional muted qualifier on the same line
/// (rarity, remaining turns, "общее"), and a sentence under it. The uniform
/// shape is what keeps a long profile readable — the eye learns one row.
class _ProfileEntry extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String name;
  final String? qualifier;
  final String description;

  const _ProfileEntry({
    required this.icon,
    required this.color,
    required this.name,
    required this.description,
    this.qualifier,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (qualifier != null)
                      Text(
                        qualifier!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.help_outline,
            title: 'ПРОИСХОЖДЕНИЕ',
            color: theme.colorScheme.onSurfaceVariant,
          ),
          Text(
            'Кто ты на самом деле — пока неизвестно. Путешествие само выберет '
            'момент, когда это выяснится.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
          ),
        ],
      );
    }

    final modifiers = origin.statModifiers.entries
        .where((entry) => entry.value != 0)
        .map(
          (entry) =>
              '${entry.value > 0 ? '+' : '−'}${entry.value.abs()} '
              '${StatChip.labelFor(entry.key)}',
        )
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: InfluenceSource.origin.icon,
          title: 'ПРОИСХОЖДЕНИЕ',
          color: accent,
        ),
        RarityFrame(
          rarity: origin.rarity,
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                origin.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${rarityLabel(origin.rarity)} · '
                '${originCategoryLabel(origin.category)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.rarityColor(origin.rarity),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                origin.description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
              if (modifiers.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Оставило свой след: $modifiers.',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: InfluenceSource.stat.icon,
          title: 'ХАРАКТЕРИСТИКИ',
          color: InfluenceSource.stat.color,
        ),
        // Every stat, including the zeroes the roster card hides — a
        // dossier's job is completeness, and "Хитрость 0" is itself an
        // answer to why a cunning-gated option never appears.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final stat in StatType.values)
              StatChip(stat: stat, value: stats.valueOf(stat)),
          ],
        ),
        const SizedBox(height: 8),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (blessings.isNotEmpty) ...[
          _SectionTitle(
            icon: Icons.auto_awesome,
            title: 'БЛАГОСЛОВЕНИЯ',
            color: AppColors.positiveEffectColor,
          ),
          for (final effect in blessings)
            _ProfileEntry(
              icon: Icons.auto_awesome,
              color: AppColors.positiveEffectColor,
              name: effect.name,
              qualifier: _durationLabel(effect),
              description: effect.description,
            ),
        ],
        if (curses.isNotEmpty) ...[
          if (blessings.isNotEmpty) const SizedBox(height: 10),
          _SectionTitle(
            icon: Icons.dangerous_outlined,
            title: 'ПРОКЛЯТИЯ',
            color: AppColors.negativeEffectColor,
          ),
          for (final effect in curses)
            _ProfileEntry(
              icon: Icons.dangerous_outlined,
              color: AppColors.negativeEffectColor,
              name: effect.name,
              qualifier: _durationLabel(effect),
              description: effect.description,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: InfluenceSource.item.icon,
          title: 'ПРЕДМЕТЫ',
          color: InfluenceSource.item.color,
        ),
        for (final item in personal) _itemEntry(item, shared: false),
        for (final item in party) _itemEntry(item, shared: true),
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

    return _ProfileEntry(
      icon: shared ? Icons.groups_outlined : Icons.inventory_2_outlined,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (allies.isNotEmpty) ...[
          _SectionTitle(
            icon: InfluenceSource.ally.icon,
            title: 'СОЮЗНИКИ КОМПАНИИ',
            color: InfluenceSource.ally.color,
          ),
          for (final ally in allies)
            _ProfileEntry(
              icon: InfluenceSource.ally.icon,
              color: InfluenceSource.ally.color,
              name: ally.name,
              description: ally.description,
            ),
        ],
        if (worldStates.isNotEmpty) ...[
          if (allies.isNotEmpty) const SizedBox(height: 10),
          _SectionTitle(
            icon: InfluenceSource.world.icon,
            title: 'МИР ПОМНИТ',
            color: InfluenceSource.world.color,
          ),
          for (final state in worldStates)
            _ProfileEntry(
              icon: switch (state.standing) {
                WorldStanding.favorable => Icons.favorite_border,
                WorldStanding.hostile => Icons.local_fire_department_outlined,
                WorldStanding.neutral => InfluenceSource.world.icon,
              },
              color: switch (state.standing) {
                WorldStanding.favorable => AppColors.positiveEffectColor,
                WorldStanding.hostile => AppColors.negativeEffectColor,
                WorldStanding.neutral => InfluenceSource.world.color,
              },
              name: state.name,
              description: state.description,
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
