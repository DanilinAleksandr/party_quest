/// A named "chapter" of the journey — see the design doc's biome system.
///
/// A biome carries no mechanics of its own: it's pure identity (id, a
/// display name, an atmosphere blurb). Everything a biome actually *does* —
/// restricting which cards/adventure choices are available, feeling
/// different in tone — comes from ordinary content (`GameCard`,
/// `AdventureChoice`) gated with [InBiomeCondition]/[NotInBiomeCondition]
/// against `WorldState.currentBiomeId`. There is no separate "biome
/// modifier" system: a biome that should feel more dangerous just has more
/// of its own curse-flavoured cards, at ordinary weights, like any other
/// content.
final class Biome {
  final String id;
  final String name;
  final String description;

  const Biome({
    required this.id,
    required this.name,
    required this.description,
  });

  factory Biome.fromJson(Map<String, dynamic> json) => Biome(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
  };
}
