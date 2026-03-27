import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

class PokedexSection {
  final String label;
  final String apiName;
  final bool isDlc;
  const PokedexSection({required this.label, required this.apiName, required this.isDlc});
}

// Mapeamento das gerações para separação na Nacional
class GenInfo {
  final String label;
  final String region;
  final int startId;
  final int endId;
  const GenInfo({required this.label, required this.region, required this.startId, required this.endId});
}

const List<GenInfo> nationalGens = [
  GenInfo(label: 'Gen I', region: 'Kanto', startId: 1, endId: 151),
  GenInfo(label: 'Gen II', region: 'Johto', startId: 152, endId: 251),
  GenInfo(label: 'Gen III', region: 'Hoenn', startId: 252, endId: 386),
  GenInfo(label: 'Gen IV', region: 'Sinnoh', startId: 387, endId: 493),
  GenInfo(label: 'Gen V', region: 'Unova', startId: 494, endId: 649),
  GenInfo(label: 'Gen VI', region: 'Kalos', startId: 650, endId: 721),
  GenInfo(label: 'Gen VII', region: 'Alola', startId: 722, endId: 809),
  GenInfo(label: 'Gen VIII', region: 'Galar/Hisui', startId: 810, endId: 905),
  GenInfo(label: 'Gen IX', region: 'Paldea', startId: 906, endId: 1025),
];

class PokeApiService {
  static const String _base = 'https://pokeapi.co/api/v2';

  static const Map<String, List<PokedexSection>> pokedexSections = {
    // ── Gen I ────────────────────────────────────────────────────
    "red___blue": [
      PokedexSection(label: 'Kanto', apiName: 'kanto', isDlc: false),
    ],
    "yellow": [
      PokedexSection(label: 'Kanto', apiName: 'kanto', isDlc: false),
    ],
    // ── Gen II ───────────────────────────────────────────────────
    "gold___silver": [
      PokedexSection(label: 'Johto', apiName: 'original-johto', isDlc: false),
    ],
    "crystal": [
      PokedexSection(label: 'Johto', apiName: 'original-johto', isDlc: false),
    ],
    // ── Gen III ──────────────────────────────────────────────────
    "ruby___sapphire": [
      PokedexSection(label: 'Hoenn', apiName: 'hoenn', isDlc: false),
    ],
    "firered___leafgreen_(gba)": [
      PokedexSection(label: 'Kanto', apiName: 'updated-kanto', isDlc: false),
    ],
    "emerald": [
      PokedexSection(label: 'Hoenn', apiName: 'updated-hoenn', isDlc: false),
    ],
    // ── Gen IV ───────────────────────────────────────────────────
    "diamond___pearl": [
      PokedexSection(label: 'Sinnoh', apiName: 'original-sinnoh', isDlc: false),
    ],
    "platinum": [
      PokedexSection(label: 'Sinnoh', apiName: 'extended-sinnoh', isDlc: false),
    ],
    "heartgold___soulsilver": [
      PokedexSection(label: 'Johto', apiName: 'updated-johto', isDlc: false),
    ],
    // ── Gen V ────────────────────────────────────────────────────
    "black___white": [
      PokedexSection(label: 'Unova', apiName: 'original-unova', isDlc: false),
    ],
    "black_2___white_2": [
      PokedexSection(label: 'Unova', apiName: 'updated-unova', isDlc: false),
    ],
    // ── Gen VI ───────────────────────────────────────────────────
    "x___y": [
      PokedexSection(label: 'Kalos Central', apiName: 'kalos-central', isDlc: false),
      PokedexSection(label: 'Kalos Coastal', apiName: 'kalos-coastal', isDlc: false),
      PokedexSection(label: 'Kalos Mountain', apiName: 'kalos-mountain', isDlc: false),
    ],
    "omega_ruby___alpha_sapphire": [
      PokedexSection(label: 'Hoenn', apiName: 'updated-hoenn-oras', isDlc: false),
    ],
    // ── Gen VII ──────────────────────────────────────────────────
    "sun___moon": [
      PokedexSection(label: 'Alola', apiName: 'original-alola', isDlc: false),
    ],
    "ultra_sun___ultra_moon": [
      PokedexSection(label: 'Alola', apiName: 'updated-alola', isDlc: false),
    ],
    // ── Gen VIII (Switch) ─────────────────────────────────────────
    "let_s_go_pikachu___eevee": [
      PokedexSection(label: "Let's Go Kanto", apiName: 'letsgo-kanto', isDlc: false),
    ],
    "sword___shield": [
      PokedexSection(label: 'Galar', apiName: 'galar', isDlc: false),
      PokedexSection(label: 'Isle of Armor', apiName: 'isle-of-armor', isDlc: true),
      PokedexSection(label: 'Crown Tundra', apiName: 'crown-tundra', isDlc: true),
    ],
    "brilliant_diamond___shining_pearl": [
      PokedexSection(label: 'Sinnoh', apiName: 'original-sinnoh-bdsp', isDlc: false),
    ],
    "legends_arceus": [
      PokedexSection(label: 'Hisui', apiName: 'hisui', isDlc: false),
    ],
    // ── Gen IX ────────────────────────────────────────────────────
    "scarlet___violet": [
      PokedexSection(label: 'Paldea', apiName: 'paldea', isDlc: false),
      PokedexSection(label: 'Teal Mask', apiName: 'kitakami', isDlc: true),
      PokedexSection(label: 'Indigo Disk', apiName: 'blueberry', isDlc: true),
    ],
    "legends_z-a": [
      PokedexSection(label: 'Lumiose', apiName: 'lumiose', isDlc: false),
      PokedexSection(label: 'Mega Dimension', apiName: 'mega-dimension', isDlc: true),
    ],
    // ── Especiais ─────────────────────────────────────────────────
    "firered___leafgreen": [
      PokedexSection(label: 'Kanto', apiName: 'updated-kanto', isDlc: false),
    ],
    "nacional": [
      PokedexSection(label: 'Nacional', apiName: 'national', isDlc: false),
    ],
  };

