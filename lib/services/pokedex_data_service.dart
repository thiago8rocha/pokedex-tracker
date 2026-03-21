import 'dart:convert';
import 'package:flutter/services.dart';

/// Acessa os dados locais de pokémon do arquivo assets/data/pokedex_data.json.
/// Carregado uma vez em memória ao iniciar o app — sem nenhuma chamada de rede.
class PokedexDataService {
  static const String _assetPath = 'assets/data/pokedex_data.json';

  static PokedexDataService? _instance;
  static PokedexDataService get instance =>
      _instance ??= PokedexDataService._();
  PokedexDataService._();

  Map<int, Map<String, dynamic>> _data = {};
  bool _loaded = false;

  /// Carrega o JSON do bundle em memória. Chamar uma vez no main().
  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _data = decoded.map((k, v) =>
          MapEntry(int.parse(k), Map<String, dynamic>.from(v as Map)));
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

  String getFlavorEn(int id) =>
      get(id)?['flavorEn'] as String? ?? '';

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
}