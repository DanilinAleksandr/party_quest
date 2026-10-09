import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/data/effect_repository.dart';
import 'package:drinking_quest/game_engine/data/item_repository.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

const _stone = InventoryItem(
  id: 'item_odd_stone',
  name: 'Необычный камень',
  description: 'd',
  rarity: Rarity.common,
  usageType: ItemUsageType.manual,
  isConsumable: false,
);

GameContext _with(List<Player> players) => GameContext(
  state: GameState(
    players: players,
    currentPlayerIndex: 0,
    status: GameStatus.inProgress,
    partySteps: 40,
  ),
  random: RandomProvider(seed: 1),
  cardCatalog: const CardCatalog([]),
  itemCatalog: const ItemCatalog({}),
  effectCatalog: const EffectCatalog({}),
  adventureCatalog: const AdventureCatalog({}),
  biomeCatalog: const BiomeCatalog({}),
  originCatalog: const OriginCatalog({}),
  eventBus: GameEventBus(),
  mode: GameMode.classic,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<GameCard> cards;
  setUpAll(() async => cards = await const CardRepository().loadCards());
  GameCard byId(String id) => cards.firstWhere((c) => c.id == id);

  test('the shaman does not come to a party with no finds', () {
    final shaman = byId('shaman_by_the_road');
    bool comes(List<InventoryItem> bag) => shaman.conditions.every(
      (c) => c.isSatisfied(_with([Player(id: 'p', name: 'A', inventory: bag)])),
    );
    expect(comes(const []), isFalse);
    // A thing that was given, not found, brings no shaman either.
    expect(comes(const [_stone]), isFalse);
    expect(comes([_stone.asFound()]), isTrue);
  });

  test('he reads a curse, names it, and the thing is known', () {
    final bag = [
      _stone.asFound(),
      _stone.asFound().withAura(
        const ItemAura(kind: AuraKind.luckDrain, turns: 9, accrued: -3),
      ),
    ];
    final read = shamanReads(
      _with([Player(id: 'p', name: 'A', inventory: bag)]),
    );
    expect(read.notice, AuraNotice.curse);
    expect(read.item, 1);
    expect(read.text, contains('Он поднимает камень'));
    expect(read.text, contains('Уже выпила 3.'));
  });

  test('an empty reading, and a blessing', () {
    expect(
      shamanReads(
        _with([
          Player(id: 'p', name: 'A', inventory: [_stone.asFound()]),
        ]),
      ).text,
      endsWith(kShamanEmpty),
    );
    final blessed = shamanReads(
      _with([
        Player(
          id: 'p',
          name: 'A',
          inventory: [
            _stone.asFound().withAura(
              const ItemAura(
                kind: AuraKind.quietStrength,
                stat: StatType.charisma,
              ),
            ),
          ],
        ),
      ]),
    );
    expect(blessed.notice, AuraNotice.blessing);
    expect(blessed.text, contains('Даёт тебе обаяние сверх того, что есть.'));
  });

  test('re-enchanted, a curse becomes its mirror blessing', () {
    for (final curse in AuraKind.curses) {
      final ctx = _with([
        Player(
          id: 'p',
          name: 'A',
          inventory: [
            _stone.asFound().withAura(
              ItemAura(
                kind: curse,
                stat: curse.onStat ? StatType.cunning : null,
              ),
            ),
          ],
        ),
      ]);
      final read = ctx.withState(ctx.state.copyWith(readItem: 0));
      final after = const ActionExecutor().execute(
        const ReadItemAction(mode: ReadItemMode.mirror),
        read,
      );
      final aura = after.players.single.inventory.single.aura!;
      expect(aura.kind, curse.mirror, reason: '$curse');
      expect(aura.curse, isFalse);
      // A failed one makes it heavy instead.
      final worse = const ActionExecutor().execute(
        const ReadItemAction(mode: ReadItemMode.worsen),
        read,
      );
      expect(worse.players.single.inventory.single.aura!.heavy, isTrue);
    }
    expect(AuraKind.luckDrain.mirror, AuraKind.quietLuck);
    expect(AuraKind.heavyHead.mirror, AuraKind.lightHead);
    expect(AuraKind.longHangover.mirror, AuraKind.noHangover);
    expect(AuraKind.quietWeakness.mirror, AuraKind.quietStrength);
  });

  test('in play: pour him a drink, and the curse can be given away', () async {
    final items = await const ItemRepository().loadCatalog();
    final effects = await const EffectRepository().loadCatalog();
    final c = GameController(
      playerNames: const ['A'],
      cards: [byId('shaman_by_the_road')],
      itemCatalog: items,
      effectCatalog: effects,
      adventureCatalog: const AdventureCatalog({}),
      biomeCatalog: const BiomeCatalog({}),
      originCatalog: const OriginCatalog({}),
      seed: 4,
      journeySteps: null,
      skipPrologue: true,
    );
    final me = c.state.players.single.id;
    c.debugGive(
      me,
      items
          .byId('item_odd_stone')
          .asFound()
          .withAura(const ItemAura(kind: AuraKind.heavyHead)),
    );
    c.takeStep();
    Iterable<String> labels() =>
        c.state.pendingCard!.choices.map((x) => x.label);
    expect(labels(), containsAll(['Налить ему', 'Пройти мимо']));
    final told = c.inspect(labels().toList().indexOf('Налить ему'));
    expect(told, contains('С ней ты пьянеешь быстрее, чем пьёшь.'));
    expect(c.state.players.single.intoxication, greaterThan(0));
    expect(
      labels(),
      containsAll(['Отдать ему', 'Пусть перезачарует', 'Оставить как есть']),
    );
    c.resolveCard(choiceIndex: labels().toList().indexOf('Отдать ему'));
    expect(c.state.players.single.inventory, isEmpty);
  });

  test('the owner notices what the figurine has become', () {
    final fig = InventoryItem(
      id: 'item_wooden_figurine',
      name: 'Деревянная фигурка',
      description: 'd',
      rarity: Rarity.common,
      usageType: ItemUsageType.manual,
      isConsumable: false,
    );
    String told(ItemAura? aura) => fillCardText(
      byId('figurine_owner_rude').description,
      _with([
        Player(id: 'p', name: 'Аня', inventory: [fig.withAura(aura)]),
      ]),
    );
    expect(told(null), endsWith('Ту, что у дороги лежала.'));
    expect(
      told(const ItemAura(kind: AuraKind.luckDrain)),
      endsWith('Только она теперь какая-то холодная.'),
    );
    expect(
      told(const ItemAura(kind: AuraKind.quietLuck)),
      endsWith('Странно, раньше она так не грела.'),
    );
  });

  test('taking the figurine may bring its owner; leaving it, the thanks', () {
    final figurine = byId('neutral_wooden_figurine');
    for (final choice in figurine.choices) {
      final gives = choice.actions.any(
        (a) => a is GiveItemAction && a.itemId == 'item_wooden_figurine',
      );
      final flags = {
        for (final a in choice.actions)
          if (a is SetWorldFlagAction) a.flag: a.chance,
      };
      if (gives) {
        expect(flags['figurine_owner_coming'], 0.6, reason: choice.label);
        expect(flags['figurine_owner_rude'], 0.4, reason: choice.label);
      }
    }
    final left = figurine.choices.firstWhere(
      (c) => c.label.startsWith('Оставить на месте'),
    );
    expect(left.actions.whereType<SetWorldFlagAction>().single.chance, 0.4);
  });
}
