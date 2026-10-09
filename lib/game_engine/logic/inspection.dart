import '../context/game_context.dart';
import '../models/models.dart';

/// What a close look at a find can come to: who sees what, and how it is
/// said. Pure — the controller rolls nothing here but the companion's
/// chance, which it passes in.

/// Who sees the work in a thing: good or a trinket.
const Set<String> kCraftEyes = {'origin_craftsman', 'origin_merchant'};

/// Who feels a curse in a thing — not which curse, only that there is one.
const Set<String> kCurseSense = {
  'origin_witch_heir',
  'origin_last_archmage',
  'origin_rune_keeper',
  'origin_soul_guide',
};

/// Who always knows a blessing.
const String kBlessingSight = 'origin_gods_chosen';

/// The odds that a companion who could see it notices, when the one
/// looking cannot.
const double kCompanionNotices = 1 / 3;

const String kNothingSeen =
    'Ничего особенного. Или ничего, что ты можешь разглядеть.';
const String kCurseSeen =
    'Пальцы холодеют, едва касаешься. Эта вещь — не просто вещь.';
const String kBlessingSeen =
    'От вещи идёт тепло, которое ты узнаёшь сразу. Её кто-то благословил.';

/// What a craft eye says of each find — the figurine's line is the brief's.
const Map<String, String> kCraftLines = {
  'item_wooden_figurine':
      'Резьба чистая, рука уверенная. Такие не теряют — такие роняют, и '
      'потом ищут.',
  'item_lucky_coin':
      'Чеканка честная, край не стёрт. Такую монету берегут, а не тратят.',
  'item_odd_stone':
      'Камень как камень. Работы в нём нет — только вода, и та давно.',
  'item_forgotten_note':
      'Бумага плотная, писарская. Почерк — нет: писал не писарь.',
  'item_bravery_flask':
      'Пробка притёрта, шов двойной. Тот, кто её делал, рассчитывал на '
      'долгую дорогу.',
  'item_flask':
      'Фляга добротная, шов ровный. Пустая — но фляга, а не '
      'безделица.',
  'item_broken_compass':
      'Корпус хороший, стекло родное. Стрелку сбили нарочно — мастер так '
      'не роняет.',
  'item_silver_tongue_ring':
      'Серебро тонкое, а гравировка внутри — работа не здешняя. Дорогая '
      'безделица.',
};

/// The find in the accusative, for «смотреть на {item}».
const Map<String, String> kItemAccusative = {
  'item_wooden_figurine': 'фигурку',
  'item_lucky_coin': 'монету',
  'item_odd_stone': 'камень',
  'item_forgotten_note': 'записку',
  'item_bravery_flask': 'флягу',
  'item_flask': 'флягу',
  'item_broken_compass': 'компас',
  'item_silver_tongue_ring': 'кольцо',
};

const String _companionLine =
    '{name} вдруг замирает и смотрит на вещь в твоих руках дольше, чем стоит '
    'смотреть на {item}.';

/// The thing a find card offers: the first item any of its choices gives.
String? findItemOf(GameCard card) {
  Iterable<GameAction> all(List<GameAction> actions) sync* {
    for (final a in actions) {
      yield a;
      if (a is ChanceCheckAction) {
        yield* all(a.winnerActions);
        yield* all(a.loserActions);
      }
    }
  }

  for (final a in [
    ...all(card.actions),
    for (final c in card.choices) ...all(c.actions),
  ]) {
    if (a is GiveItemAction) return a.itemId;
  }
  return null;
}

bool _sees(String? origin, ItemAura? aura) {
  if (aura == null || origin == null) return false;
  return aura.curse ? kCurseSense.contains(origin) : origin == kBlessingSight;
}

/// What the current player makes of the find on [card] when they look
/// closer, and what they came to notice. [companionRoll] is a roll in
/// [0, 1) for a companion's chance to notice.
({String text, AuraNotice notice}) inspectFind(
  GameContext context,
  GameCard card, {
  required double companionRoll,
  bool quiet = false,
}) {
  final aura = context.state.pendingAura;
  final looker = context.currentPlayer;
  final item = findItemOf(card);
  final lines = <String>[];
  var notice = AuraNotice.none;

  if (_sees(looker.originId, aura)) {
    lines.add(aura!.curse ? kCurseSeen : kBlessingSeen);
    notice = aura.curse ? AuraNotice.curse : AuraNotice.blessing;
  } else if (kCraftEyes.contains(looker.originId) &&
      kCraftLines.containsKey(item)) {
    lines.add(kCraftLines[item]!);
  }

  if (notice == AuraNotice.none && aura != null) {
    final companion = context.players
        .where((p) => p.id != looker.id && _sees(p.originId, aura))
        .firstOrNull;
    if (companion != null && companionRoll < kCompanionNotices) {
      lines.add(
        _companionLine
            .replaceAll('{name}', companion.name)
            .replaceAll('{item}', kItemAccusative[item] ?? 'неё'),
      );
      notice = aura.curse ? AuraNotice.curse : AuraNotice.blessing;
    }
  }

  // A look with words of its own does not also say it saw nothing.
  if (lines.isEmpty && !quiet) lines.add(kNothingSeen);
  return (text: lines.join('\n\n'), notice: notice);
}
