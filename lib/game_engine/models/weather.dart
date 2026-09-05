/// The current weather, layered on top of [Biome] — answers "what's
/// happening around the party right now" where biome answers "where are
/// they." Deliberately a plain enum with no catalog/JSON content of its
/// own (unlike [Biome]): four fixed states are enough, and every one of
/// them is just another filter content already knows how to react to
/// (see `InWeatherCondition`/`CardTag`), the same "define once, react via
/// ordinary conditions" pattern [JourneyPhase] uses.
enum Weather {
  sunny,
  rain,
  fog,
  night;

  static Weather fromJson(String value) => Weather.values.byName(value);

  String toJson() => name;
}
