import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/data/adventure_repository.dart';
import 'package:drinking_quest/game_engine/data/effect_repository.dart';
import 'package:drinking_quest/game_engine/data/item_repository.dart';
import 'package:drinking_quest/game_engine/data/origin_repository.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

GameContext _buildContext({
  required List<Player> players,
  required AdventureCatalog adventureCatalog,
  ItemCatalog itemCatalog = const ItemCatalog({}),
  EffectCatalog effectCatalog = const EffectCatalog({}),
  BiomeCatalog biomeCatalog = const BiomeCatalog({}),
  OriginCatalog originCatalog = const OriginCatalog({}),
  int seed = 1,
  WorldState worldState = const WorldState(),
  List<InventoryItem> partyInventory = const [],
}) {
  return GameContext(
    state: GameState(
      players: players,
      currentPlayerIndex: 0,
      status: GameStatus.inProgress,
      worldState: worldState,
      partyInventory: partyInventory,
    ),
    random: RandomProvider(seed: seed),
    cardCatalog: const CardCatalog([]),
    itemCatalog: itemCatalog,
    effectCatalog: effectCatalog,
    adventureCatalog: adventureCatalog,
    biomeCatalog: biomeCatalog,
    originCatalog: originCatalog,
    eventBus: GameEventBus(),
    mode: GameMode.classic,
  );
}

