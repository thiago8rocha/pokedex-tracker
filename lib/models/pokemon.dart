class Pokemon {
  final int id;
  final String name;
  final List<String> types;

  // Stats base
  final int baseHp;
  final int baseAttack;
  final int baseDefense;
  final int baseSpAttack;
  final int baseSpDefense;
  final int baseSpeed;

  // Sprites — null = variante não disponível para este Pokémon
  final String spriteUrl;          // official artwork padrão (já existia)
  final String? spriteShinyUrl;    // official artwork shiny
  final String? spritePixelUrl;    // pixel art 2D padrão
  final String? spritePixelShinyUrl; // pixel art 2D shiny
  final String? spritePixelFemaleUrl;// pixel art 2D feminino
  final String? spriteHomeUrl;     // Pokémon HOME render
  final String? spriteHomeShinyUrl;// Pokémon HOME shiny
  final String? spriteHomeFemaleUrl; // Pokémon HOME feminino

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
    this.spriteShinyUrl,
    this.spritePixelUrl,
    this.spritePixelShinyUrl,
    this.spritePixelFemaleUrl,
    this.spriteHomeUrl,
    this.spriteHomeShinyUrl,
    this.spriteHomeFemaleUrl,
  });

  int get totalStats =>
      baseHp + baseAttack + baseDefense + baseSpAttack + baseSpDefense + baseSpeed;

  // Conveniências: tem a variante?
  bool get hasShiny     => spriteShinyUrl != null;
  bool get hasFemale    => spritePixelFemaleUrl != null || spriteHomeFemaleUrl != null;
  bool get hasHome      => spriteHomeUrl != null;
  bool get hasPixel     => spritePixelUrl != null;
}