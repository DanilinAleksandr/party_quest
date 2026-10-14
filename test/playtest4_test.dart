import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:drinking_quest/core/theme/effect_terms.dart';
import 'package:drinking_quest/core/widgets/stat_chip.dart';
import 'package:drinking_quest/features/game/application/game_controller.dart';
import 'package:drinking_quest/features/game/application/result_diff.dart';
import 'package:drinking_quest/features/game_setup/presentation/game_setup_screen.dart';
import 'package:drinking_quest/game_engine/context/game_context.dart';
import 'package:drinking_quest/game_engine/data/adventure_repository.dart';
import 'package:drinking_quest/game_engine/data/biome_repository.dart';
import 'package:drinking_quest/game_engine/data/card_repository.dart';
import 'package:drinking_quest/game_engine/data/effect_repository.dart';
import 'package:drinking_quest/game_engine/data/item_repository.dart';
import 'package:drinking_quest/game_engine/data/origin_repository.dart';
import 'package:drinking_quest/game_engine/logic/logic.dart';
import 'package:drinking_quest/game_engine/models/models.dart';

GameCard _card(
  String id, {
  List<CardChoice> choices = const [],
  List<GameAction> actions = const [],
  String description = 'd',
}) => GameCard(
  id: id,
  title: id,
  description: description,
  type: CardType.event,
  rarity: Rarity.common,
  weight: 1,
  choices: choices,
  actions: actions,
);

GameController _controller(
  List<GameCard> cards, {
  List<String> players = const ['Саня', 'Миша'],
  List<int>? ages,
  int seed = 3,
}) => GameController(
  playerNames: players,
  cards: cards,
  itemCatalog: const ItemCatalog({}),
  effectCatalog: const EffectCatalog({}),
  adventureCatalog: const AdventureCatalog({}),
  biomeCatalog: const BiomeCatalog({}),
  originCatalog: const OriginCatalog({}),
  seed: seed,
  journeySteps: null,
  skipPrologue: true,
  ages: ages ?? [for (final _ in players) kDefaultAge],
);