const _player = Player(id: 'p1', name: 'A');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdventureEngine linear/branching flow', () {
    test('a fully automatic adventure cascades straight to completion', () {
      final adventure = Adventure(
        id: 'linear',
        entryNodeId: 'a',
        nodes: const {
          'a': AdventureNode(
            id: 'a',
            text: 't',
            autoTransition: GoToNode(nodeId: 'b'),
          ),
          'b': AdventureNode(
            id: 'b',
            text: 't',
            autoTransition: GoToNode(nodeId: 'c'),
          ),
          'c': AdventureNode(
            id: 'c',
            text: 't',
            autoTransition: EndAdventure(),
          ),
        },
      );
      final context = _buildContext(
        players: [_player],
        adventureCatalog: AdventureCatalog({'linear': adventure}),
      );

      final engine = AdventureEngine(const ActionExecutor());
      final result = engine.enter(adventure, context);

      expect(result.state.activeAdventureId, isNull);
      expect(result.state.pendingAdventureNode, isNull);
      expect(result.state.worldState.completedAdventures, contains('linear'));
    });

    test('a node with choices suspends and waits for resolveChoice', () {
      final adventure = Adventure(
        id: 'choice_adv',
        entryNodeId: 'start',
        nodes: const {
          'start': AdventureNode(
            id: 'start',
            text: 't',
            choices: [
              AdventureChoice(
                label: 'go',
                onSuccess: NodeTransition(to: GoToNode(nodeId: 'end')),
              ),
            ],
          ),
          'end': AdventureNode(
            id: 'end',
            text: 't',
            autoTransition: EndAdventure(),
          ),
        },
      );
      final context = _buildContext(
        players: [_player],
        adventureCatalog: AdventureCatalog({'choice_adv': adventure}),
      );
      final engine = AdventureEngine(const ActionExecutor());

      final entered = engine.enter(adventure, context);
      expect(entered.state.activeAdventureId, 'choice_adv');
      expect(entered.state.pendingAdventureNode?.id, 'start');

      final resolved = engine.resolveChoice(
        adventure,
        entered.state.pendingAdventureNode!,
        0,
        entered,
      );
      expect(resolved.state.activeAdventureId, isNull);
      expect(
        resolved.state.worldState.completedAdventures,
        contains('choice_adv'),
      );
    });

    test(
      'a node with zero eligible choices ends the adventure instead of soft-locking',
      () {
        final adventure = Adventure(
          id: 'locked_out',
          entryNodeId: 'start',
          nodes: const {
            'start': AdventureNode(
              id: 'start',
              text: 't',
              choices: [
                AdventureChoice(
                  label: 'unreachable',
                  conditions: [WorldFlagSetCondition(flag: 'never_set')],
                  onSuccess: NodeTransition(to: EndAdventure()),
                ),
              ],
            ),
          },
        );
        final context = _buildContext(
          players: [_player],
          adventureCatalog: AdventureCatalog({'locked_out': adventure}),
        );
        final engine = AdventureEngine(const ActionExecutor());

        final result = engine.enter(adventure, context);

        expect(result.state.activeAdventureId, isNull);
        expect(result.state.pendingAdventureNode, isNull);
        expect(
          result.state.worldState.completedAdventures,
          contains('locked_out'),
        );
      },
    );
  });

  group('AdventureEngine world-state gating', () {
    test('a choice condition hides/shows depending on a world flag', () {
      final adventure = Adventure(
        id: 'flag_gate',
        entryNodeId: 'start',
        nodes: const {
          'start': AdventureNode(
            id: 'start',
            text: 't',
            choices: [
              AdventureChoice(
                label: 'only if set',
                conditions: [WorldFlagSetCondition(flag: 'stole_magic_book')],
                onSuccess: NodeTransition(to: EndAdventure()),
              ),
              AdventureChoice(
                label: 'only if unset',
                conditions: [WorldFlagUnsetCondition(flag: 'stole_magic_book')],
                onSuccess: NodeTransition(to: EndAdventure()),
              ),
            ],
          ),
        },
      );
      final catalog = AdventureCatalog({'flag_gate': adventure});
      final engine = AdventureEngine(const ActionExecutor());

      final withoutFlag = engine.enter(
        adventure,
        _buildContext(players: [_player], adventureCatalog: catalog),
      );
      expect(
        withoutFlag.state.pendingAdventureNode!.choices.map((c) => c.label),
        ['only if unset'],
      );

      final withFlag = engine.enter(
        adventure,
        _buildContext(
          players: [_player],
          adventureCatalog: catalog,
          worldState: const WorldState(flags: {'stole_magic_book': true}),
        ),
      );
      expect(withFlag.state.pendingAdventureNode!.choices.map((c) => c.label), [
        'only if set',
      ]);
    });
  });

  group('AdventureEngine success/failure chance', () {
    test('successChance of 1.0 always takes onSuccess', () {
      final adventure = Adventure(
        id: 'always_win',
        entryNodeId: 'start',
        nodes: const {
          'start': AdventureNode(
            id: 'start',
            text: 't',
            choices: [
              AdventureChoice(
                label: 'try',
                successChance: 1.0,
                onSuccess: NodeTransition(
                  actions: [ModifyStatAction(stat: StatType.luck, amount: 5)],
                  to: EndAdventure(),
                ),
                onFailure: NodeTransition(
                  actions: [ModifyStatAction(stat: StatType.luck, amount: -5)],
                  to: EndAdventure(),
                ),
              ),
            ],
          ),
        },
      );
      final context = _buildContext(
        players: [_player],
        adventureCatalog: AdventureCatalog({'always_win': adventure}),
      );
      final engine = AdventureEngine(const ActionExecutor());

      final entered = engine.enter(adventure, context);
      final resolved = engine.resolveChoice(
        adventure,
        entered.state.pendingAdventureNode!,
        0,
        entered,
      );

      expect(resolved.currentPlayer.stats.valueOf(StatType.luck), 5);
    });

    test('successChance of 0.0 always takes onFailure', () {
      final adventure = Adventure(
        id: 'always_lose',
        entryNodeId: 'start',
        nodes: const {
          'start': AdventureNode(
            id: 'start',
            text: 't',
            choices: [
              AdventureChoice(
                label: 'try',
                successChance: 0.0,
                onSuccess: NodeTransition(
                  actions: [ModifyStatAction(stat: StatType.luck, amount: 5)],
                  to: EndAdventure(),
                ),
                onFailure: NodeTransition(
                  actions: [ModifyStatAction(stat: StatType.luck, amount: -5)],
                  to: EndAdventure(),
                ),
              ),
            ],
          ),
        },
      );
      final context = _buildContext(
        players: [_player],
        adventureCatalog: AdventureCatalog({'always_lose': adventure}),
      );
      final engine = AdventureEngine(const ActionExecutor());

      final entered = engine.enter(adventure, context);
      final resolved = engine.resolveChoice(
        adventure,
        entered.state.pendingAdventureNode!,
        0,
        entered,
      );

      expect(resolved.currentPlayer.stats.valueOf(StatType.luck), -5);
    });
  });

  group('AdventureEngine determinism', () {
    test('the same seed picks the same weighted random branch', () {
      final adventure = Adventure(
        id: 'random_adv',
        entryNodeId: 'start',
        nodes: const {
          'start': AdventureNode(
            id: 'start',
            text: 't',
            autoTransition: RandomNode(
              options: [
                WeightedNodeRef(nodeId: 'x', weight: 1),
                WeightedNodeRef(nodeId: 'y', weight: 1),
              ],
            ),
          ),
          'x': AdventureNode(
            id: 'x',
            text: 't',
            onEnterActions: [ModifyStatAction(stat: StatType.luck, amount: 1)],
            autoTransition: EndAdventure(),
          ),
          'y': AdventureNode(
            id: 'y',
            text: 't',
            onEnterActions: [ModifyStatAction(stat: StatType.luck, amount: -1)],
            autoTransition: EndAdventure(),
          ),
        },
      );
      final catalog = AdventureCatalog({'random_adv': adventure});
      final engine = AdventureEngine(const ActionExecutor());

      final resultA = engine.enter(
        adventure,
        _buildContext(players: [_player], adventureCatalog: catalog, seed: 42),
      );
      final resultB = engine.enter(
        adventure,
        _buildContext(players: [_player], adventureCatalog: catalog, seed: 42),
      );

      expect(
        resultA.currentPlayer.stats.valueOf(StatType.luck),
        resultB.currentPlayer.stats.valueOf(StatType.luck),
      );
    });
  });

  group('Bundled witch_hut adventure', () {
    test(
      'every branch of the real content is reachable and never throws',
      () async {
        final adventureCatalog = await const AdventureRepository()
            .loadCatalog();
        final itemCatalog = await const ItemRepository().loadCatalog();
        final effectCatalog = await const EffectRepository().loadCatalog();
        final adventure = adventureCatalog.byId('witch_hut');
        final engine = AdventureEngine(const ActionExecutor());

        final branchesSeen = <String>{};

        for (var seed = 1; seed <= 300; seed++) {
          final context = _buildContext(
            players: [_player],
            adventureCatalog: adventureCatalog,
            itemCatalog: itemCatalog,
            effectCatalog: effectCatalog,
            seed: seed,
          );
          var ctx = engine.enter(adventure, context);
          expect(ctx.state.pendingAdventureNode?.id, 'hut_entrance');

          // Always choose "Войти" (index 0) to explore the randomized interior.
          ctx = engine.resolveChoice(
            adventure,
            ctx.state.pendingAdventureNode!,
            0,
            ctx,
          );

          if (ctx.state.pendingAdventureNode != null) {
            branchesSeen.add(ctx.state.pendingAdventureNode!.id);
            continue;
          }

          expect(ctx.state.activeAdventureId, isNull);
          expect(
            ctx.state.worldState.completedAdventures,
            contains('witch_hut'),
          );
          if (ctx.currentPlayer.inventory.any(
            (i) => i.id == 'item_lucky_coin',
          )) {
            branchesSeen.add('empty_house');
          } else if (ctx.currentPlayer.inventory.any(
            (i) => i.id == 'item_healing_potion',
          )) {
            branchesSeen.add('potion_found');
          } else if (ctx.currentPlayer.activeEffects.any(
            (e) => e.id == 'effect_cloud',
          )) {
            branchesSeen.add('trap');
          }
        }

        expect(
          branchesSeen,
          containsAll([
            'witch_home',
            'chest_found',
            'empty_house',
            'potion_found',
            'trap',
          ]),
        );
      },
    );

    test(
      'stealing the spellbook is remembered on a later visit to the witch',
      () {
        // Directly target the witch_home node rather than searching for a
        // seed that lands there, so the assertion doesn't depend on the
        // random interior roll.
        final adventure = Adventure(
          id: 'witch_only',
          entryNodeId: 'witch_home',
          nodes: const {
            'witch_home': AdventureNode(
              id: 'witch_home',
              text: 't',
              choices: [
                AdventureChoice(
                  label: 'caught',
                  conditions: [WorldFlagSetCondition(flag: 'stole_magic_book')],
                  onSuccess: NodeTransition(to: EndAdventure()),
                ),
                AdventureChoice(
                  label: 'steal',
                  conditions: [
                    WorldFlagUnsetCondition(flag: 'stole_magic_book'),
                  ],
                  successChance: 1.0,
                  onSuccess: NodeTransition(
                    actions: [SetWorldFlagAction(flag: 'stole_magic_book')],
                    to: EndAdventure(),
                  ),
                  onFailure: NodeTransition(to: EndAdventure()),
                ),
              ],
            ),
          },
        );
        final catalog = AdventureCatalog({'witch_only': adventure});
        final engine = AdventureEngine(const ActionExecutor());

        // First visit: book not yet stolen, only "steal" is offered.
        var context = _buildContext(
          players: [_player],
          adventureCatalog: catalog,
        );
        var entered = engine.enter(adventure, context);
        expect(
          entered.state.pendingAdventureNode!.choices.map((c) => c.label),
          ['steal'],
        );

        var resolved = engine.resolveChoice(
          adventure,
          entered.state.pendingAdventureNode!,
          0,
          entered,
        );
        expect(resolved.state.worldState.flag('stole_magic_book'), isTrue);

        // Second visit, carrying the same world state forward: now caught.
        context = _buildContext(
          players: [_player],
          adventureCatalog: catalog,
          worldState: resolved.state.worldState,
        );
        entered = engine.enter(adventure, context);
        expect(
          entered.state.pendingAdventureNode!.choices.map((c) => c.label),
          ['caught'],
        );
      },
    );
  });

  group('Legendary origin reveal embedded in an adventure', () {
    const revealOrigin = Origin(
      id: 'origin_test_legendary',
      name: 'Test Legendary',
      description: 'd',
      category: OriginCategory.trueNature,
      rarity: Rarity.legendary,
      statModifiers: {StatType.strength: 1},
    );

    Adventure buildAdventure() => const Adventure(
      id: 'legendary_test',
      entryNodeId: 'confrontation',
      nodes: {
        'confrontation': AdventureNode(
          id: 'confrontation',
          text: 't',
          choices: [
            AdventureChoice(
              label: 'Meet its gaze',
              conditions: [CurrentPlayerOriginUnknownCondition()],
              successChance: 1.0,
              onSuccess: NodeTransition(
                actions: [],
                to: GoToNode(nodeId: 'recognized'),
              ),
              onFailure: NodeTransition(to: EndAdventure()),
            ),
            AdventureChoice(
              label: 'Fight instead',
              onSuccess: NodeTransition(to: EndAdventure()),
            ),
          ],
        ),
        'recognized': AdventureNode(
          id: 'recognized',
          text: 't',
          onEnterActions: [
            RevealOriginAction(originId: 'origin_test_legendary'),
          ],
          autoTransition: EndAdventure(),
        ),
      },
    );

    test(
      'the gaze choice is offered while the player is still Unknown, and reveals the origin on success',
      () {
        final adventure = buildAdventure();
        final engine = AdventureEngine(const ActionExecutor());
        final context = _buildContext(
          players: [_player],
          adventureCatalog: AdventureCatalog({adventure.id: adventure}),
          originCatalog: OriginCatalog({revealOrigin.id: revealOrigin}),
        );

        final entered = engine.enter(adventure, context);
        expect(
          entered.state.pendingAdventureNode!.choices.map((c) => c.label),
          ['Meet its gaze', 'Fight instead'],
        );

        final resolved = engine.resolveChoice(
          adventure,
          entered.state.pendingAdventureNode!,
          0,
          entered,
        );
        expect(resolved.currentPlayer.originId, 'origin_test_legendary');
        expect(resolved.currentPlayer.stats.valueOf(StatType.strength), 1);
      },
    );

    test(
      'the gaze choice disappears once the player already has an origin',
      () {
        final adventure = buildAdventure();
        final engine = AdventureEngine(const ActionExecutor());
        final revealedPlayer = _player.copyWith(
          originId: 'origin_test_legendary',
        );
        final context = _buildContext(
          players: [revealedPlayer],
          adventureCatalog: AdventureCatalog({adventure.id: adventure}),
          originCatalog: OriginCatalog({revealOrigin.id: revealOrigin}),
        );

        final entered = engine.enter(adventure, context);
        expect(
          entered.state.pendingAdventureNode!.choices.map((c) => c.label),
          ['Fight instead'],
        );
      },
    );
  });

  group('Bundled additional adventures smoke test', () {
    /// Walks an adventure to completion by always picking the first
    /// available choice, across many seeds — a broad, low-effort net for
    /// "does any reachable path throw", complementing the more targeted
    /// witch_hut branch-coverage test above.
    Future<void> sweepAdventure(
      String adventureId, {
      int seeds = 100,
      List<Player> Function(int seed)? playersFor,
    }) async {
      final adventureCatalog = await const AdventureRepository().loadCatalog();
      final itemCatalog = await const ItemRepository().loadCatalog();
      final effectCatalog = await const EffectRepository().loadCatalog();
      final originCatalog = await const OriginRepository().loadCatalog();
      final adventure = adventureCatalog.byId(adventureId);
      final engine = AdventureEngine(const ActionExecutor());

      for (var seed = 1; seed <= seeds; seed++) {
        final players =
            playersFor?.call(seed) ??
            [_player, const Player(id: 'p2', name: 'B')];
        var ctx = _buildContext(
          players: players,
          adventureCatalog: adventureCatalog,
          itemCatalog: itemCatalog,
          effectCatalog: effectCatalog,
          originCatalog: originCatalog,
          seed: seed,
        );
        ctx = engine.enter(adventure, ctx);

        var guard = 0;
        while (ctx.state.pendingAdventureNode != null) {
          guard++;
          expect(
            guard,
            lessThan(50),
            reason: 'adventure "$adventureId" did not terminate for seed $seed',
          );
          ctx = engine.resolveChoice(
            adventure,
            ctx.state.pendingAdventureNode!,
            0,
            ctx,
          );
        }

        expect(ctx.state.worldState.completedAdventures, contains(adventureId));
      }
    }

    test('abandoned_tavern never throws across many seeds', () async {
      await sweepAdventure('abandoned_tavern');
    });

    test('traveling_merchant never throws across many seeds', () async {
      await sweepAdventure('traveling_merchant');
    });

    test('bandit_camp never throws across many seeds', () async {
      await sweepAdventure('bandit_camp');
    });

    test('great_witch never throws across many seeds', () async {
      await sweepAdventure('great_witch');
    });

    test('ancient_forest_spirit never throws across many seeds', () async {
      await sweepAdventure('ancient_forest_spirit');
    });

    test('pharaoh never throws across many seeds', () async {
      await sweepAdventure('pharaoh');
    });

    test('desert_warlord never throws across many seeds', () async {
      await sweepAdventure('desert_warlord');
    });

    test('tavern_keeper never throws across many seeds', () async {
      await sweepAdventure('tavern_keeper');
    });

    test('legendary_cardsharp never throws across many seeds', () async {
      await sweepAdventure('legendary_cardsharp');
    });

    test('king_of_the_dead never throws across many seeds', () async {
      await sweepAdventure('king_of_the_dead');
    });

    test('dragon never throws across many seeds', () async {
      await sweepAdventure('dragon');
    });

    test('pirate_captain never throws across many seeds', () async {
      await sweepAdventure('pirate_captain');
    });

    test(
      'bandit_camp only offers the flask/keg approaches when those items are held',
      () async {
        final adventureCatalog = await const AdventureRepository()
            .loadCatalog();
        final itemCatalog = await const ItemRepository().loadCatalog();
        final adventure = adventureCatalog.byId('bandit_camp');
        final engine = AdventureEngine(const ActionExecutor());

        var withoutItems = engine.enter(
          adventure,
          _buildContext(
            players: [
              _player,
              const Player(id: 'p2', name: 'B'),
            ],
            adventureCatalog: adventureCatalog,
            itemCatalog: itemCatalog,
          ),
        );
        withoutItems = engine.resolveChoice(
          adventure,
          withoutItems.state.pendingAdventureNode!,
          0,
          withoutItems,
        );
        expect(
          withoutItems.state.pendingAdventureNode!.choices.map((c) => c.label),
          ['Прокрасться мимо часового', 'Выйти открыто и заговорить'],
        );

        final flask = itemCatalog.byId('item_bravery_flask');
        final keg = itemCatalog.byId('item_beer_keg');
        final equipped = Player(id: 'p1', name: 'A', inventory: [flask]);
        var withItems = engine.enter(
          adventure,
          _buildContext(
            players: [
              equipped,
              const Player(id: 'p2', name: 'B'),
            ],
            adventureCatalog: adventureCatalog,
            itemCatalog: itemCatalog,
            partyInventory: [keg],
          ),
        );
        withItems = engine.resolveChoice(
          adventure,
          withItems.state.pendingAdventureNode!,
          0,
          withItems,
        );
        expect(
          withItems.state.pendingAdventureNode!.choices.map((c) => c.label),
          [
            'Прокрасться мимо часового',
            'Выйти открыто и заговорить',
            'Атаковать в лоб',
            'Предложить бочонок вместо драки',
          ],
        );
      },
    );
  });
}