  // ─── BUSCA IDs + ENTRY NUMBER ─────────────────────────────────
  // Retorna mapa: sectionApiName → lista de (entryNumber, speciesId)
  Future<Map<String, List<_PokedexEntry>>> fetchEntriesBySection(String pokedexId) async {
    final sections = pokedexSections[pokedexId];
    if (sections == null) return {};

    final result = <String, List<_PokedexEntry>>{};

    for (final section in sections) {
      try {
        final url = Uri.parse('$_base/pokedex/${section.apiName}');
        final res = await http.get(url);
        if (res.statusCode != 200) continue;

        final data = json.decode(res.body) as Map<String, dynamic>;
        final rawEntries = data['pokemon_entries'] as List<dynamic>;

        final entries = <_PokedexEntry>[];
        for (final e in rawEntries) {
          final entryNumber = e['entry_number'] as int;
          final speciesUrl = e['pokemon_species']['url'] as String;
          final parts = speciesUrl.split('/');
          final speciesId = int.tryParse(parts[parts.length - 2]);
          if (speciesId != null) {
            entries.add(_PokedexEntry(entryNumber: entryNumber, speciesId: speciesId));
          }
        }
        entries.sort((a, b) => a.entryNumber.compareTo(b.entryNumber));
        result[section.apiName] = entries;
      } catch (_) {}
    }

    return result;
  }

  List<PokedexSection> getSections(String pokedexId) =>
      pokedexSections[pokedexId] ?? [];

  bool hasDlc(String pokedexId) =>
      (pokedexSections[pokedexId] ?? []).any((s) => s.isDlc);

  // ─── FETCH POKÉMON ───────────────────────────────────────────

  /// Busca o flavor text correto para o jogo ativo via /pokemon-species.
  Future<String> fetchFlavorText(int speciesId, String pokedexId) async {
    try {
      final res = await http.get(Uri.parse('$_base/pokemon-species/$speciesId'));
      if (res.statusCode != 200) return '';
      final data = json.decode(res.body) as Map<String, dynamic>;
      final entries = data['flavor_text_entries'] as List<dynamic>? ?? [];
      return _extractFlavorForGame(entries, pokedexId);
    } catch (_) {
      return '';
    }
  }

