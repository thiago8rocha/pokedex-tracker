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
    "let_s_go_pikachu___eevee": [
      PokedexSection(label: 'Let\'s Go Kanto', apiName: 'letsgo-kanto', isDlc: false),
    ],
    "sword___shield": [
      PokedexSection(label: 'Galar', apiName: 'galar', isDlc: false),
      PokedexSection(label: 'Isle of Armor', apiName: 'isle-of-armor', isDlc: true),
      PokedexSection(label: 'Crown Tundra', apiName: 'crown-tundra', isDlc: true),
    ],
    "brilliant_diamond___shining_pearl": [
      PokedexSection(label: 'Sinnoh', apiName: 'original-sinnoh', isDlc: false),
    ],
    "legends_arceus": [
      PokedexSection(label: 'Hisui', apiName: 'hisui', isDlc: false),
    ],
    "scarlet___violet": [
      PokedexSection(label: 'Paldea', apiName: 'paldea', isDlc: false),
      PokedexSection(label: 'Teal Mask', apiName: 'kitakami', isDlc: true),
      PokedexSection(label: 'Indigo Disk', apiName: 'blueberry', isDlc: true),
    ],
    "legends_z-a": [
      PokedexSection(label: 'Lumiose', apiName: 'lumiose', isDlc: false),
    ],
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