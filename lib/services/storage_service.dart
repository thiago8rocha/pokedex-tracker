import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _caughtPrefix = 'caught_';
  static const String _sectionPrefix = 'section_';

  // ─── CAPTURA ────────────────────────────────────────────────────

  Future<bool> isCaught(String pokedexId, int speciesId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_caughtPrefix}${pokedexId}_$speciesId') ?? false;
  }

  Future<void> setCaught(String pokedexId, int speciesId, bool caught) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_caughtPrefix}${pokedexId}_$speciesId', caught);
  }

  Future<Set<int>> getCaught(String pokedexId) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '${_caughtPrefix}${pokedexId}_';
    return prefs.getKeys()
        .where((k) => k.startsWith(prefix) && prefs.getBool(k) == true)
        .map((k) => int.tryParse(k.substring(prefix.length)))
        .whereType<int>()
        .toSet();
  }

  Future<void> saveCaught(String pokedexId, Set<int> caught) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '${_caughtPrefix}${pokedexId}_';
    final existing = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final k in existing) await prefs.remove(k);
    for (final id in caught) await prefs.setBool('$prefix$id', true);
  }

  Future<int> getCaughtCount(String pokedexId) async {
    final caught = await getCaught(pokedexId);
    return caught.length;
  }

  /// Conta capturados dentro de uma seção/DLC específica.
  /// Cruza os speciesIds da seção com os capturados da Pokedex.
  Future<int> getCaughtCountForSection(
      String pokedexId, String sectionApiName) async {
    final entries = await getSectionEntries(pokedexId, sectionApiName);
    if (entries == null || entries.isEmpty) return 0;
    final caughtSet = await getCaught(pokedexId);
    final sectionIds = entries.map((e) => e['speciesId']!).toSet();
    return caughtSet.intersection(sectionIds).length;
  }

  Future<Map<int, bool>> getCaughtMap(String pokedexId, List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final map = <int, bool>{};
    for (final id in ids) {
      map[id] = prefs.getBool('${_caughtPrefix}${pokedexId}_$id') ?? false;
    }
    return map;
  }

  // ─── CACHE DE ENTRIES (entryNumber + speciesId) ──────────────────
  // Salva como CSV: "entryNum:speciesId,entryNum:speciesId,..."

  Future<void> saveSectionEntries(
      String pokedexId, String sectionApiName, List<Map<String, int>> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = entries
        .map((e) => '${e['entryNumber']}:${e['speciesId']}')
        .join(',');
    await prefs.setString('$_sectionPrefix${pokedexId}_$sectionApiName', encoded);
  }

  Future<List<Map<String, int>>?> getSectionEntries(
      String pokedexId, String sectionApiName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_sectionPrefix${pokedexId}_$sectionApiName');
    if (raw == null || raw.isEmpty) return null;
    return raw.split(',').map((s) {
      final parts = s.split(':');
      return {
        'entryNumber': int.parse(parts[0]),
        'speciesId': int.parse(parts[1]),
      };
    }).toList();
  }

  Future<bool> hasSectionEntries(String pokedexId, String sectionApiName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_sectionPrefix${pokedexId}_$sectionApiName');
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ─── POKEDEX ATIVAS ─────────────────────────────────────────────
  // Salva quais Pokedex estão ativas (visíveis na home).
  // Por padrão, todas são consideradas ativas se a chave não existir.

  static const String _activePokedexKey = 'active_pokedex_ids';

  /// Retorna o Set de pokedexIds ativos.
  /// Se nunca foi configurado, retorna null (= todas ativas por padrão).
  Future<Set<String>?> getActivePokedexIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_activePokedexKey);
    if (raw == null) return null; // null = todas ativas (padrão)
    return raw.toSet();
  }

  Future<void> setActivePokedexIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_activePokedexKey, ids.toList());
  }

  Future<bool> isPokedexActive(String pokedexId) async {
    final active = await getActivePokedexIds();
    if (active == null) return true; // todas ativas por padrão
    return active.contains(pokedexId);
  }
}