  /// Escolhe o flavor text mais adequado para o jogo ativo.
  String _extractFlavorForGame(List<dynamic> entries, String pokedexId) {
    // Mapa pokedexId → version-groups da PokeAPI
    const vgMap = {
      'red___blue':                    ['red-blue'],
      'gold___silver':                 ['gold-silver'],
      'ruby___sapphire':               ['ruby-sapphire'],
      'firered___leafgreen_(gba)':     ['firered-leafgreen'],
      'emerald':                       ['emerald'],
      'diamond___pearl':               ['diamond-pearl'],
      'platinum':                      ['platinum'],
      'heartgold___soulsilver':        ['heartgold-soulsilver'],
      'black___white':                 ['black-white'],
      'black_2___white_2':             ['black-2-white-2'],
      'x___y':                         ['x-y'],
      'omega_ruby___alpha_sapphire':   ['omega-ruby-alpha-sapphire'],
      'sun___moon':                    ['sun-moon'],
      'ultra_sun___ultra_moon':        ['ultra-sun-ultra-moon'],
      'lets_go_pikachu___eevee':       ['lets-go-pikachu-lets-go-eevee'],
      'sword___shield':                ['sword-shield'],
      'brilliant_diamond___shining_pearl': ['brilliant-diamond-and-shining-pearl'],
      'legends_arceus':                ['legends-arceus'],
      'scarlet___violet':              ['scarlet-violet'],
      'legends_z-a':                   ['legends-za'],
    };
    String clean(String s) => s.replaceAll('\n', ' ').replaceAll('\f', ' ').trim();
    bool isPt(String l) => l == 'pt-BR' || l == 'pt';
    final groups = vgMap[pokedexId];
    if (groups != null) {
      // Tenta achar texto PT ou EN para o version-group do jogo
      const versionToGroup = {
        'sword': 'sword-shield', 'shield': 'sword-shield',
        'scarlet': 'scarlet-violet', 'violet': 'scarlet-violet',
        'lets-go-pikachu': 'lets-go-pikachu-lets-go-eevee',
        'lets-go-eevee': 'lets-go-pikachu-lets-go-eevee',
        'brilliant-diamond': 'brilliant-diamond-and-shining-pearl',
        'shining-pearl': 'brilliant-diamond-and-shining-pearl',
        'legends-arceus': 'legends-arceus', 'legends-za': 'legends-za',
        'firered': 'firered-leafgreen', 'leafgreen': 'firered-leafgreen',
        'ultra-sun': 'ultra-sun-ultra-moon', 'ultra-moon': 'ultra-sun-ultra-moon',
        'sun': 'sun-moon', 'moon': 'sun-moon',
        'omega-ruby': 'omega-ruby-alpha-sapphire', 'alpha-sapphire': 'omega-ruby-alpha-sapphire',
        'x': 'x-y', 'y': 'x-y',
        'black-2': 'black-2-white-2', 'white-2': 'black-2-white-2',
        'black': 'black-white', 'white': 'black-white',
        'heartgold': 'heartgold-soulsilver', 'soulsilver': 'heartgold-soulsilver',
        'platinum': 'platinum', 'diamond': 'diamond-pearl', 'pearl': 'diamond-pearl',
        'emerald': 'emerald', 'ruby': 'ruby-sapphire', 'sapphire': 'ruby-sapphire',
        'crystal': 'crystal', 'gold': 'gold-silver', 'silver': 'gold-silver',
        'red': 'red-blue', 'blue': 'red-blue',
      };
      for (final g in groups) {
        String ptText = '', enText = '';
        for (final e in entries) {
          final vg = versionToGroup[e['version']?['name'] as String? ?? ''] ?? '';
          if (vg != g) continue;
          final lang = e['language']['name'] as String;
          final text = clean(e['flavor_text'] as String? ?? '');
          if (isPt(lang) && ptText.isEmpty) ptText = text;
          if (lang == 'en' && enText.isEmpty) enText = text;
        }
        if (ptText.isNotEmpty) return ptText;
        if (enText.isNotEmpty) return enText;
      }
    }
    // Fallback: qualquer PT ou EN
    String anyPt = '', anyEn = '';
    for (final e in entries) {
      final lang = e['language']['name'] as String;
      final text = clean(e['flavor_text'] as String? ?? '');
      if (isPt(lang) && anyPt.isEmpty) anyPt = text;
      if (lang == 'en' && anyEn.isEmpty) anyEn = text;
    }
    return anyPt.isNotEmpty ? anyPt : anyEn;
  }

