import '../../../core/constants/ally_flags.dart';
import '../../../game_engine/logic/logic.dart';
import '../../../game_engine/models/models.dart';
import 'result_entry.dart';

/// Answers playtest note #8 ("недостаточный отклик интерфейса") by diffing
/// [previous] against [next] for whichever players the just-resolved
/// event/adventure was about, plus the shared party inventory, and turning
/// every real change into a [ResultEntry] — one per change, since (per the
/// user's explicit ask) each one gets shown as its own "карточка
/// результата" moment rather than several lines crammed into one toast. An
/// empty result is a legitimate answer — a flavor-only card that changed
/// nothing produces no entries and therefore no card, rather than a
/// fabricated "ничего не произошло".
List<ResultEntry> computeResultEntries({
  required GameState previous,
  required GameState next,
  required List<Player> targets,
  required OriginCatalog originCatalog,
}) {
  final entries = <ResultEntry>[];

  for (final before in targets) {
    final after = next.players.firstWhere((p) => p.id == before.id);

    if (before.originId == null &&
        after.originId != null &&
        originCatalog.contains(after.originId!)) {
      final origin = originCatalog.byId(after.originId!);
      entries.add(
        ResultEntry(
          kind: ResultKind.originRevealed,
          playerName: after.name,
          headline: origin.name,
          rarity: origin.rarity,
        ),
      );
    }

    final beforeItemIds = before.inventory.map((i) => i.id).toList();
    final afterItemIds = after.inventory.map((i) => i.id).toList();
    for (final item in after.inventory) {
      if (!_consume(beforeItemIds, item.id)) {
        entries.add(
          ResultEntry(
            kind: ResultKind.itemGained,
            playerName: after.name,
            headline: item.name,
            rarity: item.rarity,
          ),
        );
      }
    }
    for (final item in before.inventory) {
      if (!_consume(afterItemIds, item.id)) {
        entries.add(
          ResultEntry(
            kind: ResultKind.itemLost,
            playerName: after.name,
            headline: item.name,
            rarity: item.rarity,
          ),
        );
      }
    }

    final beforeEffectIds = before.activeEffects.map((e) => e.id).toList();
    final afterEffectIds = after.activeEffects.map((e) => e.id).toList();
    for (final effect in after.activeEffects) {
      if (!_consume(beforeEffectIds, effect.id)) {
        entries.add(
          ResultEntry(
            kind: ResultKind.effectGained,
            playerName: after.name,
            headline: effect.name,
            isNegative: effect.polarity == EffectPolarity.negative,
          ),
        );
      }
    }
    for (final effect in before.activeEffects) {
      if (!_consume(afterEffectIds, effect.id)) {
        entries.add(
          ResultEntry(
            kind: ResultKind.effectLost,
            playerName: after.name,
            headline: effect.name,
          ),
        );
      }
    }

    for (final stat in StatType.values) {
      final delta = after.stats.valueOf(stat) - before.stats.valueOf(stat);
      if (delta == 0) continue;
      entries.add(
        ResultEntry(
          kind: ResultKind.statChanged,
          playerName: after.name,
          headline: '${_statLabel(stat)} ${delta > 0 ? '+$delta' : '$delta'}',
          isNegative: delta < 0,
        ),
      );
    }
  }

  final beforePartyItemIds = previous.partyInventory.map((i) => i.id).toList();
  final afterPartyItemIds = next.partyInventory.map((i) => i.id).toList();
  for (final item in next.partyInventory) {
    if (!_consume(beforePartyItemIds, item.id)) {
      entries.add(
        ResultEntry(
          kind: ResultKind.partyItemGained,
          headline: item.name,
          rarity: item.rarity,
        ),
      );
    }
  }
  for (final item in previous.partyInventory) {
    if (!_consume(afterPartyItemIds, item.id)) {
      entries.add(
        ResultEntry(kind: ResultKind.partyItemLost, headline: item.name, rarity: item.rarity),
      );
    }
  }

  final previousLeaderId = previous.worldState.leaderId;
  final nextLeaderId = next.worldState.leaderId;
  if (nextLeaderId != null && nextLeaderId != previousLeaderId) {
    final leaderIndex = next.players.indexWhere((p) => p.id == nextLeaderId);
    if (leaderIndex != -1) {
      entries.add(
        ResultEntry(
          kind: ResultKind.leaderChanged,
          headline: next.players[leaderIndex].name,
        ),
      );
    }
  }

  for (final flag in allyFlags.entries) {
    final wasAllied = previous.worldState.flag(flag.key);
    final isAllied = next.worldState.flag(flag.key);
    if (!wasAllied && isAllied) {
      entries.add(
        ResultEntry(
          kind: ResultKind.allyGained,
          headline: flag.value.name,
          description: flag.value.description,
        ),
      );
    }
  }

  return entries;
}


/// Removes the first occurrence of [id] from [ids] and reports whether it
/// was there — id-based multiset diff so a player holding two of the same
/// item doesn't get misread as "nothing changed" when only one is added.
bool _consume(List<String> ids, String id) {
  final index = ids.indexOf(id);
  if (index == -1) return false;
  ids.removeAt(index);
  return true;
}

String _statLabel(StatType stat) => switch (stat) {
  StatType.strength => 'Сила',
  StatType.luck => 'Удача',
  StatType.charisma => 'Харизма',
  StatType.endurance => 'Выносливость',
  StatType.attentiveness => 'Внимательность',
  StatType.cunning => 'Хитрость',
};
