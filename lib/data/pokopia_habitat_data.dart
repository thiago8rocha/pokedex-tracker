// ─── MODELOS ──────────────────────────────────────────────────────────────────

class PokopiaEventHabitat {
  final int id;           // número no Event Habitat Dex (1, 2, 3...)
  final String name;      // nome em inglês
  final String eventName; // nome do evento ao qual pertence
  final String flavorText;
  final List<String> items;
  final List<PokopiaHabitatEntry> pokemon;
  // imagem local: assets/pokopia/habitats/event/habitat_NNN.png
  String get imageAsset => 'assets/pokopia/habitats/event/habitat_${id.toString().padLeft(3, '0')}.png';

  const PokopiaEventHabitat({
    required this.id,
    required this.name,
    required this.eventName,
    this.flavorText = '',
    required this.items,
    required this.pokemon,
  });
}

class PokopiaHabitat {
  final int id;           // número no Habitat Dex (1-211+)
  final String name;      // nome em inglês
  final List<String> biomes; // biomas onde o habitat pode aparecer
  final List<String> items;           // itens necessários
  final List<PokopiaHabitatEntry> pokemon; // pokémon possíveis
  final String flavorText; // descrição do habitat em PT-BR
  // imagem local: assets/pokopia/habitats/habitat_NNN.png
  String get imageAsset => 'assets/pokopia/habitats/habitat_${id.toString().padLeft(3, '0')}.png';

  const PokopiaHabitat({
    required this.id,
    required this.name,
    required this.biomes,
    required this.items,
    required this.pokemon,
    this.flavorText = '',
  });
}

class PokopiaHabitatEntry {
  final int speciesId;    // ID na PokeAPI
  final String name;      // nome do Pokémon
  final String rarity;    // Comum | Incomum | Raro | Muito Raro
  final String? time;     // null = qualquer | 'Dia' | 'Noite' | 'Manhã'
  final String? weather;  // null = qualquer | 'Ensolarado' | 'Chuvoso' | 'Nublado'

  const PokopiaHabitatEntry({
    required this.speciesId,
    required this.name,
    required this.rarity,
    this.time,
    this.weather,
  });
}

// ─── COR POR BIOMA ────────────────────────────────────────────────────────────
// Baseada na cor predominante da grama em cada região
const Map<String, int> biomeColor = {
  'Withered Wasteland': 0xFFA1887F, // marrom/terra seca
  'Bleak Beach':        0xFFF9A825, // areia dourada
  'Rocky Ridges':       0xFF795548, // pedra escura
  'Sparkling Skylands': 0xFF7986CB, // azul/lilás de céu
  'Palette Town':       0xFF4CAF50, // verde vivo
  'Dream Islands':      0xFF9C27B0, // roxo onírico
};

