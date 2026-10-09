import 'package:flutter/material.dart';

import '../../../../game_engine/models/models.dart';

/// Debug only — the game screen offers it under `kDebugMode`, and a release
/// build never shows it. Lists every unseen aura the party carries, and
/// hands a player a cursed thing of a chosen kind and weight, so a curse
/// can be watched at work without waiting for one to turn up.
Future<void> showDebugAuraSheet({
  required BuildContext context,
  required List<Player> players,
  required void Function(String playerId, AuraKind kind, bool heavy) onGive,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _DebugAuraSheet(players: players, onGive: onGive),
  );
}

String _describe(ItemAura a) {
  final parts = [
    a.kind.name,
    if (a.heavy) 'тяжёлое',
    if (a.stat != null) a.stat!.name,
    'ходов ${a.turns}',
    if (a.accrued != 0) 'накоплено ${a.accrued}',
  ];
  return parts.join(' · ');
}

class _DebugAuraSheet extends StatefulWidget {
  final List<Player> players;
  final void Function(String playerId, AuraKind kind, bool heavy) onGive;

  const _DebugAuraSheet({required this.players, required this.onGive});

  @override
  State<_DebugAuraSheet> createState() => _DebugAuraSheetState();
}

class _DebugAuraSheetState extends State<_DebugAuraSheet> {
  late String _player = widget.players.first.id;
  AuraKind _kind = AuraKind.luckDrain;
  bool _heavy = false;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final p in widget.players)
        for (final i in p.inventory)
          if (i.aura != null) '${p.name}: ${i.name} — ${_describe(i.aura!)}',
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Отладка · ауры',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty) const Text('Ни на одной вещи ауры нет.'),
            for (final r in rows) Text(r),
            const Divider(height: 24),
            DropdownButton<String>(
              value: _player,
              isExpanded: true,
              items: [
                for (final p in widget.players)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _player = v!),
            ),
            DropdownButton<AuraKind>(
              value: _kind,
              isExpanded: true,
              items: [
                for (final k in AuraKind.curses)
                  DropdownMenuItem(value: k, child: Text(k.name)),
              ],
              onChanged: (v) => setState(() => _kind = v!),
            ),
            SwitchListTile(
              title: const Text('Тяжёлое'),
              value: _heavy,
              onChanged: (v) => setState(() => _heavy = v),
            ),
            FilledButton(
              onPressed: () {
                widget.onGive(_player, _kind, _heavy);
                Navigator.of(context).pop();
              },
              child: const Text('Дать проклятую вещь'),
            ),
          ],
        ),
      ),
    );
  }
}
