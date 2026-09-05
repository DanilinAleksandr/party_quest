import 'package:flutter/material.dart';

/// Which game system is responsible for an option existing, or for an event
/// unfolding differently than it otherwise would.
///
/// This is one shared visual language rather than a badge per system: the
/// player learns five colors once and can then read *why* something is on
/// screen without reading any prose. That's the whole point — the color and
/// icon carry the meaning, so the pill's text can stay a single short word.
///
/// Each entry deliberately reuses the icon its concept already has
/// elsewhere in the app — `auto_awesome` from the origin-reveal moment,
/// `handshake_outlined` from `ResultKind.allyGained`'s result card,
/// `trending_up` from `statChanged` — so a symbol means the same thing on
/// every screen it appears on.
enum InfluenceSource {
  /// 🟣 The acting player's origin — see `CurrentPlayerHasOriginCondition`.
  origin(
    label: 'Происхождение',
    icon: Icons.auto_awesome,
    color: Color(0xFF9B7BC4),
  ),

  /// 🟢 Something the player or the party is carrying.
  item(
    label: 'Предмет',
    icon: Icons.inventory_2_outlined,
    color: Color(0xFF6FA86B),
  ),

  /// 🔵 A standing alliance — see `allyFlags`.
  ally(
    label: 'Союзник',
    icon: Icons.handshake_outlined,
    color: Color(0xFF5E96C4),
  ),

  /// 🟠 A characteristic high enough to matter here.
  stat(
    label: 'Характеристика',
    icon: Icons.trending_up,
    color: Color(0xFFC98A4B),
  ),

  /// 🌍 The state of the world: a past decision remembered, a finished
  /// adventure, a faction's attitude, a consequence that has had time to
  /// ripen.
  world(label: 'Мир', icon: Icons.public, color: Color(0xFF7FA8A0));

  const InfluenceSource({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}