GameContext _weatherContext(WorldState world) => GameContext(
  state: GameState(
    players: const [Player(id: 'p1', name: 'A')],
    currentPlayerIndex: 0,
    status: GameStatus.inProgress,
    worldState: world,
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

  group('«Для храбрости»', () {
    test('is offered only where a drink changes something', () {
      // The shaman's card: choices, but nothing a drink could move.
      final plain = _controller([
        _card(
          'plain',
          choices: const [
            CardChoice(label: 'Поговорить'),
            CardChoice(label: 'Уйти'),
          ],
        ),
      ])..takeStep();
      expect(plain.canDrinkForCourage, isFalse);

      final throwAhead = _controller([
        _card(
          'throw',
          choices: const [
            CardChoice(
              label: 'Рискнуть',
              actions: [ChanceCheckAction(stat: StatType.charisma)],
            ),
            CardChoice(label: 'Уйти'),
          ],
        ),
      ])..takeStep();
      expect(throwAhead.canDrinkForCourage, isTrue);

      final drunkChoice = _controller([
        _card(
          'gated',
          choices: const [
            CardChoice(
              label: 'Пойти на волков с голыми руками',
              conditions: [
                IntoxicationAtLeastCondition(level: IntoxicationLevel.drunk),
              ],
            ),
            CardChoice(label: 'Уйти'),
          ],
        ),
      ])..takeStep();
      expect(drunkChoice.canDrinkForCourage, isTrue);
    });
  });

  group('the drink', () {
    test('the eldest is not the first one sober', () {
      final c = _controller(
        [
          _card(
            'round',
            actions: const [
              DrinkAction(target: ActionTarget.allPlayers),
              DrinkAction(target: ActionTarget.allPlayers),
            ],
          ),
          _card('road'),
        ],
        players: const ['Ваня', 'Саня'],
        ages: const [24, 58],
      );
      // The round first, whoever draws it; then the road until both sober.
      for (
        var i = 0;
        i < 40 && c.state.players.every((p) => p.intoxication == 0);
        i++
      ) {
        c.takeStep();
        c.resolveCard();
      }
      final soberAt = <String, int>{};
      for (var step = 0; step < 200 && soberAt.length < 2; step++) {
        c.takeStep();
        c.resolveCard();
        for (final p in c.state.players) {
          if (p.intoxicationLevel == IntoxicationLevel.sober) {
            soberAt.putIfAbsent(p.name, () => step);
          }
        }
      }
      expect(soberAt['Ваня'], lessThan(soberAt['Саня']!));
    });

    test('a drink on a drink is told, even if the level stays', () {
      const before = Player(id: 'p', name: 'A', intoxication: 0.5);
      const after = Player(id: 'p', name: 'A', intoxication: 1.5);
      final entries = computeResultEntries(
        previous: const GameState(
          players: [before],
          currentPlayerIndex: 0,
          status: GameStatus.inProgress,
        ),
        next: const GameState(
          players: [after],
          currentPlayerIndex: 0,
          status: GameStatus.inProgress,
        ),
        targets: const [before],
        originCatalog: const OriginCatalog({}),
      );
      expect(
        entries.map((e) => e.headline),
        contains('Ещё глоток — по-прежнему навеселе'),
      );
    });
  });

  group('stats on the profile', () {
    test('show the drink and effects, never an unseen aura', () {
      final p = const Player(
        id: 'p',
        name: 'A',
        intoxication: 1,
        inventory: [
          InventoryItem(
            id: 'x',
            name: 'x',
            description: 'd',
            rarity: Rarity.common,
            usageType: ItemUsageType.manual,
            isConsumable: false,
          ),
        ],
      );
      final cursed = p.copyWith(
        inventory: [
          p.inventory.single.withAura(
            const ItemAura(
              kind: AuraKind.quietWeakness,
              stat: StatType.charisma,
            ),
          ),
        ],
      );
      // Tipsy: charisma 0 (1). The curse takes some of it in a check, but
      // the profile must not show that.
      expect(p.visibleStat(StatType.charisma), 1);
      expect(cursed.visibleStat(StatType.charisma), 1);
      expect(
        cursed.effectiveStat(StatType.charisma),
        lessThan(cursed.visibleStat(StatType.charisma)),
      );
      expect(StatChip.valueText(0, 1), '0 (1)');
      expect(StatChip.valueText(2, 2), '2');
    });
  });

  group('effects say what they give, and for how long', () {
    test('from their own data', () {
      const sharp = GameEffect(
        id: 'effect_fireside_sharp',
        name: 'Острый глаз',
        description: 'd',
        polarity: EffectPolarity.positive,
        duration: 4,
        remainingTurns: 4,
        statShifts: {StatType.attentiveness: 1},
      );
      expect(effectTerms(sharp), '+1 к внимательности · на 4 карточки');
      const host = GameEffect(
        id: 'h',
        name: 'h',
        description: 'd',
        polarity: EffectPolarity.positive,
        duration: 15,
        remainingTurns: 15,
        partyStatShifts: {StatType.luck: 1},
      );
      expect(effectTerms(host), '+1 к удаче всем остальным · на 15 карточек');
      const ward = GameEffect(
        id: 'w',
        name: 'w',
        description: 'd',
        polarity: EffectPolarity.positive,
        duration: -1,
        remainingTurns: -1,
        autoExpire: false,
        blocksNextNegativeEffect: true,
      );
      expect(effectTerms(ward), 'гасит следующую беду · до первой беды');
      expect(cardsWord(1), '1 карточку');
      expect(cardsWord(3), '3 карточки');
      expect(cardsWord(11), '11 карточек');
      expect(cardsWord(21), '21 карточку');
    });

    test('and no shipped effect repeats its numbers by hand', () async {
      final effects = await const EffectRepository().loadCatalog();
      // Stats only: «Дурное предзнаменование» counts danger, not a stat,
      // and says so in its own words.
      final handNumbers = RegExp(
        r'[+−-]\d+ к (силе|удаче|харизме|обаянию|выносливости|'
        r'внимательности|хитрости)',
      );
      for (final e in effects.all) {
        expect(
          handNumbers.hasMatch(e.description),
          isFalse,
          reason: '${e.id}: «${e.description}» — the terms line says it',
        );
      }
    });
  });

  group('a duel names its opponent before the choice', () {
    test('in the scene, and the throw goes against the one named', () {
      final duel = _card(
        'bet',
        description: '{opponent} бьёт тебя по рукам.',
        choices: const [
          CardChoice(label: 'Поспорить', actions: [StartDuelAction()]),
          CardChoice(label: 'Отказаться'),
        ],
      );
      for (var seed = 0; seed < 10; seed++) {
        final c = _controller(
          [duel],
          players: const ['Саня', 'Миша', 'Валера'],
          seed: seed,
        )..takeStep();
        final text = c.state.pendingCard!.description;
        expect(text, isNot(contains('{opponent}')));
        final gamble = c.gambleFor(choiceIndex: 0)!;
        expect(text, startsWith(gamble.opponent!));
        expect(gamble.opponent, isNot(gamble.challenger));
      }
    });

    test('every duel card in the content names one', () async {
      final cards = await const CardRepository().loadCards();
      for (final card in cards) {
        final duel = [
          ...card.actions,
          for (final c in card.choices) ...c.actions,
        ].any((a) => a is StartDuelAction);
        if (duel) {
          expect(card.description, contains('{opponent}'), reason: card.id);
        }
      }
    });
  });

  group('the weather', () {
    test('«the rain has just stopped» needs rain a moment ago', () {
      const cond = WeatherWithinTurnsCondition(weather: Weather.rain, turns: 4);
      bool at(WorldState w) => cond.isSatisfied(_weatherContext(w));
      expect(at(const WorldState()), isFalse); // sunny all along
      expect(at(const WorldState(currentWeather: Weather.rain)), isTrue);
      expect(
        at(
          const WorldState(
            previousWeather: Weather.rain,
            turnsInCurrentWeather: 2,
          ),
        ),
        isTrue,
      );
      expect(
        at(
          const WorldState(
            previousWeather: Weather.rain,
            turnsInCurrentWeather: 9,
          ),
        ),
        isFalse,
      );
    });

    test('no weather card falls in another weather', () async {
      final cards = await const CardRepository().loadCards();
      // Under a sky that has been clear all match, nothing that says it is
      // raining, has just rained, or is night is drawable.
      const rainy = [
        'world_road_rain_just_stopped',
        'world_road_after_storm',
        'world_road_cart_in_mud',
        'rest_boots_drying',
      ];
      const nightly = [
        'mountains_cold_night',
        'state_smuggler_hand_stays',
        'reveal_moonborn',
        'reveal_pathfinder',
      ];
      final sunny = _weatherContext(const WorldState());
      final night = _weatherContext(
        const WorldState(currentWeather: Weather.night),
      );
      for (final id in [...rainy, ...nightly]) {
        final card = cards.singleWhere((c) => c.id == id);
        final weatherGates = card.conditions.where(
          (c) =>
              c is InWeatherCondition ||
              c is NotInWeatherCondition ||
              c is WeatherWithinTurnsCondition,
        );
        expect(weatherGates, isNotEmpty, reason: id);
        expect(
          weatherGates.every((c) => c.isSatisfied(sunny)),
          isFalse,
          reason: '$id under a clear sky',
        );
        if (nightly.contains(id)) {
          expect(
            card.conditions.whereType<InWeatherCondition>().every(
              (c) => c.isSatisfied(night),
            ),
            isTrue,
            reason: id,
          );
        }
      }
      // And the sun scenes need the sun.
      for (final id in [
        'echo_gods_chosen_sun',
        'npc_alchemist_desert_again',
        'atmosphere_mountains_clouds_below_v3',
      ]) {
        final card = cards.singleWhere((c) => c.id == id);
        expect(
          card.conditions.whereType<InWeatherCondition>().single.weather,
          Weather.sunny,
          reason: id,
        );
      }
    });

    test('a change of weather remembers the one before', () {
      const executor = ActionExecutor();
      var ctx = _weatherContext(const WorldState(currentWeather: Weather.rain));
      ctx = executor.execute(
        const SetWeatherAction(weather: Weather.sunny),
        ctx,
      );
      expect(ctx.state.worldState.previousWeather, Weather.rain);
      expect(ctx.state.worldState.currentWeather, Weather.sunny);
    });
  });

  group('stops', () {
    test('at least $kMinStopGap steps of road between two, the halt counted '
        'from the last one left', () async {
      final cards = await const CardRepository().loadCards();
      final items = await const ItemRepository().loadCatalog();
      final effects = await const EffectRepository().loadCatalog();
      final adventures = await const AdventureRepository().loadCatalog();
      final biomes = await const BiomeRepository().loadCatalog();
      final origins = await const OriginRepository().loadCatalog();
      String stopOf(WorldState w) => w.flag('in_rest')
          ? 'rest'
          : w.flag('in_village')
          ? 'village'
          : w.flag('in_tavern')
          ? 'tavern'
          : '';
      var stops = 0;
      for (var seed = 0; seed < 25; seed++) {
        final pick = Random(seed);
        final c = GameController(
          playerNames: const ['A', 'B', 'C'],
          cards: cards,
          itemCatalog: items,
          effectCatalog: effects,
          adventureCatalog: adventures,
          biomeCatalog: biomes,
          originCatalog: origins,
          seed: seed,
          journeySteps: null,
          skipPrologue: true,
        );
        var prev = '';
        int? road;
        int? restLeftAt;
        for (var drawn = 0, g = 0; drawn < 100 && g < 600; g++) {
          c.takeStep();
          if (c.state.pendingParticipantSelection != null) {
            c.resolveParticipant(c.state.players.first.id);
          }
          final card = c.state.pendingCard;
          if (card == null) continue;
          drawn++;
          final n = card.choices.length;
          c.resolveCard(choiceIndex: n > 0 ? pick.nextInt(n) : null);
          for (var k = 0; c.state.pendingAdventureNode != null && k < 30; k++) {
            final m = c.state.pendingAdventureNode!.choices.length;
            c.resolveAdventureChoice(m == 0 ? 0 : pick.nextInt(m));
          }
          final stop = stopOf(c.state.worldState);
          if (stop.isNotEmpty && prev.isEmpty) {
            stops++;
            if (road != null) {
              expect(
                road,
                greaterThanOrEqualTo(kMinStopGap),
                reason: 'seed $seed: $stop after $road steps of road',
              );
            }
            if (stop == 'rest' && restLeftAt != null) {
              expect(
                c.state.partySteps - restLeftAt,
                greaterThanOrEqualTo(kRestInterval),
                reason: 'seed $seed: halt too soon after the last',
              );
            }
            road = 0;
          } else if (stop.isEmpty && prev.isEmpty && road != null) {
            road++;
          }
          if (stop.isEmpty && prev == 'rest') {
            restLeftAt = c.state.partySteps;
          }
          prev = stop;
          if (c.state.status != GameStatus.inProgress) break;
        }
      }
      expect(stops, greaterThan(100));
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('eight ways to break camp, the halt as long as before', () async {
      final cards = await const CardRepository().loadCards();
      final ways = cards.where(
        (c) => c.actions.any(
          (a) => a is SetWorldFlagAction && a.flag == 'in_rest' && !a.value,
        ),
      );
      expect(ways.map((c) => c.description).toSet(), hasLength(8));
      // Every halt card doubled when the night watch was split into calm and
      // trouble (#69), so 80 is the old 40.
      expect(ways.fold<int>(0, (s, c) => s + c.weight), 80);
    });
  });

  group('content taken out', () {
    test('the confession and the impersonation are gone', () async {
      final cards = await const CardRepository().loadCards();
      for (final card in cards) {
        expect(
          card.description,
          isNot(contains('Расскажи компании одну вещь')),
          reason: card.id,
        );
        expect(
          card.description,
          isNot(contains('Изобрази игрока слева')),
          reason: card.id,
        );
      }
    });

    test('«Ва-банк» waits for the underground casino', () async {
      final cards = await const CardRepository().loadCards();
      final card = cards.singleWhere((c) => c.id == 'luck_double_or_nothing');
      expect(
        card.conditions.whereType<WorldFlagSetCondition>().map((c) => c.flag),
        contains('in_underground_casino'),
      );
    });
  });

  test('a name starts with a capital', () {
    expect(capitalizeName('саня'), 'Саня');
    expect(capitalizeName('де Бирс'), 'Де Бирс');
    expect(capitalizeName(''), '');
  });
}
