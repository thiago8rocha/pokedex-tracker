import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:dexcurator/core/app_constants.dart';

class PokedexSection {
  final String label;
  final String apiName;
  final bool isDlc;
  const PokedexSection(
      {required this.label,
      required this.apiName,
      required this.isDlc});
}

// Mapeamento das gerações para separação na Nacional
class GenInfo {
  final String label;
  final String region;
  final int startId;
  final int endId;
  const GenInfo(
      {required this.label,
      required this.region,
      required this.startId,
      required this.endId});
}

const List<GenInfo> nationalGens = [
  GenInfo(label: 'Gen I',   region: 'Kanto',        startId: 1,   endId: 151),
  GenInfo(label: 'Gen II',  region: 'Johto',         startId: 152, endId: 251),
  GenInfo(label: 'Gen III', region: 'Hoenn',         startId: 252, endId: 386),
  GenInfo(label: 'Gen IV',  region: 'Sinnoh',        startId: 387, endId: 493),
  GenInfo(label: 'Gen V',   region: 'Unova',         startId: 494, endId: 649),
  GenInfo(label: 'Gen VI',  region: 'Kalos',         startId: 650, endId: 721),
  GenInfo(label: 'Gen VII', region: 'Alola',         startId: 722, endId: 809),
  GenInfo(label: 'Gen VIII',region: 'Galar/Hisui',   startId: 810, endId: 905),
  GenInfo(label: 'Gen IX',  region: 'Paldea',        startId: 906, endId: 1025),
];

