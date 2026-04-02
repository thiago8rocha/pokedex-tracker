import 'package:shared_preferences/shared_preferences.dart';

/// Gerencia toda persistência local do DexCurator via SharedPreferences.
///
/// OTIMIZAÇÃO: instância de SharedPreferences é cacheada após o primeiro
/// acesso, eliminando o overhead de `SharedPreferences.getInstance()` a
/// cada chamada (era chamado 36× sem cache).
class StorageService {
  static const String _caughtPrefix    = 'caught_';
  static const String _sectionPrefix   = 'section_';
  static const String _activePokedexKey = 'active_pokedex_ids';
  static const String _themeKey         = 'app_theme_id';
  static const String _defaultSpriteKey = 'default_sprite';
  static const String _bilingualKey     = 'bilingual_mode';
  static const String _disclaimerKey    = 'disclaimer_seen';
  static const String _lastPokedexKey   = 'last_pokedex_id';

  // ── Cache de instância ──────────────────────────────────────────
  // Evita criar uma nova instância de SharedPreferences a cada chamada.
  static SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ─── CAPTURA ────────────────────────────────────────────────────

  Future<bool> isCaught(String pokedexId, int speciesId) async {
    final prefs = await _instance;
    return prefs.getBool('${_caughtPrefix}${pokedexId}_$speciesId') ?? false;
  }

  Future<void> setCaught(
      String pokedexId, int speciesId, bool caught) async {
    final prefs = await _instance;
    await prefs.setBool(
        '${_caughtPrefix}${pokedexId}_$speciesId', caught);

    // Propagação automática para a Pokédex Nacional:
    // - Só ao CAPTURAR (true), nunca ao descapturar
    // - Só de dexes de jogos / GO, não da própria Nacional nem da Pokopia
    // - Não sobrescreve se o Pokémon já estiver marcado na Nacional
    const _excludeFromSync = {'nacional', 'pokopia'};
    if (caught &&
        !_excludeFromSync.any((id) => pokedexId.startsWith(id))) {
      final nacKey = '${_caughtPrefix}nacional_$speciesId';
      final alreadyInNac = prefs.getBool(nacKey) ?? false;
      if (!alreadyInNac) {
        await prefs.setBool(nacKey, true);
      }
    }
  }

  Future<Set<int>> getCaught(String pokedexId) async {
    final prefs = await _instance;
    final prefix = '${_caughtPrefix}${pokedexId}_';
    return prefs
        .getKeys()
        .where((k) => k.startsWith(prefix) && prefs.getBool(k) == true)
        .map((k) => int.tryParse(k.substring(prefix.length)))
        .whereType<int>()
        .toSet();
  }

