import '../logic/adventure_catalog.dart';
import '../logic/biome_catalog.dart';
import '../logic/card_catalog.dart';
import '../logic/effect_catalog.dart';
import '../logic/game_event_bus.dart';
import '../logic/item_catalog.dart';
import '../logic/origin_catalog.dart';
import '../logic/random_provider.dart';
import '../models/game_mode.dart';
import '../models/game_state.dart';
import '../models/player.dart';

/// The single object every engine operation works through: the mutable-ish
/// (immutable, but replaced wholesale) current [state] plus every service
/// an action, condition, or event reaction might need — randomness, content
/// catalogs, the event bus, and the active [mode].
///
/// Nothing in the engine reaches for a global, a singleton, or a
/// constructor-injected dependency of its own anymore: [ActionExecutor],
/// [GameCondition], [CardCatalog] and friends all take a `GameContext` and
/// read whatever they need off it. That's what makes it possible to add a
/// new condition, action, or catalog lookup later without changing the
/// signature of everything that already exists.
///
/// [state] is the only field that changes turn to turn; everything else
/// (catalogs, the event bus, the random provider, the mode) is fixed for
/// the lifetime of one match, so [withState] is the only mutator needed.
final class GameContext {
  final GameState state;
  final RandomProvider random;
  final CardCatalog cardCatalog;
  final ItemCatalog itemCatalog;
  final EffectCatalog effectCatalog;
  final AdventureCatalog adventureCatalog;
  final BiomeCatalog biomeCatalog;
  final OriginCatalog originCatalog;
  final GameEventBus eventBus;
  final GameMode mode;

  const GameContext({
    required this.state,
    required this.random,
    required this.cardCatalog,
    required this.itemCatalog,
    required this.effectCatalog,
    required this.adventureCatalog,
    required this.biomeCatalog,
    required this.originCatalog,
    required this.eventBus,
    required this.mode,
  });

  List<Player> get players => state.players;

  Player get currentPlayer => state.currentPlayer;

  GameContext withState(GameState newState) => GameContext(
    state: newState,
    random: random,
    cardCatalog: cardCatalog,
    itemCatalog: itemCatalog,
    effectCatalog: effectCatalog,
    adventureCatalog: adventureCatalog,
    biomeCatalog: biomeCatalog,
    originCatalog: originCatalog,
    eventBus: eventBus,
    mode: mode,
  );
}
