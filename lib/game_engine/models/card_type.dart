/// Thematic category of a [GameCard]. Purely a classification used for
/// display and future deck-building/filtering — the actual behaviour of a
/// card comes from its `actions`/`choices`, not its type.
enum CardType {
  event,
  trap,
  curse,
  blessing,
  duel,
  global,
  item,
  luck,
  legendary;

  static CardType fromJson(String value) => CardType.values.byName(value);

  String toJson() => name;
}