class PokeApiService {
  // Usa constante centralizada — não repetir a URL aqui.
  static const String _base = kPokeApiBase;

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
      PokedexSection(
          label: 'Johto', apiName: 'original-johto', isDlc: false),
    ],
    "crystal": [
      PokedexSection(
          label: 'Johto', apiName: 'original-johto', isDlc: false),
    ],
    // ── Gen III ──────────────────────────────────────────────────
    "ruby___sapphire": [
      PokedexSection(label: 'Hoenn', apiName: 'hoenn', isDlc: false),
    ],
    "firered___leafgreen_(gba)": [
      PokedexSection(
          label: 'Kanto', apiName: 'updated-kanto', isDlc: false),
    ],
    "emerald": [
      PokedexSection(
          label: 'Hoenn', apiName: 'updated-hoenn', isDlc: false),
    ],
    // ── Gen IV ───────────────────────────────────────────────────
    "diamond___pearl": [
      PokedexSection(
          label: 'Sinnoh',
          apiName: 'original-sinnoh',
          isDlc: false),
    ],
    "platinum": [
      PokedexSection(
          label: 'Sinnoh',
          apiName: 'extended-sinnoh',
          isDlc: false),
    ],
    "heartgold___soulsilver": [
      PokedexSection(
          label: 'Johto', apiName: 'updated-johto', isDlc: false),
    ],
    // ── Gen V ────────────────────────────────────────────────────
    "black___white": [
      PokedexSection(
          label: 'Unova',
          apiName: 'original-unova',
          isDlc: false),
    ],
    "black_2___white_2": [
      PokedexSection(
          label: 'Unova',
          apiName: 'updated-unova',
          isDlc: false),
    ],
    // ── Gen VI ───────────────────────────────────────────────────
    "x___y": [
      PokedexSection(
          label: 'Kalos Central',
          apiName: 'kalos-central',
          isDlc: false),
      PokedexSection(
          label: 'Kalos Coastal',
          apiName: 'kalos-coastal',
          isDlc: false),
      PokedexSection(
          label: 'Kalos Mountain',
          apiName: 'kalos-mountain',
          isDlc: false),
    ],
    "omega_ruby___alpha_sapphire": [
      PokedexSection(
          label: 'Hoenn',
          apiName: 'updated-hoenn-oras',
          isDlc: false),
    ],
    // ── Gen VII ──────────────────────────────────────────────────
    "sun___moon": [
      PokedexSection(
          label: 'Alola',
          apiName: 'original-alola',
          isDlc: false),
    ],
    "ultra_sun___ultra_moon": [
      PokedexSection(
          label: 'Alola',
          apiName: 'updated-alola',
          isDlc: false),
    ],
    // ── Gen VIII (Switch) ─────────────────────────────────────────
    "let_s_go_pikachu___eevee": [
      PokedexSection(
          label: "Let's Go Kanto",
          apiName: 'letsgo-kanto',
          isDlc: false),
    ],
    "sword___shield": [
      PokedexSection(
          label: 'Galar', apiName: 'galar', isDlc: false),
      PokedexSection(
          label: 'Isle of Armor',
          apiName: 'isle-of-armor',
          isDlc: true),
      PokedexSection(
          label: 'Crown Tundra',
          apiName: 'crown-tundra',
          isDlc: true),
    ],
    "brilliant_diamond___shining_pearl": [
      PokedexSection(
          label: 'Sinnoh',
          apiName: 'original-sinnoh-bdsp',
          isDlc: false),
    ],
    "legends_arceus": [
      PokedexSection(
          label: 'Hisui', apiName: 'hisui', isDlc: false),
    ],
    // ── Gen IX ────────────────────────────────────────────────────
    "scarlet___violet": [
      PokedexSection(
          label: 'Paldea', apiName: 'paldea', isDlc: false),
      PokedexSection(
          label: 'Teal Mask',
          apiName: 'kitakami',
          isDlc: true),
      PokedexSection(
          label: 'Indigo Disk',
          apiName: 'blueberry',
          isDlc: true),
    ],
    "legends_z-a": [
      PokedexSection(
          label: 'Lumiose', apiName: 'lumiose', isDlc: false),
      PokedexSection(
          label: 'Mega Dimension',
          apiName: 'mega-dimension',
          isDlc: true),
    ],
    // ── Especiais ─────────────────────────────────────────────────
    "firered___leafgreen": [
      PokedexSection(
          label: 'Kanto', apiName: 'updated-kanto', isDlc: false),
    ],
    "nacional": [
      PokedexSection(
          label: 'Nacional', apiName: 'national', isDlc: false),
    ],
  };

  // ─── BUSCA IDs + ENTRY NUMBER ─────────────────────────────────
  Future<Map<String, List<_PokedexEntry>>> fetchEntriesBySection(
      String pokedexId) async {
    final sections = pokedexSections[pokedexId];
    if (sections == null) return {};

    final result = <String, List<_PokedexEntry>>{};

    for (final section in sections) {
      try {
        final url =
            Uri.parse('$_base/pokedex/${section.apiName}');
        final res = await http.get(url);
        if (res.statusCode != 200) continue;

        final data =
            json.decode(res.body) as Map<String, dynamic>;
        final rawEntries =
            data['pokemon_entries'] as List<dynamic>;

        final entries = <_PokedexEntry>[];
        for (final e in rawEntries) {
          final entryNumber = e['entry_number'] as int;
          final speciesUrl =
              e['pokemon_species']['url'] as String;
          final parts = speciesUrl.split('/');
          final speciesId =
              int.tryParse(parts[parts.length - 2]);
          if (speciesId != null) {
            entries.add(_PokedexEntry(
                entryNumber: entryNumber,
                speciesId: speciesId));
          }
        }
        entries.sort(
            (a, b) => a.entryNumber.compareTo(b.entryNumber));
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

  Future<String> fetchFlavorText(
      int speciesId, String pokedexId) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/pokemon-species/$speciesId'));
      if (res.statusCode != 200) return '';
      final data =
          json.decode(res.body) as Map<String, dynamic>;
      final entries =
          data['flavor_text_entries'] as List<dynamic>? ?? [];
      return _extractFlavorForGame(entries, pokedexId);
    } catch (_) {
      return '';
    }
  }

  String _extractFlavorForGame(
      List<dynamic> entries, String pokedexId) {
    const vgMap = {
      'red___blue':                        ['red-blue'],
      'gold___silver':                     ['gold-silver'],
      'ruby___sapphire':                   ['ruby-sapphire'],
      'firered___leafgreen_(gba)':         ['firered-leafgreen'],
      'emerald':                           ['emerald'],
      'diamond___pearl':                   ['diamond-pearl'],
      'platinum':                          ['platinum'],
      'heartgold___soulsilver':            ['heartgold-soulsilver'],
      'black___white':                     ['black-white'],
      'black_2___white_2':                 ['black-2-white-2'],
      'x___y':                             ['x-y'],
      'omega_ruby___alpha_sapphire':       ['omega-ruby-alpha-sapphire'],
      'sun___moon':                        ['sun-moon'],
      'ultra_sun___ultra_moon':            ['ultra-sun-ultra-moon'],
      'lets_go_pikachu___eevee':           ['lets-go-pikachu-lets-go-eevee'],
      'sword___shield':                    ['sword-shield'],
      'brilliant_diamond___shining_pearl': ['brilliant-diamond-and-shining-pearl'],
      'legends_arceus':                    ['legends-arceus'],
      'scarlet___violet':                  ['scarlet-violet'],
      'legends_z-a':                       ['legends-za'],
    };
    String clean(String s) =>
        s.replaceAll('\n', ' ').replaceAll('\f', ' ').trim();
    bool isPt(String l) => l == 'pt-BR' || l == 'pt';
    final groups = vgMap[pokedexId];
    if (groups != null) {
      const versionToGroup = {
        'sword': 'sword-shield',
        'shield': 'sword-shield',
        'scarlet': 'scarlet-violet',
        'violet': 'scarlet-violet',
        'lets-go-pikachu': 'lets-go-pikachu-lets-go-eevee',
        'lets-go-eevee': 'lets-go-pikachu-lets-go-eevee',
        'brilliant-diamond':
            'brilliant-diamond-and-shining-pearl',
        'shining-pearl':
            'brilliant-diamond-and-shining-pearl',
        'legends-arceus': 'legends-arceus',
        'legends-za': 'legends-za',
        'firered': 'firered-leafgreen',
        'leafgreen': 'firered-leafgreen',
        'ultra-sun': 'ultra-sun-ultra-moon',
        'ultra-moon': 'ultra-sun-ultra-moon',
        'sun': 'sun-moon',
        'moon': 'sun-moon',
        'omega-ruby': 'omega-ruby-alpha-sapphire',
        'alpha-sapphire': 'omega-ruby-alpha-sapphire',
        'x': 'x-y',
        'y': 'x-y',
        'black-2': 'black-2-white-2',
        'white-2': 'black-2-white-2',
        'black': 'black-white',
        'white': 'black-white',
        'heartgold': 'heartgold-soulsilver',
        'soulsilver': 'heartgold-soulsilver',
        'platinum': 'platinum',
        'diamond': 'diamond-pearl',
        'pearl': 'diamond-pearl',
        'emerald': 'emerald',
        'ruby': 'ruby-sapphire',
        'sapphire': 'ruby-sapphire',
        'crystal': 'crystal',
        'gold': 'gold-silver',
        'silver': 'gold-silver',
        'red': 'red-blue',
        'blue': 'red-blue',
      };
      for (final g in groups) {
        String ptText = '', enText = '';
        for (final e in entries) {
          final vg = versionToGroup[
                  e['version']?['name'] as String? ?? ''] ??
              '';
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
      final res = await http
          .get(Uri.parse('$_base/pokemon/$speciesId'));
      if (res.statusCode != 200) return null;
      return json.decode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPokemonBatch(
    List<int> ids, {
    int batchSize = 10,
  }) async {
    final results = <Map<String, dynamic>>[];
    for (int i = 0; i < ids.length; i += batchSize) {
      final batch = ids.skip(i).take(batchSize).toList();
      final batchResults =
          await Future.wait(batch.map(fetchPokemon));
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
      return pokemon['sprites']['other']['official-artwork']
          ['front_default'] as String?;
    } catch (_) {
      return pokemon['sprites']['front_default'] as String?;
    }
  }

  Map<String, String?> extractAllSprites(
      Map<String, dynamic> pokemon) {
    String? s(List<String> path) {
      try {
        dynamic node = pokemon['sprites'];
        for (final key in path) node = node[key];
        return node as String?;
      } catch (_) {
        return null;
      }
    }

    return {
      'default':
          s(['other', 'official-artwork', 'front_default']),
      'shiny': s(['other', 'official-artwork', 'front_shiny']),
      'pixel': s(['front_default']),
      'pixelShiny': s(['front_shiny']),
      'pixelFemale': s(['front_female']),
      'home': s(['other', 'home', 'front_default']),
      'homeShiny': s(['other', 'home', 'front_shiny']),
      'homeFemale': s(['other', 'home', 'front_female']),
      'homeShinyFemale': null,
    };
  }

  Map<String, int> extractStats(Map<String, dynamic> pokemon) {
    final result = <String, int>{};
    for (final stat in pokemon['stats'] as List<dynamic>) {
      result[stat['stat']['name'] as String] =
          stat['base_stat'] as int;
    }
    return result;
  }
}

class _PokedexEntry {
  final int entryNumber;
  final int speciesId;
  const _PokedexEntry(
      {required this.entryNumber, required this.speciesId});
}

// ─── LISTA POKOPIA ────────────────────────────────────────────────
// 300 Pokémon no jogo (IDs da PokeAPI / nacional)
// Fontes: Serebii (#001-#300), Bulbapedia, Nintendo Life,
//         NintendoReporters, Dexerto (março 2026)
const List<int> pokopiaSpeciesIds = [
  1, 2, 3, 4, 5, 6, 7, 8, 9, 16,
  17, 18, 43, 44, 45, 182, 46, 47, 48, 49,
  69, 70, 71, 79, 80, 199, 81, 82, 462, 95,
  208, 104, 105, 236, 106, 107, 237, 109, 110, 114,
  465, 123, 212, 127, 129, 130, 132, 163, 164, 214,
  313, 314, 316, 317, 331, 332, 415, 416, 422, 423,
  425, 426, 529, 530, 532, 533, 534, 607, 608, 609,
  610, 611, 612, 704, 705, 706, 845, 172, 25, 26,
  41, 42, 169, 52, 53, 54, 55, 58, 59, 83,
  88, 89, 92, 93, 94, 100, 101, 102, 103, 440,
  113, 242, 239, 125, 466, 131, 446, 143, 167, 168,
  179, 180, 181, 298, 183, 184, 194, 980, 235, 255,
  256, 257, 278, 279, 296, 297, 359, 393, 394, 395,
  531, 568, 569, 570, 571, 572, 573, 736, 737, 738,
  778, 921, 922, 923, 978, 23, 24, 173, 35, 36,
  174, 39, 40, 50, 51, 66, 67, 68, 74, 75,
  76, 240, 126, 467, 438, 185, 198, 430, 246, 247,
  248, 270, 271, 272, 303, 324, 401, 402, 441, 447,
  448, 479, 636, 637, 722, 723, 724, 813, 814, 815,
  819, 820, 821, 822, 823, 838, 839, 840, 848, 849,
  133, 134, 135, 136, 196, 197, 471, 470, 700, 280,
  281, 282, 475, 311, 312, 333, 334, 147, 148, 149,
  200, 429, 203, 981, 355, 356, 477, 885, 886, 887,
  906, 907, 908, 924, 925, 855, 901, 902, 939, 940,
  495, 496, 497, 656, 657, 658, 328, 329, 330, 374,
  375, 376, 408, 409, 410, 411, 439, 122, 696, 697,
  698, 699, 714, 715, 957, 958, 959, 60, 61, 62,
  186, 63, 64, 65, 37, 38, 142, 969, 970, 999,
  1000, 137, 233, 474, 155, 156, 157, 702, 382, 721,
  243, 244, 245, 249, 250, 144, 145, 146, 150, 151,
];

const Map<int, List<String>> pokopiaSpecialtyMap = {
  1: ['Grow'], 2: ['Grow'], 3: ['Grow', 'Litter'],
  4: ['Burn'], 5: ['Burn'], 6: ['Burn', 'Fly'],
  7: ['Water'], 8: ['Water'], 9: ['Water', 'Trade'],
  16: ['Fly', 'Search'], 17: ['Fly', 'Search'], 18: ['Fly', 'Search'],
  43: ['Grow'], 44: ['Grow'], 45: ['Grow', 'Litter'], 182: ['Grow', 'Hype'],
  46: ['Search'], 47: ['Search'],
  48: ['Search'], 49: ['Search'],
  69: ['Grow', 'Litter'], 70: ['Grow', 'Litter'], 71: ['Grow', 'Chop'],
  79: ['Water', 'Yawn'], 80: ['Water', 'Trade'], 199: ['Water', 'Teleport'],
  81: ['Generate'], 82: ['Generate'], 462: ['Generate', 'Recycle'],
  95: ['Crush', 'Bulldoze'], 208: ['Crush', 'Bulldoze'],
  104: ['Build'], 105: ['Build'],
  236: ['Trade'], 106: ['Trade'], 107: ['Trade'], 237: ['Trade'],
  109: ['Recycle'], 110: ['Recycle'],
  114: ['Grow', 'Litter'], 465: ['Grow', 'Litter'],
  123: ['Chop'], 212: ['Chop'], 127: ['Chop', 'Build'],
  129: [], 130: ['Water'],
  132: ['Transform'],
  163: ['Trade', 'Fly'], 164: ['Trade', 'Fly'],
  214: ['Chop', 'Build'],
  313: ['Hype'], 314: ['Hype'],
  316: ['Storage'], 317: ['Storage'],
  331: ['Grow'], 332: ['Grow', 'Litter'],
  415: ['Litter'], 416: ['Gather Honey', 'Search'],
  422: ['Water'], 423: ['Water', 'Trade'],
  425: ['Dream Island'], 426: ['Fly', 'Gather'],
  529: ['Search'], 530: ['Search', 'Chop'],
  532: ['Build'], 533: ['Build'], 534: ['Build', 'Crush'],
  607: ['Burn'], 608: ['Burn'], 609: ['Burn'],
  610: ['Chop'], 611: ['Chop'], 612: ['Chop', 'Litter'],
  704: ['Water'], 705: ['Water'], 706: ['Water'],
  845: ['Fly', 'Water'],
  172: ['Generate'], 25: ['Generate'], 26: ['Generate', 'Hype'],
  41: ['Search'], 42: ['Search'], 169: ['Search', 'Chop'],
  52: ['Trade'], 53: ['Trade', 'Search'],
  54: ['Search'], 55: ['Search'],
  58: ['Burn', 'Search'], 59: ['Burn', 'Search'],
  83: ['Chop', 'Build'],
  88: ['Litter'], 89: ['Litter'],
  92: ['Gather', 'Trade'], 93: ['Gather', 'Trade'], 94: ['Gather', 'Trade'],
  100: ['Generate', 'Explode'], 101: ['Generate', 'Explode'],
  102: ['Grow', 'Teleport'], 103: ['Grow', 'Teleport'],
  440: ['Trade'], 113: ['Trade'], 242: ['Trade', 'Litter'],
  239: ['Generate'], 125: ['Generate'], 466: ['Generate', 'Crush'],
  131: ['Water'],
  446: ['Bulldoze'], 143: ['Trade', 'Bulldoze'],
  167: ['Litter'], 168: ['Litter'],
  179: ['Generate', 'Litter'], 180: ['Generate', 'Litter'], 181: ['Generate', 'Trade'],
  298: ['Water', 'Hype'], 183: ['Water', 'Hype'], 184: ['Water', 'Build'],
  194: ['Litter'], 980: ['Litter', 'Bulldoze'],
  235: ['Paint'],
  255: ['Burn'], 256: ['Burn', 'Build'], 257: ['Burn', 'Build'],
  278: ['Water', 'Fly'], 279: ['Water', 'Fly'],
  296: ['Build', 'Bulldoze'], 297: ['Build', 'Bulldoze'],
  359: ['Chop'],
  393: ['Water'], 394: ['Water', 'Trade'], 395: ['Water', 'Trade'],
  531: ['Trade'],
  568: ['Recycle'], 569: ['Recycle', 'Litter'],
  570: ['Trade'], 571: ['Trade', 'Chop'],
  572: ['Gather'], 573: ['Gather', 'Recycle'],
  736: ['Chop'], 737: ['Generate', 'Chop'], 738: ['Generate', 'Chop'],
  778: ['Trade'],
  921: ['Generate'], 922: ['Generate', 'Crush'], 923: ['Generate', 'Crush'],
  978: ['Trade'],
  23: ['Search'], 24: ['Search'],
  173: ['Hype'], 35: ['Hype'], 36: ['Hype', 'Trade'],
  174: ['Hype'], 39: ['Hype'], 40: ['Hype'],
  50: ['Hype'], 51: ['Hype', 'Crush'],
  66: ['Build', 'Gather'], 67: ['Build', 'Gather'], 68: ['Build', 'Gather'],
  74: ['Crush'], 75: ['Crush'], 76: ['Crush', 'Trade'],
  240: ['Burn'], 126: ['Burn'], 467: ['Burn'],
  438: ['Bulldoze'], 185: ['Trade'],
  198: ['Fly', 'Trade'], 430: ['Fly', 'Trade'],
  246: ['Crush', 'Bulldoze'], 247: ['Crush', 'Bulldoze'], 248: ['Crush', 'Bulldoze'],
  270: ['Water'], 271: ['Water'], 272: ['Water', 'Hype'],
  303: ['Trade', 'Build'],
  324: ['Burn'],
  401: ['Hype'], 402: ['Hype'],
  441: ['Fly', 'Hype'],
  447: ['Build'], 448: ['Build'],
  636: ['Burn'], 637: ['Burn', 'Fly'],
  722: ['Grow'], 723: ['Grow', 'Chop'], 724: ['Grow', 'Chop'],
  813: ['Burn'], 814: ['Burn'], 815: ['Burn', 'Hype'],
  819: ['Gather'], 820: [],
  838: ['Burn', 'Gather'], 839: ['Burn', 'Gather'], 840: ['Burn'],
  848: ['Generate'], 849: ['Generate'],
  924: ['Search'], 925: ['Search', 'Trade'],
  855: ['Burn'], 901: ['Burn', 'Trade'], 902: ['Burn', 'Trade'],
  969: ['Litter'], 970: ['Litter'],
  999: ['Collect'], 1000: ['Collect'],
  37: ['Burn'], 38: ['Burn'],
  60: ['Water'], 61: ['Water'], 62: ['Water', 'Build'], 186: ['Water', 'Hype', 'Build'],
  63: ['Teleport'], 64: ['Teleport'], 65: ['Teleport', 'Trade'],
  439: ['Gather', 'Hype'], 122: ['Gather', 'Build'],
  137: ['Recycle'], 233: ['Rarify'], 474: ['Recycle'],
  147: ['Water'], 148: ['Water'], 149: ['Water', 'Fly'],
  155: ['Burn'], 156: ['Burn'], 157: ['Burn', 'Trade'],
  200: ['Trade'], 429: ['Gather', 'Trade'],
  203: ['Gather'], 981: ['Gather'],
  280: ['Teleport'], 281: ['Teleport', 'Build'],
  282: ['Teleport', 'Trade'], 475: ['Build', 'Teleport'],
  311: ['Generate'], 312: ['Generate'],
  328: ['Litter', 'Bulldoze'], 329: ['Fly', 'Bulldoze'], 330: ['Fly', 'Bulldoze'],
  333: ['Fly', 'Litter'], 334: ['Fly', 'Litter'],
  355: ['Gather'], 356: ['Gather'], 477: ['Gather', 'Trade'],
  374: ['Generate'], 375: ['Recycle'], 376: ['Crush'],
  495: ['Grow', 'Litter'], 496: ['Grow', 'Litter'], 497: ['Grow'],
  656: ['Water'], 657: ['Water'], 658: ['Water', 'Chop'],
  702: ['Generate'],
  714: ['Fly'], 715: ['Fly'],
  821: ['Fly'], 822: ['Fly', 'Chop'], 823: ['Fly', 'Chop'],
  885: ['Gather', 'Search'], 886: ['Gather', 'Search'], 887: ['Gather', 'Trade'],
  906: ['Grow'], 907: ['Grow'], 908: ['Grow', 'Hype'],
  939: ['Fly'], 940: ['Generate', 'Fly'],
  957: ['Build'], 958: ['Build'], 959: ['Build'],
  142: ['Fly', 'Chop'],
  408: ['Crush'], 409: ['Crush'], 410: ['Build'], 411: ['Build'],
  696: ['Crush'], 697: ['Crush', 'Litter'], 698: ['Crush'], 699: ['Crush'],
  133: ['Trade'], 134: ['Water'], 135: ['Generate'], 136: ['Burn'],
  196: ['Teleport', 'Gather'], 197: ['Search'],
  470: ['Grow'], 471: ['Water', 'Trade'], 700: ['Hype'],
  382: ['Water'],
  243: ['Generate'], 244: ['Burn'], 245: ['Water'],
  721: ['Burn'],
  144: ['Fly'], 145: ['Generate', 'Fly'], 146: ['Burn', 'Fly'],
  249: ['Fly'], 250: ['Fly'],
  150: ['Teleport'], 151: ['Teleport'],
};

class PokopiaEvent {
  final int eventDexNumber;
  final int speciesId;
  final String name;
  final String eventName;
  final String startDate;
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
  PokopiaEvent(
    eventDexNumber: 1, speciesId: 187, name: 'Hoppip',
    eventName: 'More Spores for Hoppip',
    startDate: '03/10', endDate: '03/25', specialties: ['Grow'],
  ),
  PokopiaEvent(
    eventDexNumber: 2, speciesId: 188, name: 'Skiploom',
    eventName: 'More Spores for Hoppip',
    startDate: '03/10', endDate: '03/25', specialties: ['Grow'],
  ),
  PokopiaEvent(
    eventDexNumber: 3, speciesId: 189, name: 'Jumpluff',
    eventName: 'More Spores for Hoppip',
    startDate: '03/10', endDate: '03/25', specialties: ['Grow', 'Litter'],
  ),
  PokopiaEvent(
    eventDexNumber: 4, speciesId: 302, name: 'Sableye',
    eventName: 'Sableye Event',
    startDate: '04/29', endDate: '05/13', specialties: [],
  ),
];

final List<int> pokopiaEventSpeciesIds =
    pokopiaEventPokemon.map((e) => e.speciesId).toList();