// ─── MAPA: speciesId → lista de habitats ─────────────────────────────────────
// Fonte: Serebii Habitat Dex (março 2026)
const Map<int, List<int>> pokemonHabitatMap = {
  1:   [1, 22],     // Bulbasaur
  2:   [22, 11],    // Ivysaur
  3:   [11],        // Venusaur
  4:   [1],         // Charmander
  5:   [17],        // Charmeleon
  6:   [1, 40],     // Charizard
  7:   [1, 4],      // Squirtle
  8:   [4],         // Wartortle
  9:   [36],        // Blastoise
  16:  [8, 6],      // Pidgey
  17:  [6],         // Pidgeotto
  23:  [],
  24:  [],
  25:  [],
  26:  [],
  35:  [],
  36:  [],
  39:  [],
  40:  [],
  41:  [],
  42:  [],
  43:  [1],         // Oddish
  44:  [57],        // Gloom
  46:  [],
  47:  [],
  48:  [7, 23],     // Venonat
  49:  [23, 7],     // Venomoth
  50:  [],
  51:  [],
  52:  [],
  53:  [],
  54:  [],
  55:  [],
  58:  [],
  59:  [],
  66:  [3],         // Machop
  67:  [],
  68:  [],
  69:  [2],         // Bellsprout
  70:  [21],        // Weepinbell
  71:  [21],        // Victreebel
  74:  [1],         // Geodude
  75:  [],
  79:  [5],         // Slowpoke
  80:  [5, 30],     // Slowbro
  81:  [38],        // Magnemite
  82:  [38],        // Magneton
  83:  [20],        // Farfetch'd
  88:  [],
  89:  [],
  92:  [],
  93:  [],
  94:  [],
  95:  [37],        // Onix
  100: [],
  101: [],
  102: [57],        // Exeggcute
  103: [57],        // Exeggutor
  104: [13],        // Cubone
  105: [],
  106: [24],        // Hitmonlee
  107: [24],        // Hitmonchan
  109: [],
  113: [25],        // Chansey
  123: [2],         // Scyther
  125: [],
  127: [2],         // Pinsir
  129: [],
  130: [],
  131: [],
  132: [],
  133: [8],         // Eevee
  134: [],
  143: [],
  156: [],
  157: [],
  158: [],
  163: [8, 31],     // Hoothoot
  164: [31],        // Noctowl
  167: [],
  168: [],
  169: [],
  172: [],
  173: [],
  174: [],
  178: [],
  179: [],
  180: [],
  181: [],
  182: [11],        // Bellossom
  183: [],
  184: [],
  193: [],
  194: [],
  196: [],
  199: [5],         // Slowking
  208: [37, 117],   // Steelix
  212: [2],         // Scizor
  214: [2],         // Heracross
  235: [85],        // Smeargle
  236: [],
  237: [],
  239: [],
  240: [8],         // Magby
  242: [25],        // Blissey
  252: [],
  255: [],
  256: [],
  257: [],
  259: [],
  260: [],
  272: [],
  278: [6, 36],     // Wingull
  279: [36],        // Pelipper
  296: [28],        // Makuhita
  297: [28],        // Hariyama
  298: [],
  302: [],
  303: [],
  313: [10],        // Volbeat
  314: [10],        // Illumise
  316: [19],        // Gulpin
  317: [19],        // Swalot
  324: [],
  327: [],
  331: [],
  332: [9],         // Cacturne
  333: [12],        // Swablu
  334: [12],        // Altaria
  353: [13],        // Shuppet
  354: [13],        // Banette
  355: [],
  356: [],
  359: [],
  361: [],
  362: [],
  393: [],
  394: [],
  395: [],
  401: [],
  402: [],
  415: [8],         // Combee
  416: [11],        // Vespiquen
  422: [27],        // Shellos
  423: [27],        // Gastrodon
  424: [],
  425: [16, 30],    // Drifloon
  426: [16],        // Drifblim
  429: [],
  440: [20],        // Happiny
  446: [17, 30],    // Munchlax
  461: [],
  462: [38],        // Magnezone
  466: [],
  468: [],
  469: [],
  470: [],
  471: [],
  473: [],
  474: [],
  475: [],
  477: [],
  478: [],
  480: [],
  481: [],
  482: [],
  529: [15],        // Drilbur
  530: [15],        // Excadrill
  531: [],
  532: [3],         // Timburr
  533: [3],         // Gurdurr
  534: [],
  568: [],
  569: [],
  570: [],
  571: [],
  572: [],
  573: [],
  607: [],
  608: [],
  609: [],
  610: [29],        // Axew
  611: [29],        // Fraxure
  612: [29],        // Haxorus
  669: [],
  670: [],
  671: [],
  700: [],
  702: [],
  703: [],
  704: [9],         // Goomy
  705: [4],         // Sliggoo
  706: [],
  721: [],
  736: [],
  737: [],
  738: [9],         // Vikavolt
  778: [],
  785: [],
  815: [],
  838: [],
  845: [4],         // Cramorant
  848: [],
  849: [],
  885: [],
  886: [],
  887: [],
  906: [],
  907: [],
  908: [],
  921: [],
  922: [],
  923: [],
  939: [],
  940: [],
  970: [],
  978: [],
  980: [],
  981: [],
  982: [],
  999: [],
  1000: [],
  1006: [],
};

