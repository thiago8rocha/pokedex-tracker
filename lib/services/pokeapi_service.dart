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

// Mapa de especialidades por speciesId — Fonte: Nintendo Life, VGC, RankedBoost (Março 2026)
// speciesId → lista de especialidades que esse Pokémon tem no jogo
const Map<int, List<String>> pokopiaSpecialtyMap = {
  // ── Bulbasaur line ──────────────────────────────────────────────
  1:   ['Grow'],                       // Bulbasaur
  2:   ['Grow'],                       // Ivysaur
  3:   ['Grow', 'Litter'],             // Venusaur
  // ── Charmander line ─────────────────────────────────────────────
  4:   ['Burn'],                       // Charmander
  5:   ['Burn'],                       // Charmeleon
  6:   ['Burn', 'Fly'],                // Charizard
  // ── Squirtle line ───────────────────────────────────────────────
  7:   ['Water'],                      // Squirtle
  8:   ['Water'],                      // Wartortle
  9:   ['Water', 'Trade'],             // Blastoise
  // ── Pidgey line ─────────────────────────────────────────────────
  16:  ['Fly', 'Search'],              // Pidgey
  17:  ['Fly', 'Search'],              // Pidgeotto
  18:  ['Fly', 'Search'],              // Pidgeot
  // ── Oddish line ─────────────────────────────────────────────────
  43:  ['Grow'],                       // Oddish
  44:  ['Grow'],                       // Gloom
  45:  ['Grow', 'Litter'],             // Vileplume
  182: ['Grow', 'Hype'],               // Bellossom
  // ── Paras line ──────────────────────────────────────────────────
  46:  ['Search'],                     // Paras
  47:  ['Search'],                     // Parasect
  // ── Venonat line ────────────────────────────────────────────────
  48:  ['Search'],                     // Venonat
  49:  ['Search'],                     // Venomoth
  // ── Bellsprout line ─────────────────────────────────────────────
  69:  ['Grow', 'Litter'],             // Bellsprout
  70:  ['Grow', 'Litter'],             // Weepinbell
  71:  ['Grow', 'Chop'],               // Victreebel
  // ── Slowpoke line ───────────────────────────────────────────────
  79:  ['Water', 'Yawn'],              // Slowpoke
  80:  ['Water', 'Trade'],             // Slowbro
  199: ['Water', 'Teleport'],          // Slowking
  // ── Magnemite line ──────────────────────────────────────────────
  81:  ['Generate'],                   // Magnemite
  82:  ['Generate'],                   // Magneton
  462: ['Generate', 'Recycle'],        // Magnezone
  // ── Onix / Steelix ──────────────────────────────────────────────
  95:  ['Crush', 'Bulldoze'],          // Onix
  208: ['Crush', 'Bulldoze'],          // Steelix
  // ── Cubone / Marowak ────────────────────────────────────────────
  104: ['Build'],                      // Cubone
  105: ['Build'],                      // Marowak
  // ── Tyrogue / Hitmon line ────────────────────────────────────────
  236: ['Trade'],                      // Tyrogue
  106: ['Trade'],                      // Hitmonlee
  107: ['Trade'],                      // Hitmonchan
  237: ['Trade'],                      // Hitmontop
  // ── Koffing / Weezing ───────────────────────────────────────────
  109: ['Recycle'],                    // Koffing
  110: ['Recycle'],                    // Weezing
  // ── Tangela / Tangrowth ─────────────────────────────────────────
  114: ['Grow', 'Litter'],             // Tangela
  465: ['Grow', 'Litter'],             // Tangrowth (NPC Professor Tangrowth = Appraise)
  // ── Scyther / Scizor / Pinsir ───────────────────────────────────
  123: ['Chop'],                       // Scyther
  212: ['Chop'],                       // Scizor
  127: ['Chop', 'Build'],              // Pinsir
  // ── Magikarp / Gyarados ─────────────────────────────────────────
  129: [],                             // Magikarp — N/A
  130: ['Water'],                      // Gyarados
  // ── Ditto ───────────────────────────────────────────────────────
  132: ['Transform'],                  // Ditto
  // ── Hoothoot / Noctowl ──────────────────────────────────────────
  163: ['Trade', 'Fly'],               // Hoothoot
  164: ['Trade', 'Fly'],               // Noctowl
  // ── Heracross ───────────────────────────────────────────────────
  214: ['Chop', 'Build'],              // Heracross
  // ── Volbeat / Illumise ──────────────────────────────────────────
  313: ['Hype'],                       // Volbeat
  314: ['Hype'],                       // Illumise
  // ── Gulpin / Swalot ─────────────────────────────────────────────
  316: ['Storage'],                    // Gulpin
  317: ['Storage'],                    // Swalot
  // ── Cacnea / Cacturne ───────────────────────────────────────────
  331: ['Grow'],                       // Cacnea
  332: ['Grow', 'Litter'],             // Cacturne
  // ── Combee / Vespiquen ──────────────────────────────────────────
  415: ['Litter'],                     // Combee
  416: ['Gather Honey', 'Search'],     // Vespiquen
  // ── Shellos / Gastrodon ─────────────────────────────────────────
  422: ['Water'],                      // Shellos
  423: ['Water', 'Trade'],             // Gastrodon
  // ── Drifloon / Drifblim ─────────────────────────────────────────
  425: ['Dream Island'],               // Drifloon
  426: ['Fly', 'Gather'],              // Drifblim
  // ── Drilbur / Excadrill ─────────────────────────────────────────
  529: ['Search'],                     // Drilbur
  530: ['Search', 'Chop'],             // Excadrill
  // ── Timburr line ────────────────────────────────────────────────
  532: ['Build'],                      // Timburr
  533: ['Build'],                      // Gurdurr
  534: ['Build', 'Crush'],             // Conkeldurr
  // ── Litwick line ────────────────────────────────────────────────
  607: ['Burn'],                       // Litwick
  608: ['Burn'],                       // Lampent
  609: ['Burn'],                       // Chandelure
  // ── Axew line ───────────────────────────────────────────────────
  610: ['Chop'],                       // Axew
  611: ['Chop'],                       // Fraxure
  612: ['Chop', 'Litter'],             // Haxorus
  // ── Goomy line ──────────────────────────────────────────────────
  704: ['Water'],                      // Goomy
  705: ['Water'],                      // Sliggoo
  706: ['Water'],                      // Goodra
  // ── Cramorant ───────────────────────────────────────────────────
  845: ['Fly', 'Water'],               // Cramorant
  // ── Pichu / Pikachu / Raichu ────────────────────────────────────
  172: ['Generate'],                   // Pichu
  25:  ['Generate'],                   // Pikachu (NPC Peakychu = Illuminate)
  26:  ['Generate', 'Hype'],           // Raichu
  // ── Zubat line ──────────────────────────────────────────────────
  41:  ['Search'],                     // Zubat
  42:  ['Search'],                     // Golbat
  169: ['Search', 'Chop'],             // Crobat
  // ── Meowth / Persian ────────────────────────────────────────────
  52:  ['Trade'],                      // Meowth
  53:  ['Trade', 'Search'],            // Persian
  // ── Psyduck / Golduck ───────────────────────────────────────────
  54:  ['Search'],                     // Psyduck
  55:  ['Search'],                     // Golduck
  // ── Growlithe / Arcanine ────────────────────────────────────────
  58:  ['Burn', 'Search'],             // Growlithe
  59:  ['Burn', 'Search'],             // Arcanine
  // ── Farfetch'd ──────────────────────────────────────────────────
  83:  ['Chop', 'Build'],              // Farfetch'd
  // ── Grimer / Muk ────────────────────────────────────────────────
  88:  ['Litter'],                     // Grimer
  89:  ['Litter'],                     // Muk
  // ── Gastly line ─────────────────────────────────────────────────
  92:  ['Gather', 'Trade'],            // Gastly
  93:  ['Gather', 'Trade'],            // Haunter
  94:  ['Gather', 'Trade'],            // Gengar
  // ── Voltorb / Electrode ─────────────────────────────────────────
  100: ['Generate', 'Explode'],        // Voltorb
  101: ['Generate', 'Explode'],        // Electrode
  // ── Exeggcute / Exeggutor ───────────────────────────────────────
  102: ['Grow', 'Teleport'],           // Exeggcute
  103: ['Grow', 'Teleport'],           // Exeggutor
  // ── Happiny / Chansey / Blissey ─────────────────────────────────
  440: ['Trade'],                      // Happiny
  113: ['Trade'],                      // Chansey
  242: ['Trade', 'Litter'],            // Blissey
  // ── Elekid / Electabuzz / Electivire ────────────────────────────
  239: ['Generate'],                   // Elekid
  125: ['Generate'],                   // Electabuzz
  466: ['Generate', 'Crush'],          // Electivire
  // ── Lapras ──────────────────────────────────────────────────────
  131: ['Water'],                      // Lapras
  // ── Munchlax / Snorlax ──────────────────────────────────────────
  446: ['Bulldoze'],                   // Munchlax
  143: ['Trade', 'Bulldoze'],          // Snorlax (NPC Mosslax = Eat)
  // ── Spinarak / Ariados ──────────────────────────────────────────
  167: ['Litter'],                     // Spinarak
  168: ['Litter'],                     // Ariados
  // ── Mareep line ─────────────────────────────────────────────────
  179: ['Generate', 'Litter'],         // Mareep
  180: ['Generate', 'Litter'],         // Flaaffy
  181: ['Generate', 'Trade'],          // Ampharos
  // ── Azurill / Marill / Azumarill ────────────────────────────────
  298: ['Water', 'Hype'],              // Azurill
  183: ['Water', 'Hype'],              // Marill
  184: ['Water', 'Build'],             // Azumarill
  // ── Paldean Wooper / Clodsire ───────────────────────────────────
  194: ['Litter'],                     // Paldean Wooper
  980: ['Litter', 'Bulldoze'],         // Clodsire
  // ── Smeargle ────────────────────────────────────────────────────
  235: ['Paint'],                      // Smeargle (NPC Smearguru também = Paint)
  // ── Torchic line ────────────────────────────────────────────────
  255: ['Burn'],                       // Torchic
  256: ['Burn', 'Build'],              // Combusken
  257: ['Burn', 'Build'],              // Blaziken
  // ── Wingull / Pelipper ──────────────────────────────────────────
  278: ['Water', 'Fly'],               // Wingull
  279: ['Water', 'Fly'],               // Pelipper
  // ── Makuhita / Hariyama ─────────────────────────────────────────
  296: ['Build', 'Bulldoze'],          // Makuhita
  297: ['Build', 'Bulldoze'],          // Hariyama
  // ── Absol ───────────────────────────────────────────────────────
  359: ['Chop'],                       // Absol
  // ── Piplup line ─────────────────────────────────────────────────
  393: ['Water'],                      // Piplup
  394: ['Water', 'Trade'],             // Prinplup
  395: ['Water', 'Trade'],             // Empoleon
  // ── Audino ──────────────────────────────────────────────────────
  531: ['Trade'],                      // Audino
  // ── Trubbish / Garbodor ─────────────────────────────────────────
  568: ['Recycle'],                    // Trubbish
  569: ['Recycle', 'Litter'],          // Garbodor
  // ── Zorua / Zoroark ─────────────────────────────────────────────
  570: ['Trade'],                      // Zorua
  571: ['Trade', 'Chop'],              // Zoroark
  // ── Minccino / Cinccino ─────────────────────────────────────────
  572: ['Gather'],                     // Minccino
  573: ['Gather', 'Recycle'],          // Cinccino
  // ── Grubbin line ────────────────────────────────────────────────
  736: ['Chop'],                       // Grubbin
  737: ['Generate', 'Chop'],           // Charjabug
  738: ['Generate', 'Chop'],           // Vikavolt
  // ── Mimikyu ─────────────────────────────────────────────────────
  778: ['Trade'],                      // Mimikyu
  // ── Pawmi line ──────────────────────────────────────────────────
  921: ['Generate'],                   // Pawmi
  922: ['Generate', 'Crush'],          // Pawmo
  923: ['Generate', 'Crush'],          // Pawmot
  // ── Tatsugiri ───────────────────────────────────────────────────
  978: ['Trade'],                      // Tatsugiri
  // ── Ekans / Arbok ───────────────────────────────────────────────
  23:  ['Search'],                     // Ekans
  24:  ['Search'],                     // Arbok
  // ── Cleffa line ─────────────────────────────────────────────────
  173: ['Hype'],                       // Cleffa
  35:  ['Hype'],                       // Clefairy
  36:  ['Hype', 'Trade'],              // Clefable
  // ── Igglybuff line ──────────────────────────────────────────────
  174: ['Hype'],                       // Igglybuff
  39:  ['Hype'],                       // Jigglypuff
  40:  ['Hype'],                       // Wigglytuff
  // ── Diglett / Dugtrio ───────────────────────────────────────────
  50:  ['Hype'],                       // Diglett
  51:  ['Hype', 'Crush'],              // Dugtrio
  // ── Machop line ─────────────────────────────────────────────────
  66:  ['Build', 'Gather'],            // Machop
  67:  ['Build', 'Gather'],            // Machoke
  68:  ['Build', 'Gather'],            // Machamp
  // ── Geodude line ────────────────────────────────────────────────
  74:  ['Crush'],                      // Geodude
  75:  ['Crush'],                      // Graveler
  76:  ['Crush', 'Trade'],             // Golem
  // ── Magby line ──────────────────────────────────────────────────
  240: ['Burn'],                       // Magby
  126: ['Burn'],                       // Magmar
  467: ['Burn'],                       // Magmortar
  // ── Bonsly / Sudowoodo ──────────────────────────────────────────
  438: ['Bulldoze'],                   // Bonsly
  185: ['Trade'],                      // Sudowoodo
  // ── Murkrow / Honchkrow ─────────────────────────────────────────
  198: ['Fly', 'Trade'],               // Murkrow
  430: ['Fly', 'Trade'],               // Honchkrow
  // ── Larvitar line ───────────────────────────────────────────────
  246: ['Crush', 'Bulldoze'],          // Larvitar
  247: ['Crush', 'Bulldoze'],          // Pupitar
  248: ['Crush', 'Bulldoze'],          // Tyranitar
  // ── Lotad line ──────────────────────────────────────────────────
  270: ['Water'],                      // Lotad
  271: ['Water'],                      // Lombre
  272: ['Water', 'Hype'],              // Ludicolo
  // ── Mawile ──────────────────────────────────────────────────────
  303: ['Trade', 'Build'],             // Mawile
  // ── Torkoal ─────────────────────────────────────────────────────
  324: ['Burn'],                       // Torkoal
  // ── Kricketot / Kricketune ──────────────────────────────────────
  401: ['Hype'],                       // Kricketot
  402: ['Hype'],                       // Kricketune
  // ── Chatot ──────────────────────────────────────────────────────
  441: ['Fly', 'Hype'],                // Chatot
  // ── Riolu / Lucario ─────────────────────────────────────────────
  447: ['Build'],                      // Riolu
  448: ['Build'],                      // Lucario
  // ── Larvesta / Volcarona ────────────────────────────────────────
  636: ['Burn'],                       // Larvesta
  637: ['Burn', 'Fly'],                // Volcarona
  // ── Rowlet line ─────────────────────────────────────────────────
  722: ['Grow'],                       // Rowlet
  723: ['Grow', 'Chop'],               // Dartrix
  724: ['Grow', 'Chop'],               // Decidueye
  // ── Scorbunny line ──────────────────────────────────────────────
  813: ['Burn'],                       // Scorbunny
  814: ['Burn'],                       // Raboot
  815: ['Burn', 'Hype'],               // Cinderace
  // ── Skwovet / Greedent ──────────────────────────────────────────
  819: ['Gather'],                     // Skwovet
  820: [],                             // Greedent (NPC Chef Dente = Party)
  // ── Rolycoly line ───────────────────────────────────────────────
  838: ['Burn', 'Gather'],             // Rolycoly
  839: ['Burn', 'Gather'],             // Carkol
  840: ['Burn'],                       // Coalossal
  // ── Toxel / Toxtricity ──────────────────────────────────────────
  848: ['Generate'],                   // Toxel
  849: ['Generate'],                   // Toxtricity
  // ── Fidough / Dachsbun ──────────────────────────────────────────
  924: ['Search'],                     // Fidough
  925: ['Search', 'Trade'],            // Dachsbun
  // ── Charcadet line ──────────────────────────────────────────────
  855: ['Burn'],                       // Charcadet
  901: ['Burn', 'Trade'],              // Armarouge
  902: ['Burn', 'Trade'],              // Ceruledge
  // ── Glimmet / Glimmora ──────────────────────────────────────────
  969: ['Litter'],                     // Glimmet
  970: ['Litter'],                     // Glimmora
  // ── Gimmighoul / Gholdengo ──────────────────────────────────────
  999: ['Collect'],                    // Gimmighoul
  1000:['Collect'],                    // Gholdengo
  // ── Vulpix / Ninetales ──────────────────────────────────────────
  37:  ['Burn'],                       // Vulpix
  38:  ['Burn'],                       // Ninetales
  // ── Poliwag line ────────────────────────────────────────────────
  60:  ['Water'],                      // Poliwag
  61:  ['Water'],                      // Poliwhirl
  62:  ['Water', 'Build'],             // Poliwrath
  186: ['Water', 'Hype', 'Build'],     // Politoed
  // ── Abra line ───────────────────────────────────────────────────
  63:  ['Teleport'],                   // Abra
  64:  ['Teleport'],                   // Kadabra
  65:  ['Teleport', 'Trade'],          // Alakazam
  // ── Mime Jr. / Mr. Mime ─────────────────────────────────────────
  439: ['Gather', 'Hype'],             // Mime Jr.
  122: ['Gather', 'Build'],            // Mr. Mime
  // ── Porygon line ────────────────────────────────────────────────
  137: ['Recycle'],                    // Porygon
  233: ['Rarify'],                     // Porygon2
  474: ['Recycle'],                    // Porygon-Z
  // ── Dratini line ────────────────────────────────────────────────
  147: ['Water'],                      // Dratini
  148: ['Water'],                      // Dragonair
  149: ['Water', 'Fly'],               // Dragonite
  // ── Cyndaquil line ──────────────────────────────────────────────
  155: ['Burn'],                       // Cyndaquil
  156: ['Burn'],                       // Quilava
  157: ['Burn', 'Trade'],              // Typhlosion
  // ── Misdreavus / Mismagius ──────────────────────────────────────
  200: ['Trade'],                      // Misdreavus
  429: ['Gather', 'Trade'],            // Mismagius
  // ── Girafarig / Farigiraf ───────────────────────────────────────
  203: ['Gather'],                     // Girafarig
  981: ['Gather'],                     // Farigiraf
  // ── Ralts line ──────────────────────────────────────────────────
  280: ['Teleport'],                   // Ralts
  281: ['Teleport', 'Build'],          // Kirlia
  282: ['Teleport', 'Trade'],          // Gardevoir
  475: ['Build', 'Teleport'],          // Gallade
  // ── Plusle / Minun ──────────────────────────────────────────────
  311: ['Generate'],                   // Plusle
  312: ['Generate'],                   // Minun
  // ── Trapinch line ───────────────────────────────────────────────
  328: ['Litter', 'Bulldoze'],         // Trapinch
  329: ['Fly', 'Bulldoze'],            // Vibrava
  330: ['Fly', 'Bulldoze'],            // Flygon
  // ── Swablu / Altaria ────────────────────────────────────────────
  333: ['Fly', 'Litter'],              // Swablu
  334: ['Fly', 'Litter'],              // Altaria
  // ── Duskull line ────────────────────────────────────────────────
  355: ['Gather'],                     // Duskull
  356: ['Gather'],                     // Dusclops
  477: ['Gather', 'Trade'],            // Dusknoir
  // ── Beldum line ─────────────────────────────────────────────────
  374: ['Generate'],                   // Beldum
  375: ['Recycle'],                    // Metang
  376: ['Crush'],                      // Metagross
  // ── Snivy line ──────────────────────────────────────────────────
  495: ['Grow', 'Litter'],             // Snivy
  496: ['Grow', 'Litter'],             // Servine
  497: ['Grow'],                       // Serperior
  // ── Froakie line ────────────────────────────────────────────────
  656: ['Water'],                      // Froakie
  657: ['Water'],                      // Frogadier
  658: ['Water', 'Chop'],              // Greninja
  // ── Dedenne ─────────────────────────────────────────────────────
  702: ['Generate'],                   // Dedenne
  // ── Noibat / Noivern ────────────────────────────────────────────
  714: ['Fly'],                        // Noibat
  715: ['Fly'],                        // Noivern
  // ── Rookidee line ───────────────────────────────────────────────
  821: ['Fly'],                        // Rookidee
  822: ['Fly', 'Chop'],                // Corvisquire
  823: ['Fly', 'Chop'],                // Corviknight
  // ── Dreepy line ─────────────────────────────────────────────────
  885: ['Gather', 'Search'],           // Dreepy
  886: ['Gather', 'Search'],           // Drakloak
  887: ['Gather', 'Trade'],            // Dragapult
  // ── Sprigatito line ─────────────────────────────────────────────
  906: ['Grow'],                       // Sprigatito
  907: ['Grow'],                       // Floragato
  908: ['Grow', 'Hype'],               // Meowscarada
  // ── Wattrel / Kilowattrel ───────────────────────────────────────
  939: ['Fly'],                        // Wattrel
  940: ['Generate', 'Fly'],            // Kilowattrel
  // ── Tinkatink line ──────────────────────────────────────────────
  957: ['Build'],                      // Tinkatink
  958: ['Build'],                      // Tinkatuff
  959: ['Build'],                      // Tinkaton (NPC Tinkmaster = Engineer)
  // ── Fossil Pokémon ──────────────────────────────────────────────
  142: ['Fly', 'Chop'],                // Aerodactyl
  408: ['Crush'],                      // Cranidos
  409: ['Crush'],                      // Rampardos
  410: ['Build'],                      // Shieldon
  411: ['Build'],                      // Bastiodon
  696: ['Crush'],                      // Tyrunt
  697: ['Crush', 'Litter'],            // Tyrantrum
  698: ['Crush'],                      // Amaura
  699: ['Crush'],                      // Aurorus
  // ── Eevee / Eeveelutions ────────────────────────────────────────
  133: ['Trade'],                      // Eevee
  134: ['Water'],                      // Vaporeon
  135: ['Generate'],                   // Jolteon
  136: ['Burn'],                       // Flareon
  196: ['Teleport', 'Gather'],         // Espeon
  197: ['Search'],                     // Umbreon
  470: ['Grow'],                       // Leafeon
  471: ['Water', 'Trade'],             // Glaceon
  700: ['Hype'],                       // Sylveon
  // ── Legendários ─────────────────────────────────────────────────
  382: ['Water'],                      // Kyogre
  243: ['Generate'],                   // Raikou
  244: ['Burn'],                       // Entei
  245: ['Water'],                      // Suicune
  721: ['Burn'],                       // Volcanion
  144: ['Fly'],                        // Articuno
  145: ['Generate', 'Fly'],            // Zapdos
  146: ['Burn', 'Fly'],                // Moltres
  249: ['Fly'],                        // Lugia
  250: ['Fly'],                        // Ho-Oh
  150: ['Teleport'],                   // Mewtwo
  151: ['Teleport'],                   // Mew
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