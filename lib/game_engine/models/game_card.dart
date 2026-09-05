import 'card_choice.dart';
import 'card_tag.dart';
import 'card_type.dart';
import 'event_participant.dart';
import 'game_action.dart';
import 'game_condition.dart';
import 'rarity.dart';

/// A single event card. Cards are pure data — parsed from JSON packs under
/// `assets/data/cards/` — so content authors can add hundreds more without
/// touching engine code, and split them across as many files as convenient
/// (see `JsonAssetLoader`).
final class GameCard {
  final String id;
  final String title;
  final String description;
  final CardType type;
  final Rarity rarity;

  /// Relative draw probability. A card with weight 20 is twice as likely to
  /// be drawn as one with weight 10 — cards are not equally likely.
  final int weight;

  /// Secondary, cross-cutting classification independent of [type] — see
  /// [CardTag]. Not currently consulted by the draw itself; available for
  /// future filtered draws (daily events, themed packs) via `CardCatalog`.
  final List<CardTag> tags;

  /// Every condition must hold for the card to be eligible for drawing —
  /// see [GameCondition]. Empty means "always eligible" (subject to the
  /// game mode's rarity pool, which `CardCatalog` always enforces
  /// regardless of this list).
  final List<GameCondition> conditions;

  /// Actions applied automatically when the card is resolved. Empty when
  /// the card instead presents [choices].
  final List<GameAction> actions;

  /// If non-empty, the player must pick one choice and only that choice's
  /// actions run.
  final List<CardChoice> choices;

  /// Who this event is about — see [EventParticipant]. Defaults to picking
  /// one random player, which is why none of the content authored before
  /// this field existed needs to change: it keeps happening to a single
  /// party member, just without the old "whose turn" framing.
  final EventParticipant participant;

  const GameCard({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.rarity,
    required this.weight,
    this.tags = const [],
    this.conditions = const [],
    this.actions = const [],
    this.choices = const [],
    this.participant = const RandomPlayerParticipant(),
  });

  bool get hasChoices => choices.isNotEmpty;

  bool hasTag(CardTag tag) => tags.contains(tag);

  /// Used by `GameController` to cache, in `GameState`, the same card with
  /// only the choices the player is currently eligible to see — mirrors
  /// `AdventureNode.withChoices` so the index the UI shows always lines up
  /// with the index `resolveCard` receives.
  GameCard withChoices(List<CardChoice> choices) => GameCard(
    id: id,
    title: title,
    description: description,
    type: type,
    rarity: rarity,
    weight: weight,
    tags: tags,
    conditions: conditions,
    actions: actions,
    choices: choices,
    participant: participant,
  );

  factory GameCard.fromJson(Map<String, dynamic> json) => GameCard(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    type: CardType.fromJson(json['type'] as String),
    rarity: Rarity.fromJson(json['rarity'] as String),
    weight: json['weight'] as int,
    tags: CardTag.listFromJson(json['tags'] as List<dynamic>?),
    conditions: GameCondition.listFromJson(
      json['conditions'] as List<dynamic>?,
    ),
    actions: GameAction.listFromJson(json['actions'] as List<dynamic>?),
    choices: (json['choices'] as List<dynamic>? ?? const [])
        .map((e) => CardChoice.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    participant: json['participant'] == null
        ? const RandomPlayerParticipant()
        : EventParticipant.fromJson(json['participant'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.toJson(),
    'rarity': rarity.toJson(),
    'weight': weight,
    'tags': CardTag.listToJson(tags),
    'conditions': GameCondition.listToJson(conditions),
    'actions': GameAction.listToJson(actions),
    'choices': choices.map((c) => c.toJson()).toList(growable: false),
    'participant': participant.toJson(),
  };
}