// ─── DADOS DOS HABITATS ───────────────────────────────────────────────────────
// Habitat Dex confirmados via Serebii (março 2026)
// Numeração segue o Habitat Dex do jogo
// biomes: lista de biomas onde o habitat pode aparecer
const List<PokopiaHabitat> pokopiaHabitats = [
  // #001
  PokopiaHabitat(
    id: 1,
    name: 'Tall Grass',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Tall Grass x4'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 1,   name: 'Bulbasaur',  rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 4,   name: 'Charmander', rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 7,   name: 'Squirtle',   rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 43,  name: 'Oddish',     rarity: 'Comum',     time: 'Noite'),
      PokopiaHabitatEntry(speciesId: 74,  name: 'Geodude',    rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 6,   name: 'Charizard',  rarity: 'Muito Raro'),
    ],
    flavorText: 'Quatro tufos de grama alta agrupados. O esconderijo perfeito para Pokémon pequenos.',
  ),
  // #002
  PokopiaHabitat(
    id: 2,
    name: 'Tree-shaded Tall Grass',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Large Tree (any) x1', 'Tall Grass x4'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 69,  name: 'Bellsprout', rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 123, name: 'Scyther',    rarity: 'Incomum'),
      PokopiaHabitatEntry(speciesId: 212, name: 'Scizor',     rarity: 'Raro'),
      PokopiaHabitatEntry(speciesId: 127, name: 'Pinsir',     rarity: 'Incomum'),
      PokopiaHabitatEntry(speciesId: 214, name: 'Heracross',  rarity: 'Incomum'),
    ],
    flavorText: 'Grama alta sombreada por árvores, que permanece fresca mesmo sob o sol do meio-dia. Pokémon podem vir aqui para relaxar.',
  ),
  // #003
  PokopiaHabitat(
    id: 3,
    name: 'Boulder-shaded Tall Grass',
    biomes: ['Withered Wasteland', 'Rocky Ridges'],
    items: ['Large Boulder x1', 'Tall Grass x4'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 532, name: 'Timburr',  rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 533, name: 'Gurdurr',  rarity: 'Incomum'),
      PokopiaHabitatEntry(speciesId: 66,  name: 'Machop',   rarity: 'Comum'),
    ],
    flavorText: 'Grama alta próxima a uma grande pedra. Perfeita para brincar de esconde-esconde.',
  ),
  // #004
  PokopiaHabitat(
    id: 4,
    name: 'Hydrated Tall Grass',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Tall Grass x4', 'Water x2'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 7,   name: 'Squirtle',  rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 8,   name: 'Wartortle', rarity: 'Incomum'),
      PokopiaHabitatEntry(speciesId: 705, name: 'Sliggoo',   rarity: 'Raro',    weather: 'Chuvoso'),
      PokopiaHabitatEntry(speciesId: 845, name: 'Cramorant', rarity: 'Incomum'),
    ],
    flavorText: 'Grama alta à beira d\'água. Um habitat cheio de energia graças à água abundante.',
  ),
  // #005
  PokopiaHabitat(
    id: 5,
    name: 'Seaside Tall Grass',
    biomes: ['Bleak Beach'],
    items: ['Tall Grass x4', 'Ocean Water x2'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 79,  name: 'Slowpoke', rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 80,  name: 'Slowbro',  rarity: 'Incomum'),
      PokopiaHabitatEntry(speciesId: 199, name: 'Slowking', rarity: 'Raro'),
    ],
    flavorText: 'Grama alta que resiste à brisa do mar. Ideal para escapar do calor costeiro.',
  ),
  // #006
  PokopiaHabitat(
    id: 6,
    name: 'Elevated Tall Grass',
    biomes: ['Sparkling Skylands'],
    items: ['Tall Grass x4', 'High-up Location'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 16,  name: 'Pidgey',    rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 17,  name: 'Pidgeotto', rarity: 'Incomum'),
      PokopiaHabitatEntry(speciesId: 278, name: 'Wingull',   rarity: 'Comum'),
    ],
    flavorText: 'Uma área de altitude elevada onde ventos frios sopram pela grama.',
  ),
  // #007
  PokopiaHabitat(
    id: 7,
    name: 'Illuminated Tall Grass',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Tall Grass (any) x4', 'Lighting (any) x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 48, name: 'Venonat',  rarity: 'Comum',   time: 'Noite'),
      PokopiaHabitatEntry(speciesId: 49, name: 'Venomoth', rarity: 'Incomum', time: 'Noite'),
    ],
    flavorText: 'Grama alta suavemente iluminada que atrai Pokémon com seu brilho gentil.',
  ),
  // #008
  PokopiaHabitat(
    id: 8,
    name: 'Pretty Flower Bed',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Wildflowers x4'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 16,  name: 'Pidgey',   rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 163, name: 'Hoothoot', rarity: 'Comum',   time: 'Noite'),
      PokopiaHabitatEntry(speciesId: 415, name: 'Combee',   rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 240, name: 'Magby',    rarity: 'Incomum'),
      PokopiaHabitatEntry(speciesId: 133, name: 'Eevee',    rarity: 'Raro'),
    ],
    flavorText: 'Um belo canteiro de flores silvestres com uma fragrância leve e doce.',
  ),
  // #009
  PokopiaHabitat(
    id: 9,
    name: 'Tree-shaded Flower Bed',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Berry Tree (any) x1', 'Wildflowers x4'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 332, name: 'Cacturne', rarity: 'Incomum', time: 'Noite'),
      PokopiaHabitatEntry(speciesId: 704, name: 'Goomy',    rarity: 'Raro',    weather: 'Chuvoso'),
      PokopiaHabitatEntry(speciesId: 738, name: 'Vikavolt', rarity: 'Incomum'),
    ],
    flavorText: 'Flores desabrochando sob a sombra de árvores, atraindo Pokémon com seu aroma fresco.',
  ),
  // #010
  PokopiaHabitat(
    id: 10,
    name: 'Hydrated Flower Bed',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Wildflowers x4', 'Water x2'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 314, name: 'Illumise', rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 313, name: 'Volbeat',  rarity: 'Comum'),
    ],
    flavorText: 'Flores à beira da água desabrochando em abundância, atraindo Pokémon com seu aroma e água cristalina.',
  ),
  // #011
  PokopiaHabitat(
    id: 11,
    name: 'Field of Flowers',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Wildflowers x8'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 416, name: 'Vespiquen', rarity: 'Incomum'),
      PokopiaHabitatEntry(speciesId: 2,   name: 'Ivysaur',   rarity: 'Raro'),
      PokopiaHabitatEntry(speciesId: 182, name: 'Bellossom', rarity: 'Raro'),
    ],
    flavorText: 'Um amplo campo de flores, cada uma liberando uma fragrância agradável.',
  ),
  // #012
  PokopiaHabitat(
    id: 12,
    name: 'Elevated Flower Bed',
    biomes: ['Sparkling Skylands'],
    items: ['Wildflowers x4', 'High-up Location'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 333, name: 'Swablu',  rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 334, name: 'Altaria', rarity: 'Incomum'),
    ],
    flavorText: 'Flores desabrochando em grande altitude, com seu perfume carregado pelo vento.',
  ),
  // #013
  PokopiaHabitat(
    id: 13,
    name: 'Grave with Flowers',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Wildflowers x1', 'Gravestone x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 104, name: 'Cubone',   rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 353, name: 'Shuppet',  rarity: 'Comum',   time: 'Noite'),
      PokopiaHabitatEntry(speciesId: 354, name: 'Banette',  rarity: 'Incomum', time: 'Noite'),
    ],
    flavorText: 'Um lugar de descanso tranquilo com flores, irradiando elegância e calma.',
  ),
  // #015
  PokopiaHabitat(
    id: 15,
    name: 'Fresh Veggie Field',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Vegetable Field (any) x8'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 529, name: 'Drilbur',   rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 530, name: 'Excadrill', rarity: 'Incomum'),
    ],
    flavorText: 'Um campo de vegetais em crescimento que provavelmente atrai Pokémon que amam cultivar.',
  ),
  // #016
  PokopiaHabitat(
    id: 16,
    name: 'Riding Warm Updrafts',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Campfire x3'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 425, name: 'Drifloon', rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 426, name: 'Drifblim', rarity: 'Incomum'),
    ],
    flavorText: 'Ar quente das fogueiras subindo em espiral para o céu.',
  ),
  // #017
  PokopiaHabitat(
    id: 17,
    name: 'Campsite',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Campfire x1', 'Straw Stool x1', 'Straw Table x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 5,   name: 'Charmeleon', rarity: 'Incomum'),
      PokopiaHabitatEntry(speciesId: 446, name: 'Munchlax',   rarity: 'Raro'),
    ],
    flavorText: 'Um acampamento natural onde Pokémon se reúnem e se aquecem ao redor da fogueira.',
  ),
  // #019
  PokopiaHabitat(
    id: 19,
    name: 'Tantalizing Dining Set',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Plated Food x1', 'Seat (any) x1', 'Table (any) x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 316, name: 'Gulpin',  rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 317, name: 'Swalot',  rarity: 'Incomum'),
    ],
    flavorText: 'Uma mesa com comida preparada, atraindo Pokémon famintos.',
  ),
  // #020
  PokopiaHabitat(
    id: 20,
    name: 'Picnic Set',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Picnic Basket x1', 'Picnic Sheet x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 83,  name: "Farfetch'd", rarity: 'Incomum'),
      PokopiaHabitatEntry(speciesId: 440, name: 'Happiny',    rarity: 'Raro'),
    ],
    flavorText: 'Uma mesa com uma cesta que cria uma atmosfera relaxante de piquenique.',
  ),
  // #021
  PokopiaHabitat(
    id: 21,
    name: 'Flowery Table',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Small Vase x1', 'Seat (any) x1', 'Table (any) x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 70, name: 'Weepinbell', rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 71, name: 'Victreebel', rarity: 'Incomum'),
    ],
    flavorText: 'Uma mesa com um vaso de flores onde Pokémon podem sentar e admirar as flores.',
  ),
  // #022
  PokopiaHabitat(
    id: 22,
    name: 'Bench with Greenery',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Hedge (any) x2', 'Seat (any) x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 1, name: 'Bulbasaur', rarity: 'Incomum'),
      PokopiaHabitatEntry(speciesId: 2, name: 'Ivysaur',   rarity: 'Raro'),
    ],
    flavorText: 'Um banco próximo a arbustos onde Pokémon podem descansar tranquilamente.',
  ),
  // #023
  PokopiaHabitat(
    id: 23,
    name: 'Illuminated Bench',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Streetlight (any) x1', 'Seat (wide) x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 48, name: 'Venonat',  rarity: 'Comum',   time: 'Noite'),
      PokopiaHabitatEntry(speciesId: 49, name: 'Venomoth', rarity: 'Incomum', time: 'Noite'),
    ],
    flavorText: 'Um banco suavemente iluminado que atrai Pokémon.',
  ),
  // #024
  PokopiaHabitat(
    id: 24,
    name: 'Exercise Resting Spot',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Punching Bag x1', 'Seat (any) x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 107, name: 'Hitmonchan', rarity: 'Incomum'),
      PokopiaHabitatEntry(speciesId: 106, name: 'Hitmonlee',  rarity: 'Incomum'),
    ],
    flavorText: 'Um lugar de descanso para Pokémon após o treino.',
  ),
  // #025
  PokopiaHabitat(
    id: 25,
    name: 'Urgent Care',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['First Aid Kit x1', 'Seat (any) x1', 'Table (any) x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 113, name: 'Chansey',  rarity: 'Raro'),
      PokopiaHabitatEntry(speciesId: 242, name: 'Blissey',  rarity: 'Muito Raro'),
    ],
    flavorText: 'Um lugar onde Pokémon curandeiros podem aparecer para ajudar os feridos.',
  ),
  // #027
  PokopiaHabitat(
    id: 27,
    name: 'Road Sign',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Arrow Sign x1', 'Wooden Path x3'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 422, name: 'Shellos',   rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 423, name: 'Gastrodon', rarity: 'Incomum'),
    ],
    flavorText: 'Uma placa que pode orientar Pokémon errantes.',
  ),
  // #028
  PokopiaHabitat(
    id: 28,
    name: 'Large Luggage Carrier',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Cart x1', 'Cardboard Boxes x2'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 296, name: 'Makuhita',  rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 297, name: 'Hariyama',  rarity: 'Incomum'),
    ],
    flavorText: 'Um carrinho capaz de transportar grandes caixas.',
  ),
  // #029
  PokopiaHabitat(
    id: 29,
    name: "Lumberjack's Workplace",
    biomes: ['Withered Wasteland', 'Rocky Ridges'],
    items: ['Log Chair x1', 'Cart x1', 'Tree Stump (any) x1', 'Log Table x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 610, name: 'Axew',    rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 611, name: 'Fraxure', rarity: 'Incomum'),
      PokopiaHabitatEntry(speciesId: 612, name: 'Haxorus', rarity: 'Raro'),
    ],
    flavorText: 'Uma área de corte de troncos com ferramentas e uma cadeira de descanso.',
  ),
  // #030
  PokopiaHabitat(
    id: 30,
    name: 'Bed with a Plush',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Bed (any) x1', 'Doll (any) x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 425, name: 'Drifloon', rarity: 'Incomum'),
      PokopiaHabitatEntry(speciesId: 446, name: 'Munchlax', rarity: 'Incomum'),
    ],
    flavorText: 'Uma cama com um brinquedo de pelúcia, oferecendo conforto para Pokémon pequenos.',
  ),
  // #031
  PokopiaHabitat(
    id: 31,
    name: 'Gently Lit Bed',
    biomes: ['Withered Wasteland', 'Bleak Beach', 'Rocky Ridges', 'Sparkling Skylands', 'Palette Town'],
    items: ['Slender Candle x1', 'Bed (any) x1', 'Table (any) x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 163, name: 'Hoothoot', rarity: 'Comum',   time: 'Noite'),
      PokopiaHabitatEntry(speciesId: 164, name: 'Noctowl',  rarity: 'Incomum', time: 'Noite'),
    ],
    flavorText: 'Uma cama com iluminação suave para descanso tranquilo.',
  ),
  // #036
  PokopiaHabitat(
    id: 36,
    name: 'Floating in the Shade',
    biomes: ['Bleak Beach'],
    items: ['Inflatable Boat x1', 'Beach Parasol x1', 'Water x2'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 9,   name: 'Blastoise', rarity: 'Raro'),
      PokopiaHabitatEntry(speciesId: 278, name: 'Wingull',   rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 279, name: 'Pelipper',  rarity: 'Incomum'),
    ],
    flavorText: 'Uma boia inflável com sombra para relaxar.',
  ),
  // #037
  PokopiaHabitat(
    id: 37,
    name: 'Smooth Tall Grass',
    biomes: ['Withered Wasteland'],
    items: ['Dry Tall Grass x4', 'Smooth Rock x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 95,  name: 'Onix',    rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 208, name: 'Steelix', rarity: 'Incomum'),
    ],
    flavorText: 'Grama alta enfraquecida por uma estranha pedra lisa.',
  ),
  // #038
  PokopiaHabitat(
    id: 38,
    name: 'Factory Storage',
    biomes: ['Sparkling Skylands'],
    items: ['Streetlight (any) x1', 'Control Unit x1', 'Metal Drum x1', 'Jumbled Cords x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 81,  name: 'Magnemite', rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 82,  name: 'Magneton',  rarity: 'Incomum'),
      PokopiaHabitatEntry(speciesId: 462, name: 'Magnezone', rarity: 'Raro'),
    ],
    flavorText: 'Uma área de armazenamento industrial sem funcionamento.',
  ),
  // #040
  PokopiaHabitat(
    id: 40,
    name: 'Berry-feast Campsite',
    biomes: ['Sparkling Skylands'],
    items: ['Castform Weather Charm (Sun) x2', 'Campfire x1', 'Berry Basket x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 6, name: 'Charizard', rarity: 'Muito Raro'),
    ],
    flavorText: 'Um acampamento centrado em uma festa de bagas.',
  ),
  // #057
  PokopiaHabitat(
    id: 57,
    name: 'Tropical Vibes',
    biomes: ['Bleak Beach'],
    items: ['Large Palm Tree x1', 'Seashore Flowers x4'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 44,  name: 'Gloom',      rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 102, name: 'Exeggcute',  rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 103, name: 'Exeggutor',  rarity: 'Incomum'),
    ],
    flavorText: 'Um habitat de lagoa tranquila.',
  ),
  // #085
  PokopiaHabitat(
    id: 85,
    name: 'Mini Game Corner',
    biomes: ['Palette Town'],
    items: ['Arcade Machine x1', 'Seat (any) x1', 'Punching Game x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 235, name: 'Smeargle', rarity: 'Incomum'),
    ],
  ),
  // #117
  PokopiaHabitat(
    id: 117,
    name: 'Clink-clang Iron Construction',
    biomes: ['Sparkling Skylands'],
    items: ['Iron Beam or Column x3', 'Wheelbarrow x1', 'Sandbags x1', 'Excavation Tools x1'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 208, name: 'Steelix', rarity: 'Raro'),
    ],
  ),
];