  Future<Map<String, dynamic>?> fetchPokemon(int speciesId) async {
    try {
      final res = await http.get(Uri.parse('$_base/pokemon/$speciesId'));
      if (res.statusCode != 200) return null;
      return json.decode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPokemonBatch(
    List<int> ids, {int batchSize = 10}) async {
    final results = <Map<String, dynamic>>[];
    for (int i = 0; i < ids.length; i += batchSize) {
      final batch = ids.skip(i).take(batchSize).toList();
      final batchResults = await Future.wait(batch.map(fetchPokemon));
      for (final r in batchResults) {
        if (r != null) results.add(r);
      }
    }
    return results;
  }

  List<String> extractTypes(Map<String, dynamic> pokemon) =>
      (pokemon['types'] as List<dynamic>)
          .map((t) => t['type']['name'] as String)
          .toList();

  String? extractSprite(Map<String, dynamic> pokemon) {
    try {
      return pokemon['sprites']['other']['official-artwork']['front_default'] as String?;
    } catch (_) {
      return pokemon['sprites']['front_default'] as String?;
    }
  }

  /// Extrai todos os URLs de sprite úteis para o header de detalhe.
  /// Retorna null para variantes inexistentes (campo null na API).
  Map<String, String?> extractAllSprites(Map<String, dynamic> pokemon) {
    String? s(List<String> path) {
      try {
        dynamic node = pokemon['sprites'];
        for (final key in path) node = node[key];
        return node as String?;
      } catch (_) { return null; }
    }
    return {
      // Artwork oficial
      'default':       s(['other', 'official-artwork', 'front_default']),
      'shiny':         s(['other', 'official-artwork', 'front_shiny']),
      // Pixel art 2D
      'pixel':         s(['front_default']),
      'pixelShiny':    s(['front_shiny']),
      'pixelFemale':   s(['front_female']),
      // Pokémon HOME (render de alta qualidade)
      'home':          s(['other', 'home', 'front_default']),
      'homeShiny':     s(['other', 'home', 'front_shiny']),
      'homeFemale':    s(['other', 'home', 'front_female']),
      'homeShinyFemale': null, // não exposto diretamente pela API no campo sprites
    };
  }

  Map<String, int> extractStats(Map<String, dynamic> pokemon) {
    final result = <String, int>{};
    for (final stat in pokemon['stats'] as List<dynamic>) {
      result[stat['stat']['name'] as String] = stat['base_stat'] as int;
    }
    return result;
  }
}

// Modelo interno para entrada da Pokedex
class _PokedexEntry {
  final int entryNumber; // número dentro da dex (ex: #025 no Galar)
  final int speciesId;   // ID nacional (para buscar sprite/stats na API)
  const _PokedexEntry({required this.entryNumber, required this.speciesId});
}
// ─── LISTA POKOPIA ────────────────────────────────────────────────
// 300 Pokémon no jogo (IDs da PokeAPI / nacional)
// 300 Pokémon no jogo + Ditto (você) + Peakychu (NPC, compartilha ID 25)
// Fontes cruzadas: Serebii (#001-#300), Bulbapedia, Nintendo Life, NintendoReporters, Dexerto (março 2026)
// IDs são da PokeAPI (National Dex)
const List<int> pokopiaSpeciesIds = [
  // Pokopia #001-#009 — Starters (Bulbasaur, Charmander, Squirtle)
  1, 2, 3, 4, 5, 6, 7, 8, 9,
  // #010-#012 — Pidgey line
  16, 17, 18,
  // #013-#016 — Oddish line + Bellossom
  43, 44, 45, 182,
  // #017-#018 — Paras line
  46, 47,
  // #019-#020 — Venonat line
  48, 49,
  // #021-#023 — Bellsprout line
  69, 70, 71,
  // #024-#026 — Slowpoke line (Slowking = 199)
  79, 80, 199,
  // #027-#029 — Magnemite line (Magnezone = 462)
  81, 82, 462,
  // #030-#031 — Onix + Steelix
  95, 208,
  // #032-#033 — Cubone + Marowak
  104, 105,
  // #034-#037 — Tyrogue + Hitmonlee + Hitmonchan + Hitmontop
  236, 106, 107, 237,
  // #038-#039 — Koffing + Weezing
  109, 110,
  // #040-#041 — Tangela + Tangrowth (465)
  114, 465,
  // #042-#044 — Scyther + Scizor + Pinsir
  123, 212, 127,
  // #045-#046 — Magikarp + Gyarados
  129, 130,
  // #047 — Ditto (você, o jogador)
  132,
  // #048-#049 — Hoothoot + Noctowl
  163, 164,
  // #050 — Heracross
  214,
  // #051-#052 — Volbeat + Illumise
  313, 314,
  // #053-#054 — Gulpin + Swalot
  316, 317,
  // #055-#056 — Cacnea + Cacturne
  331, 332,
  // #057-#058 — Combee + Vespiquen
  415, 416,
  // #059-#060 — Shellos + Gastrodon
  422, 423,
  // #061-#062 — Drifloon + Drifblim
  425, 426,
  // #063-#064 — Drilbur + Excadrill
  529, 530,
  // #065-#067 — Timburr + Gurdurr + Conkeldurr
  532, 533, 534,
  // #068-#070 — Litwick + Lampent + Chandelure
  607, 608, 609,
  // #071-#073 — Axew + Fraxure + Haxorus
  610, 611, 612,
  // #074-#076 — Goomy + Sliggoo + Goodra
  704, 705, 706,
  // #077 — Cramorant
  845,
  // #078-#081 — Pichu + Peakychu(=25) + Pikachu + Raichu
  172, 25, 26,
  // #082-#084 — Zubat + Golbat + Crobat
  41, 42, 169,
  // #085-#086 — Meowth + Persian
  52, 53,
  // #087-#088 — Psyduck + Golduck
  54, 55,
  // #089-#090 — Growlithe + Arcanine
  58, 59,
  // #091 — Farfetch'd
  83,
  // #092-#093 — Grimer + Muk
  88, 89,
  // #094-#096 — Gastly + Haunter + Gengar
  92, 93, 94,
  // #097-#098 — Voltorb + Electrode
  100, 101,
  // #099-#100 — Exeggcute + Exeggutor
  102, 103,
  // #101-#103 — Happiny + Chansey + Blissey
  440, 113, 242,
  // #104-#106 — Elekid + Electabuzz + Electivire
  239, 125, 466,
  // #107 — Lapras
  131,
  // #108-#109 — Munchlax + Snorlax
  446, 143,
  // #110-#111 — Spinarak + Ariados
  167, 168,
  // #112-#114 — Mareep + Flaaffy + Ampharos
  179, 180, 181,
  // #115-#117 — Azurill + Marill + Azumarill
  298, 183, 184,
  // #118-#119 — Wooper (Paldean=194) + Clodsire
  194, 980,
  // #120 — Smeargle
  235,
  // #121-#123 — Torchic + Combusken + Blaziken
  255, 256, 257,
  // #124-#125 — Wingull + Pelipper
  278, 279,
  // #126-#127 — Makuhita + Hariyama
  296, 297,
  // #128 — Absol
  359,
  // #129-#131 — Piplup + Prinplup + Empoleon
  393, 394, 395,
  // #132 — Audino
  531,
  // #133-#134 — Trubbish + Garbodor
  568, 569,
  // #135-#136 — Zorua + Zoroark
  570, 571,
  // #137-#138 — Minccino + Cinccino
  572, 573,
  // #139-#141 — Grubbin + Charjabug + Vikavolt
  736, 737, 738,
  // #142 — Mimikyu
  778,
  // #143-#145 — Pawmi + Pawmo + Pawmot
  921, 922, 923,
  // #146 — Tatsugiri
  978,
  // #147-#148 — Ekans + Arbok
  23, 24,
  // #149-#151 — Cleffa + Clefairy + Clefable
  173, 35, 36,
  // #152-#154 — Igglybuff + Jigglypuff + Wigglytuff
  174, 39, 40,
  // #154-#155 — Diglett + Dugtrio
  50, 51,
  // #156-#158 — Geodude + Graveler + Golem
  74, 75, 76,
  // #159-#161 — Magby + Magmar + Magmortar
  240, 126, 467,
  // #162-#163 — Bonsly + Sudowoodo
  438, 185,
  // #164-#165 — Murkrow + Honchkrow
  198, 430,
  // #166-#168 — Larvitar + Pupitar + Tyranitar
  246, 247, 248,
  // #169-#171 — Lotad + Lombre + Ludicolo
  270, 271, 272,
  // #172 — Mawile
  303,
  // #173-#174 — Kricketot + Kricketune
  401, 402,
  // #175 — Chatot
  441,
  // #176-#177 — Riolu + Lucario
  447, 448,
  // #178 — Rotom
  479,
  // #179-#180 — Larvesta + Volcarona
  636, 637,
  // #181-#183 — Rowlet + Dartrix + Decidueye
  722, 723, 724,
  // #184-#186 — Scorbunny + Raboot + Cinderace
  813, 814, 815,
  // #187-#188 — Skwovet + Greedent
  819, 820,
  // #189-#191 — Rookidee + Corvisquire + Corviknight
  821, 822, 823,
  // #192-#194 — Rolycoly + Carkol + Coalossal
  838, 839, 840,
  // #195-#196 — Toxel + Toxtricity
  848, 849,
  // #197-#199 — Frigibax + Arctibax + Baxcalibur
  936, 937, 998,
  // #200-#204 — Eevee + Vaporeon + Jolteon + Flareon
  133, 134, 135, 136,
  // #205-#206 — Espeon + Umbreon
  196, 197,
  // #207-#208 — Glaceon + Leafeon
  471, 470,
  // #209 — Sylveon
  700,
  // #210-#212 — Togepi + Togetic + Togekiss
  175, 176, 468,
  // #213-#214 — Natu + Xatu
  177, 178,
  // #215-#218 — Ralts + Kirlia + Gardevoir + Gallade
  280, 281, 282, 475,
  // #219-#220 — Swablu + Altaria
  333, 334,
  // #221-#223 — Dratini + Dragonair + Dragonite
  147, 148, 149,
  // #224-#225 — Misdreavus + Mismagius
  200, 429,
  // #226-#227 — Snubbull + Granbull
  209, 210,
  // #228-#229 — Phanpy + Donphan
  231, 232,
  // #230-#231 — Girafarig + Farigiraf
  203, 981,
  // #232-#233 — Dunsparce + Dudunsparce
  206, 982,
  // #234-#235 — Yanma + Yanmega
  193, 469,
  // #236-#237 — Aipom + Ambipom
  190, 424,
  // #238-#239 — Sneasel + Weavile
  215, 461,
  // #240-#242 — Swinub + Piloswine + Mamoswine
  220, 221, 473,
  // #243-#245 — Snorunt + Glalie + Froslass
  361, 362, 478,
  // #246-#248 — Duskull + Dusclops + Dusknoir
  355, 356, 477,
  // #249-#250 — Shuppet + Banette
  353, 354,
  // #251 — Sableye
  302,
  // #252-#254 — Mudkip + Marshtomp + Swampert
  258, 259, 260,
  // #255-#257 — Treecko + Grovyle + Sceptile
  252, 253, 254,
  // #258-#260 — Cyndaquil + Quilava + Typhlosion
  155, 156, 157,
  // #261-#263 — Totodile + Croconaw + Feraligatr
  158, 159, 160,
  // #264-#266 — Chikorita + Bayleef + Meganium
  152, 153, 154,
  // #267-#269 — Porygon + Porygon2 + Porygon-Z
  137, 233, 474,
  // #270-#272 — Dreepy + Drakloak + Dragapult
  885, 886, 887,
  // #273-#275 — Sprigatito + Floragato + Meowscarada
  906, 907, 908,
  // #276-#277 — Fidough + Dachsbun
  924, 925,
  // #278-#280 — Charcadet + Armarouge + Ceruledge
  855, 901, 902,
  // #281-#282 — Wattrel + Kilowattrel
  939, 940,
  // #283-#285 — Snivy + Servine + Serperior
  495, 496, 497,
  // #286-#288 — Froakie + Frogadier + Greninja
  656, 657, 658,
  // #289-#291 — Trapinch + Vibrava + Flygon
  328, 329, 330,
  // #292-#293 — Tyrunt + Tyrantrum
  696, 697,
  // #294-#295 — Amaura + Aurorus
  698, 699,
  // #296-#297 — Noibat + Noivern
  714, 715,
  // #298-#300 — Tinkatink + Tinkatuff + Tinkaton
  957, 958, 959,
  // Extras confirmados por fontes (fora da numeração principal):
  // Poliwag line + Politoed
  60, 61, 186,
  // Abra + Kadabra + Alakazam
  63, 64, 65,
  // Machop + Machoke + Machamp
  66, 67, 68,
  // Flabebe + Floette + Florges
  669, 670, 671,
  // Dedenne + Carbink
  702, 703,
  // Poltchageist
  970,
  // Gimmighoul + Gholdengo
  999, 1000,
  // Kyogre
  382,
  // Volcanion
  721,
  // Lake guardians
  480, 481, 482,
  // Legendaries
  243, 244, 245, 249, 250, 144, 145, 146, 150, 151,
];

// Mapa de especialidades por speciesId para filtro na Pokédex Pokopia
// speciesId → lista de especialidades que esse Pokémon tem
const Map<int, List<String>> pokopiaSpecialtyMap = {
  1:   ['Grow'],       // Bulbasaur
  3:   ['Grow'],       // Venusaur
  4:   ['Burn'],       // Charmander
  6:   ['Burn', 'Fly'],// Charizard
  7:   ['Water'],      // Squirtle
  8:   ['Water'],      // Wartortle
  9:   ['Water', 'Bulldoze'], // Blastoise
  16:  ['Fly'],        // Pidgey
  18:  ['Fly'],        // Pidgeot
  23:  ['Litter'],     // Ekans
  25:  ['Generate'],   // Pikachu
  26:  ['Generate'],   // Raichu
  35:  ['Hype'],       // Clefairy
  37:  ['Burn'],       // Vulpix
  39:  ['Hype'],       // Jigglypuff
  43:  ['Grow'],       // Oddish
  46:  ['Gather Honey'],// Paras
  47:  ['Gather Honey'],// Parasect
  48:  ['Gather'],     // Venonat
  49:  ['Gather'],     // Venomoth
  50:  ['Search'],     // Diglett
  51:  ['Search'],     // Dugtrio
  52:  ['Collect'],    // Meowth
  53:  ['Collect'],    // Persian
  54:  ['Water'],      // Psyduck
  58:  ['Burn'],       // Growlithe
  59:  ['Burn'],       // Arcanine
  60:  ['Water'],      // Poliwag
  63:  ['Teleport'],   // Abra
  65:  ['Teleport'],   // Alakazam
  66:  ['Build'],      // Machop
  69:  ['Grow'],       // Bellsprout
  70:  ['Grow'],       // Weepinbell
  74:  ['Crush'],      // Geodude
  75:  ['Crush'],      // Graveler
  79:  ['Yawn'],       // Slowpoke
  80:  ['Yawn'],       // Slowbro
  81:  ['Generate'],   // Magnemite
  83:  ['Gather'],     // Farfetch'd
  95:  ['Build', 'Bulldoze'], // Onix
  100: ['Explode'],    // Voltorb
  103: ['Grow'],       // Exeggutor
  104: ['Search'],     // Cubone
  106: ['Build'],      // Hitmonlee
  107: ['Build'],      // Hitmonchan
  113: ['Hype'],       // Chansey
  123: ['Chop'],       // Scyther
  126: ['Burn'],       // Magmar
  127: ['Chop'],       // Pinsir
  129: ['Gather'],     // Magikarp
  131: ['Water', 'Storage'], // Lapras
  132: ['Transform'],  // Ditto
  133: ['Gather'],     // Eevee
  134: ['Water'],      // Vaporeon
  135: ['Generate'],   // Jolteon
  136: ['Burn'],       // Flareon
  143: ['Yawn', 'Bulldoze'], // Snorlax
  147: ['Water'],      // Dratini
  148: ['Water'],      // Dragonair
  149: ['Fly'],        // Dragonite
  156: ['Burn'],       // Quilava
  163: ['Fly'],        // Hoothoot
  164: ['Fly'],        // Noctowl
  167: ['Search'],     // Spinarak
  172: ['Generate'],   // Pichu
  175: ['Hype'],       // Togepi
  176: ['Fly', 'Hype'],// Togetic
  177: ['Fly'],        // Natu
  183: ['Water'],      // Marill
  185: ['Build'],      // Sudowoodo
  186: ['Water'],      // Politoed
  190: ['Gather'],     // Aipom
  196: ['Teleport'],   // Espeon
  197: ['Teleport'],   // Umbreon
  202: ['Yawn'],       // Wobbuffet
  208: ['Build', 'Bulldoze'], // Steelix
  214: ['Build'],      // Heracross
  233: ['Generate'],   // Porygon2
  236: ['Build'],      // Tyrogue
  240: ['Burn'],       // Magby
  243: ['Generate'],   // Raikou
  246: ['Crush'],      // Larvitar
  249: ['Fly'],        // Lugia — Dream Island
  250: ['Fly'],        // Ho-Oh — Sparkling Skylands
  248: ['Bulldoze'],   // Tyranitar
  255: ['Burn'],       // Torchic
  270: ['Water', 'Grow'],    // Lotad
  272: ['Water', 'Grow'],    // Ludicolo
  278: ['Fly'],        // Wingull
  282: ['Teleport'],   // Gardevoir
  296: ['Build'],      // Makuhita
  298: ['Water'],      // Azurill
  303: ['Chop'],       // Mawile
  312: ['Generate'],   // Minun
  313: ['Hype'],       // Volbeat
  316: ['Litter'],     // Gulpin
  324: ['Burn'],       // Torkoal
  331: ['Grow'],       // Cacnea
  332: ['Grow'],       // Cacturne
  333: ['Fly'],        // Swablu
  393: ['Water'],      // Piplup
  415: ['Gather Honey'], // Combee
  416: ['Gather Honey', 'Rarify'], // Vespiquen
  422: ['Water'],      // West Sea Shellos
  423: ['Water'],      // West Sea Gastrodon
  425: ['Fly', 'Dream Island'], // Drifloon
  439: ['Hype'],       // Mime Jr.
  440: ['Hype'],       // Happiny
  446: ['Yawn', 'Storage'], // Munchlax
  447: ['Build'],      // Riolu
  448: ['Build'],      // Lucario
  470: ['Grow'],       // Leafeon
  471: ['Water'],      // Glaceon
  478: ['Water'],      // Froslass
  529: ['Search'],     // Drilbur
  530: ['Search', 'Bulldoze'], // Excadrill
  531: ['Hype'],       // Audino
  532: ['Build'],      // Timburr
  533: ['Build'],      // Gurdurr
  568: ['Recycle', 'Litter'], // Trubbish
  570: ['Search'],     // Zorua
  572: ['Gather'],     // Minccino
  573: ['Gather'],     // Cinccino
  607: ['Burn'],       // Litwick
  608: ['Burn'],       // Lampent
  609: ['Burn'],       // Chandelure
  610: ['Chop'],       // Axew
  612: ['Chop', 'Bulldoze'], // Haxorus
  637: ['Burn', 'Fly'],// Volcarona
  658: ['Water'],      // Greninja
  700: ['Hype'],       // Sylveon
  702: ['Generate'],   // Dedenne
  704: ['Water'],      // Goomy
  706: ['Water'],      // Goodra
  722: ['Fly'],        // Rowlet
  738: ['Generate'],   // Vikavolt
  778: ['Rarify'],     // Mimikyu
  813: ['Build'],      // Scorbunny
  814: ['Build'],      // Raboot
  819: ['Gather'],     // Skwovet
  821: ['Fly'],        // Rookidee
  839: ['Burn'],       // Carkol
  845: ['Fly'],        // Cramorant
  848: ['Generate'],   // Toxel
  885: ['Fly'],        // Dreepy
  906: ['Grow'],       // Sprigatito
  921: ['Generate'],   // Pawmi
  940: ['Generate', 'Fly'], // Kilowattrel
  970: ['Grow'],       // Glimmora
  978: ['Water'],      // Tatsugiri
  999: ['Collect'],    // Gimmighoul
  151: ['Transform'],  // Mew
  150: ['Teleport'],   // Mewtwo
  144: ['Fly'],        // Articuno
  145: ['Generate', 'Fly'], // Zapdos
  146: ['Burn', 'Fly'],// Moltres
  721: ['Burn'],       // Volcanion
};

// ─── POKOPIA EVENT POKÉDEX ────────────────────────────────────────────────────
// Pokémon exclusivos de eventos temporários (hardcoded no jogo, recorrem anualmente)
// Fonte: Miketendo64, Nintendo Life, Bulbapedia (março 2026)

class PokopiaEvent {
  final int eventDexNumber;  // número na Pokédex de Evento
  final int speciesId;       // ID nacional (PokeAPI)
  final String name;
  final String eventName;    // nome do evento
  final String startDate;    // MM/DD (repete anualmente)
  final String endDate;
  final List<String> specialties;

  const PokopiaEvent({
    required this.eventDexNumber,
    required this.speciesId,
    required this.name,
    required this.eventName,
    required this.startDate,
    required this.endDate,
    required this.specialties,
  });
}

const List<PokopiaEvent> pokopiaEventPokemon = [
  // Evento: More Spores for Hoppip
  // 10 de março → 25 de março (anual)
  PokopiaEvent(
    eventDexNumber: 1,
    speciesId: 187,         // Hoppip
    name: 'Hoppip',
    eventName: 'More Spores for Hoppip',
    startDate: '03/10',
    endDate: '03/25',
    specialties: ['Grow'],
  ),
  PokopiaEvent(
    eventDexNumber: 2,
    speciesId: 188,         // Skiploom
    name: 'Skiploom',
    eventName: 'More Spores for Hoppip',
    startDate: '03/10',
    endDate: '03/25',
    specialties: ['Grow'],
  ),
  PokopiaEvent(
    eventDexNumber: 3,
    speciesId: 189,         // Jumpluff
    name: 'Jumpluff',
    eventName: 'More Spores for Hoppip',
    startDate: '03/10',
    endDate: '03/25',
    specialties: ['Grow', 'Litter'],
  ),
  // Evento: Sableye — datas ainda não anunciadas
  PokopiaEvent(
    eventDexNumber: 4,
    speciesId: 302,         // Sableye
    name: 'Sableye',
    eventName: 'Sableye Event',
    startDate: '04/29',
    endDate: '05/13',
    specialties: [],
  ),
];

// IDs dos Pokémon de evento em ordem para a PokedexScreen
final List<int> pokopiaEventSpeciesIds =
    pokopiaEventPokemon.map((e) => e.speciesId).toList();