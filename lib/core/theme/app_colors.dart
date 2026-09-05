import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';

/// Pure UI-layer color/icon lookup tables — deliberately *not* part of the
/// `game_engine` models. [Rarity] and [Biome] stay pure identity in the
/// engine (see their own doc comments); how a rarity tier or a biome id
/// looks on screen is a presentation concern, so it lives here instead of
/// growing the domain models a UI dependency.
abstract final class AppColors {
  /// Single source of truth for rarity's visual weight — every rarity-aware
  /// widget (`RarityFrame`, item/effect chips, origin badges, card dialogs)
  /// reads from here so the ramp only has to be tuned in one place.
  static Color rarityColor(Rarity rarity) => switch (rarity) {
    Rarity.common => const Color(0xFF9AA0A6),
    Rarity.uncommon => const Color(0xFF6FA97A),
    Rarity.rare => const Color(0xFF5B8DBE),
    Rarity.epic => const Color(0xFF9B6FC9),
    Rarity.legendary => const Color(0xFFD4A94C),
  };

  /// Whether this rarity tier is rare enough to override a card's [CardType]
  /// color entirely (see `card_resolution_dialog.dart`) — a legendary/epic
  /// card reads as "legendary/epic" first and "curse/blessing/whatever"
  /// second. Deliberately a *different* concern from [glowFor]: this picks
  /// which color wins, [glowFor] shapes how strongly whatever color was
  /// chosen gets rendered.
  static bool dominatesTypeAccent(Rarity rarity) =>
      rarity == Rarity.epic || rarity == Rarity.legendary;

  /// The five-tier glow ramp — "взгляд сразу понимает редкость" without
  /// every tier competing for attention: common is nearly bare, uncommon is
  /// a plain colored border, rare/epic add a static glow of increasing
  /// strength, and only legendary earns the looping pulse. Single source of
  /// truth for [RarityFrame], `OriginBadge`, `AppDialogShell`, and
  /// `ItemChip`'s border weight.
  static RarityGlow glowFor(Rarity rarity) => switch (rarity) {
    Rarity.common => const RarityGlow(
      borderAlpha: 0.22,
      blurRadius: 0,
      shadowAlpha: 0,
      pulse: false,
    ),
    Rarity.uncommon => const RarityGlow(
      borderAlpha: 0.55,
      blurRadius: 0,
      shadowAlpha: 0,
      pulse: false,
    ),
    Rarity.rare => const RarityGlow(
      borderAlpha: 0.7,
      blurRadius: 8,
      shadowAlpha: 0.22,
      pulse: false,
    ),
    Rarity.epic => const RarityGlow(
      borderAlpha: 0.85,
      blurRadius: 13,
      shadowAlpha: 0.38,
      pulse: false,
    ),
    Rarity.legendary => const RarityGlow(
      borderAlpha: 1,
      blurRadius: 16,
      shadowAlpha: 0.55,
      pulse: true,
    ),
  };

  static const Color positiveEffectColor = Color(0xFF6FA97A);
  static const Color negativeEffectColor = Color(0xFFC96B6B);

  /// A stable, arbitrary color per player id — used everywhere a player
  /// needs to read as visually distinct without portrait art (roster cards,
  /// the participant-selection dialog).
  static Color playerAvatarColor(String playerId) =>
      _avatarPalette[playerId.hashCode.abs() % _avatarPalette.length];

  static const List<Color> _avatarPalette = [
    Color(0xFFB0793F),
    Color(0xFF5B8DBE),
    Color(0xFF6FA97A),
    Color(0xFF9B6FC9),
    Color(0xFFC96B6B),
    Color(0xFF3E8E96),
  ];

  /// Keyed by the same `Biome.id` strings already in
  /// `assets/data/biomes/biomes.json` — falls back to a neutral tone for any
  /// id this map hasn't been taught about yet (new biomes ship as content,
  /// not code, so this must never throw).
  static Color biomeColor(String biomeId) =>
      _biomeColors[biomeId] ?? const Color(0xFF7C8894);

  static IconData biomeIcon(String biomeId) =>
      _biomeIcons[biomeId] ?? Icons.map_outlined;

  static const Map<String, Color> _biomeColors = {
    'forest': Color(0xFF4C7A52),
    'desert': Color(0xFFC9954B),
    'tavern': Color(0xFF8B5E3C),
    'graveyard': Color(0xFF5B6B70),
    'mountains': Color(0xFF6E7A8A),
    'coast': Color(0xFF3E8E96),
    // Deliberately not coast's teal: this is still fresh water under a grey
    // sky, not sea. Muted grey-green keeps the two apart at banner size.
    'floodlands': Color(0xFF7E9B8E),
  };

  static const Map<String, IconData> _biomeIcons = {
    'forest': Icons.forest,
    'desert': Icons.wb_sunny_outlined,
    'tavern': Icons.local_bar,
    'graveyard': Icons.church_outlined,
    'mountains': Icons.terrain,
    'coast': Icons.sailing,
    'floodlands': Icons.water,
  };
}

/// How strongly a rarity tier should render — see [AppColors.glowFor].
/// [blurRadius]/[shadowAlpha] of 0 means "no `BoxShadow` at all", not a
/// very faint one, so common/uncommon content pays zero extra paint cost.
final class RarityGlow {
  final double borderAlpha;
  final double blurRadius;
  final double shadowAlpha;
  final bool pulse;

  const RarityGlow({
    required this.borderAlpha,
    required this.blurRadius,
    required this.shadowAlpha,
    required this.pulse,
  });
}
