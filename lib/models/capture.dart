class Capture {
  final int pokemonId;
  final String pokedexId;
  final bool caught;

  const Capture({
    required this.pokemonId,
    required this.pokedexId,
    required this.caught,
  });

  Capture copyWith({bool? caught}) {
    return Capture(
      pokemonId: pokemonId,
      pokedexId: pokedexId,
      caught: caught ?? this.caught,
    );
  }

  Map<String, dynamic> toJson() => {
        'pokemonId': pokemonId,
        'pokedexId': pokedexId,
        'caught': caught,
      };

  factory Capture.fromJson(Map<String, dynamic> json) => Capture(
        pokemonId: json['pokemonId'] as int,
        pokedexId: json['pokedexId'] as String,
        caught: json['caught'] as bool,
      );
}