// ─── HABITATS DE EVENTO ───────────────────────────────────────────────────────
// Fonte: Serebii Event Habitat Dex + screenshots do usuário (março 2026)
// Imagens: assets/pokopia/habitats/event/habitat_NNN.png
/// Mapa: speciesId → lista de IDs de habitats de EVENTO onde o pokémon aparece
const Map<int, List<int>> pokemonEventHabitatMap = {
  187: [1],      // Hoppip   — Yellow Carpet
  188: [1, 2],   // Skiploom — Yellow Carpet + Field-trip Friends
  189: [1, 3],   // Jumpluff — Yellow Carpet + Dandelion Lunchtime
};

const List<PokopiaEventHabitat> pokopiaEventHabitats = [
  PokopiaEventHabitat(
    id: 1,
    name: 'Yellow Carpet',
    eventName: 'More Spores for Hoppip',
    flavorText: 'Um campo de flores amarelas quentes e desabrochadas. Só de olhar parece encher você de energia.',
    items: ['Dandy flowers x4'],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 187, name: 'Hoppip',  rarity: 'Comum'),
      PokopiaHabitatEntry(speciesId: 188, name: 'Skiploom', rarity: 'Raro'),
      PokopiaHabitatEntry(speciesId: 189, name: 'Jumpluff', rarity: 'Muito Raro'),
    ],
  ),
  PokopiaEventHabitat(
    id: 2,
    name: 'Field-trip Friends',
    eventName: 'More Spores for Hoppip',
    flavorText: 'Coloque a lancheira e a cantil na mochila, e está tudo pronto para a excursão.',
    items: [
      'Flower backpack x1',
      'Hoppip water bottle x1',
      'Lunch box x1',
    ],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 188, name: 'Skiploom', rarity: 'Raro'),
    ],
  ),
  PokopiaEventHabitat(
    id: 3,
    name: 'Dandelion Lunchtime',
    eventName: 'More Spores for Hoppip',
    flavorText: 'Lancheira? Pronta. Louças? Prontas. Hora do almoço no piquenique!',
    items: [
      'Dandy flowers x1',
      'Flower cushion x1',
      'Lunch box x1',
      'Flowery table setting x1',
    ],
    pokemon: [
      PokopiaHabitatEntry(speciesId: 189, name: 'Jumpluff', rarity: 'Raro'),
    ],
  ),
];