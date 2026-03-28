import 'dart:convert';
import 'package:flutter/services.dart';

/// Acessa os dados locais de pokémon do arquivo assets/data/pokedex_data.json.
/// Carregado uma vez em memória ao iniciar o app — sem nenhuma chamada de rede.
class PokedexDataService {
  static const String _assetPath  = 'assets/data/pokedex_data.json';
  static const String _namesPath  = 'assets/data/pokemon_names.json';

  static PokedexDataService? _instance;
  static PokedexDataService get instance =>
      _instance ??= PokedexDataService._();
  PokedexDataService._();

  Map<int, Map<String, dynamic>> _data  = {};
  Map<int, String>               _names = {};
  bool _loaded = false;

  /// Carrega o JSON do bundle em memória. Chamar uma vez no main().
  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _data = decoded.map((k, v) =>
          MapEntry(int.parse(k), Map<String, dynamic>.from(v as Map)));

      final rawNames = await rootBundle.loadString(_namesPath);
      final decodedNames = json.decode(rawNames) as Map<String, dynamic>;
      _names = decodedNames.map((k, v) => MapEntry(int.parse(k), v as String));

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

  /// Retorna a lista de grupos de flavor text (novo bundle).
  /// Cada grupo: {textPt, textEn, games: [...]}
  /// Fallback: converte o flavorText antigo (string) para lista com 1 grupo.
  List<Map<String, dynamic>> getFlavorTexts(int id) {
    final raw = get(id)?['flavorTexts'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    // Fallback para bundle antigo com flavorText como string
    final legacy = get(id)?['flavorText'] as String? ?? '';
    if (legacy.isNotEmpty) {
      return [{'textPt': legacy, 'textEn': '', 'games': <String>[]}];
    }
    return [];
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
}