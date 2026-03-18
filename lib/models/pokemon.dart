class Pokemon {
  final int id;
  final String name;
  final List<String> types;
  final int baseHp;
  final int baseAttack;
  final int baseDefense;
  final int baseSpAttack;
  final int baseSpDefense;
  final int baseSpeed;
  final String spriteUrl;

  const Pokemon({
    required this.id,
    required this.name,
    required this.types,
    required this.baseHp,
    required this.baseAttack,
    required this.baseDefense,
    required this.baseSpAttack,
    required this.baseSpDefense,
    required this.baseSpeed,
    required this.spriteUrl,
  });

  int get totalStats =>
      baseHp +
      baseAttack +
      baseDefense +
      baseSpAttack +
      baseSpDefense +
      baseSpeed;

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as List;
    int getStat(String name) => (stats.firstWhere(
          (s) => s['stat']['name'] == name,
        )['base_stat'] as int);

    final types = (json['types'] as List)
        .map((t) => t['type']['name'] as String)
        .toList();

    return Pokemon(
      id: json['id'] as int,
      name: json['name'] as String,
      types: types,
      baseHp: getStat('hp'),
      baseAttack: getStat('attack'),
      baseDefense: getStat('defense'),
      baseSpAttack: getStat('special-attack'),
      baseSpDefense: getStat('special-defense'),
      baseSpeed: getStat('speed'),
      spriteUrl: json['sprites']['other']['official-artwork']
              ['front_default'] as String? ??
          '',
    );
  }

  Pokemon copyWith({
    int? id,
    String? name,
    List<String>? types,
    int? baseHp,
    int? baseAttack,
    int? baseDefense,
    int? baseSpAttack,
    int? baseSpDefense,
    int? baseSpeed,
    String? spriteUrl,
  }) {
    return Pokemon(
      id: id ?? this.id,
      name: name ?? this.name,
      types: types ?? this.types,
      baseHp: baseHp ?? this.baseHp,
      baseAttack: baseAttack ?? this.baseAttack,
      baseDefense: baseDefense ?? this.baseDefense,
      baseSpAttack: baseSpAttack ?? this.baseSpAttack,
      baseSpDefense: baseSpDefense ?? this.baseSpDefense,
      baseSpeed: baseSpeed ?? this.baseSpeed,
      spriteUrl: spriteUrl ?? this.spriteUrl,
    );
  }
}