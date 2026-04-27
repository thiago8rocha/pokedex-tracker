import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Acessa os dados locais de pokémon do arquivo assets/data/pokedex_data.json.
/// Carregado uma vez em memória ao iniciar o app — sem nenhuma chamada de rede.
class PokedexDataService {
  static const String _assetPath  = 'assets/data/pokedex_data.json';
  static const String _namesPath  = 'assets/data/pokemon_names.json';
  static const String _formsPath  = 'assets/data/forms_map.json';

  static PokedexDataService? _instance;
  static PokedexDataService get instance =>
      _instance ??= PokedexDataService._();
  PokedexDataService._();

  Map<int, Map<String, dynamic>> _data  = {};
  Map<int, String>               _names = {};
  // forms_map keyed por speciesId — lista de formas alternativas
  Map<int, List<dynamic>>        _forms = {};
  bool _loaded = false;

  /// Carrega o JSON do bundle em memória. Chamar uma vez no main().
  Future<void> load() async {
    if (_loaded) return;
    try {
      final results = await Future.wait([
        rootBundle.loadString(_assetPath),
        rootBundle.loadString(_namesPath),
        rootBundle.loadString(_formsPath),
      ]);

      if (kDebugMode) {
        _data  = _decodePokedex(results[0]);
        _names = _decodeNames(results[1]);
        _forms = _decodeForms(results[2]);
      } else {
        _data  = await compute(_decodePokedex,  results[0]);
        _names = await compute(_decodeNames,    results[1]);
        _forms = await compute(_decodeForms,    results[2]);
      }
      _loaded = true;
    } catch (_) {}
  }

  bool get isLoaded => _loaded;

  /// Dados brutos de um pokémon (null se não carregado ou ID inválido)
  Map<String, dynamic>? get(int id) => _loaded ? _data[id] : null;

  // ─── Getters usados pelas telas de detalhe ─────────────────────

  List<String> getTypes(int id) =>
      (get(id)?['types'] as List<dynamic>?)?.cast<String>() ?? [];

  String getHeight(int id) =>
      get(id)?['height'] as String? ?? '—';

  String getWeight(int id) =>
      get(id)?['weight'] as String? ?? '—';

  String getCategory(int id) =>
      get(id)?['category'] as String? ?? '—';

  String getFlavorText(int id) =>
      get(id)?['flavorText'] as String? ?? '';

  /// Lista de flavor texts por jogo — usado pelas telas de detalhe.
  /// Cada item tem: textPt, textEn, games (List<String>).
  List<Map<String, dynamic>> getFlavorTexts(int id) {
    final raw = get(id)?['flavorTexts'] as List<dynamic>?;
    return raw?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }

  String getGeneration(int id) =>
      get(id)?['generation'] as String? ?? '';

  int getCaptureRate(int id) =>
      get(id)?['captureRate'] as int? ?? 0;

  List<Map<String, dynamic>> getAbilities(int id) {
    final raw = get(id)?['abilities'] as List<dynamic>?;
    return raw?.map((a) => Map<String, dynamic>.from(a as Map)).toList() ?? [];
  }

  List<Map<String, dynamic>> getEvoChain(int id) {
    final raw = get(id)?['evoChain'] as List<dynamic>?;
    return raw?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  }

  /// Lista de jogos onde o pokémon aparece (já ordenada cronologicamente)
  List<String> getGames(int id) {
    final raw = get(id)?['games'] as List<dynamic>?;
    return raw?.cast<String>() ?? [];
  }

  /// Nome em inglês no formato "Bulbasaur" (ex: para exibição na grid)
  String getName(int id) => _names[id] ?? '#$id';

  /// Retorna true se o pokémon tem formas alternativas no forms_map.json.
  /// Síncrono — pode ser chamado no initState sem async.
  bool hasForms(int id) {
    final list = _forms[id];
    return list != null && list.isNotEmpty;
  }

  /// Lista de formas alternativas para um pokémon.
  List<dynamic> getForms(int id) => _forms[id] ?? [];
}

// ─── Funções top-level para compute() ─────────────────────────────
// Precisam estar fora da classe para rodar em isolate separado.

Map<int, Map<String, dynamic>> _decodePokedex(String raw) {
  final decoded = json.decode(raw) as Map<String, dynamic>;
  return decoded.map((k, v) =>
      MapEntry(int.parse(k), Map<String, dynamic>.from(v as Map)));
}

Map<int, String> _decodeNames(String raw) {
  final decoded = json.decode(raw) as Map<String, dynamic>;
  return decoded.map((k, v) => MapEntry(int.parse(k), v as String));
}

Map<int, List<dynamic>> _decodeForms(String raw) {
  final decoded = json.decode(raw) as Map<String, dynamic>;
  return decoded.map((k, v) =>
      MapEntry(int.parse(k), v as List<dynamic>));
}