  Future<void> saveCaught(String pokedexId, Set<int> caught) async {
    final prefs = await _instance;
    final prefix = '${_caughtPrefix}${pokedexId}_';
    final existing =
        prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final k in existing) await prefs.remove(k);
    for (final id in caught) await prefs.setBool('$prefix$id', true);
  }

  Future<int> getCaughtCount(String pokedexId) async {
    final caught = await getCaught(pokedexId);
    return caught.length;
  }

  /// Conta capturados dentro de uma seção/DLC específica.
  Future<int> getCaughtCountForSection(
      String pokedexId, String sectionApiName) async {
    final entries = await getSectionEntries(pokedexId, sectionApiName);
    if (entries == null || entries.isEmpty) return 0;
    final caughtSet = await getCaught(pokedexId);
    final sectionIds =
        entries.map((e) => e['speciesId'] as int).toSet();
    return caughtSet.intersection(sectionIds).length;
  }

  /// Retorna Map<int, bool> keyed por speciesId.
  Future<Map<int, bool>> getCaughtMap(
      String pokedexId, List<int> ids) async {
    final prefs = await _instance;
    final map = <int, bool>{};
    for (final id in ids) {
      map[id] =
          prefs.getBool('${_caughtPrefix}${pokedexId}_$id') ?? false;
    }
    return map;
  }

  /// Versão com suporte a formaKey — usada pela PokedexScreen.
  Future<Map<String, bool>> getCaughtMapByEntries(
      String pokedexId, List<Map<String, dynamic>> entries) async {
    final prefs = await _instance;
    final map = <String, bool>{};
    for (final e in entries) {
      final speciesId = e['speciesId'] as int;
      final formaKey = e['formaKey'] as String?;
      final catchKey =
          formaKey != null ? '${speciesId}_$formaKey' : '$speciesId';
      map[catchKey] =
          prefs.getBool('${_caughtPrefix}${pokedexId}_$speciesId') ??
              false;
    }
    return map;
  }

  // ─── CACHE DE ENTRIES ───────────────────────────────────────────
  // Salva como CSV: "entryNum:speciesId[:formaKey],..."

  Future<void> saveSectionEntries(
      String pokedexId,
      String sectionApiName,
      List<Map<String, dynamic>> entries) async {
    final prefs = await _instance;
    final encoded = entries.map((e) {
      final base = '${e['entryNumber']}:${e['speciesId']}';
      final fk = e['formaKey'] as String?;
      return fk != null ? '$base:$fk' : base;
    }).join(',');
    await prefs.setString(
        '$_sectionPrefix${pokedexId}_$sectionApiName', encoded);
  }

  Future<List<Map<String, dynamic>>?> getSectionEntries(
      String pokedexId, String sectionApiName) async {
    final prefs = await _instance;
    final raw =
        prefs.getString('$_sectionPrefix${pokedexId}_$sectionApiName');
    if (raw == null || raw.isEmpty) return null;
    return raw.split(',').map((s) {
      final parts = s.split(':');
      final entry = <String, dynamic>{
        'entryNumber': int.parse(parts[0]),
        'speciesId': int.parse(parts[1]),
      };
      if (parts.length > 2) entry['formaKey'] = parts.sublist(2).join(':');
      return entry;
    }).toList();
  }

  Future<bool> hasSectionEntries(
      String pokedexId, String sectionApiName) async {
    final prefs = await _instance;
    return prefs
        .containsKey('$_sectionPrefix${pokedexId}_$sectionApiName');
  }

  Future<void> clearAll() async {
    final prefs = await _instance;
    await prefs.clear();
    _prefs = null; // Invalida o cache após limpar tudo
  }

  // ─── POKÉDEX ATIVAS ─────────────────────────────────────────────

  Future<Set<String>?> getActivePokedexIds() async {
    final prefs = await _instance;
    final raw = prefs.getStringList(_activePokedexKey);
    if (raw == null) return null;
    return raw.toSet();
  }

  Future<void> setActivePokedexIds(Set<String> ids) async {
    final prefs = await _instance;
    await prefs.setStringList(_activePokedexKey, ids.toList());
  }

  Future<bool> isPokedexActive(String pokedexId) async {
    final active = await getActivePokedexIds();
    if (active == null) return true;
    return active.contains(pokedexId);
  }

  // ─── TEMA ────────────────────────────────────────────────────────

  Future<String> getThemeId() async {
    final prefs = await _instance;
    return prefs.getString(_themeKey) ?? 'system';
  }

  Future<void> setThemeId(String themeId) async {
    final prefs = await _instance;
    await prefs.setString(_themeKey, themeId);
  }

  // ─── SPRITE PADRÃO ───────────────────────────────────────────────

  Future<String> getDefaultSprite() async {
    final prefs = await _instance;
    return prefs.getString(_defaultSpriteKey) ?? 'artwork';
  }

  Future<void> setDefaultSprite(String sprite) async {
    final prefs = await _instance;
    await prefs.setString(_defaultSpriteKey, sprite);
  }

  // ─── MODO BILÍNGUE ───────────────────────────────────────────────

  Future<String> getBilingualMode() async {
    final prefs = await _instance;
    return prefs.getString(_bilingualKey) ?? 'both';
  }

  Future<void> setBilingualMode(String mode) async {
    final prefs = await _instance;
    await prefs.setString(_bilingualKey, mode);
  }

  // ─── DISCLAIMER ──────────────────────────────────────────────────

  Future<bool> isDisclaimerSeen() async {
    final prefs = await _instance;
    return prefs.getBool(_disclaimerKey) ?? false;
  }

  Future<void> setDisclaimerSeen() async {
    final prefs = await _instance;
    await prefs.setBool(_disclaimerKey, true);
  }

  // ─── ÚLTIMA POKÉDEX ACESSADA ─────────────────────────────────────

  Future<String?> getLastPokedexId() async {
    final prefs = await _instance;
    return prefs.getString(_lastPokedexKey);
  }

  Future<void> setLastPokedexId(String id) async {
    final prefs = await _instance;
    await prefs.setString(_lastPokedexKey, id);
  }
}
