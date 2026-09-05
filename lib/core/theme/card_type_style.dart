import 'package:flutter/material.dart';

import '../../game_engine/models/models.dart';

/// Icon/color per [CardType] — shared between the card resolution dialog
/// and the journey log sheet so a card's visual identity stays consistent
/// wherever it's shown, instead of two independent copies drifting apart.
IconData cardTypeIcon(CardType type) {
  return switch (type) {
    CardType.event => Icons.theater_comedy_outlined,
    CardType.trap => Icons.warning_amber_rounded,
    CardType.curse => Icons.dangerous_outlined,
    CardType.blessing => Icons.auto_awesome,
    CardType.duel => Icons.sports_kabaddi,
    CardType.global => Icons.groups_outlined,
    CardType.item => Icons.inventory_2_outlined,
    CardType.luck => Icons.casino_outlined,
    CardType.legendary => Icons.workspace_premium,
  };
}

Color cardTypeColor(CardType type) {
  return switch (type) {
    CardType.event => const Color(0xFF7C8894),
    CardType.trap => const Color(0xFFD08A3E),
    CardType.curse => const Color(0xFFC96B6B),
    CardType.blessing => const Color(0xFF6FA97A),
    CardType.duel => const Color(0xFFD0703E),
    CardType.global => const Color(0xFF5B8DBE),
    CardType.item => const Color(0xFF3E8E96),
    CardType.luck => const Color(0xFF9B6FC9),
    CardType.legendary => const Color(0xFFD4A94C),
  };
}
