import 'dart:convert';
import 'package:flutter/services.dart';

/// Lê as listas de pokémon de cada pokedex diretamente do bundle local
/// (assets/data/dex/dex_*.json) sem precisar de rede.
///
/// Formato dos arquivos:
/// {
///   "apiName": "galar",
///   "entries": [
///     {"entryNumber": 1, "speciesId": 810},
///     {"entryNumber": 26, "speciesId": 26, "formaKey": "26_ALOLA"}  // opcional
///   ]
/// }
///
/// O campo "formaKey" é opcional e identifica formas alternativas que devem
/// ser tratadas como entradas distintas na pokédex (ex: regionais no GO).
/// Quando presente, o sprite e os tipos devem ser buscados pela formaKey,
/// não pelo speciesId da espécie base.
class DexBundleService {
  static const String _basePath = 'assets/data/dex';

  static DexBundleService? _instance;
  static DexBundleService get instance =>
      _instance ??= DexBundleService._();
  DexBundleService._();

  // Cache em memória: apiName → lista de entries
  // Usa Map<String, dynamic> para suportar formaKey opcional (String)
  final Map<String, List<Map<String, dynamic>>> _cache = {};

  /// Tenta carregar a dex do bundle para um dado apiName.
  /// Retorna null se o arquivo não existir no bundle.
  Future<List<Map<String, dynamic>>?> loadSection(String apiName) async {
    if (_cache.containsKey(apiName)) return _cache[apiName];

    try {
      final raw = await rootBundle.loadString('$_basePath/dex_$apiName.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final rawEntries = decoded['entries'] as List<dynamic>;
      final entries = rawEntries.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return <String, dynamic>{
          'entryNumber': m['entryNumber'] as int,
          'speciesId':   m['speciesId']   as int,
          if (m['formaKey'] != null) 'formaKey': m['formaKey'] as String,
        };
      }).toList();
      _cache[apiName] = entries;
      return entries;
    } catch (_) {
      return null;
    }
  }

  /// Limpa o cache em memória (raramente necessário).
  void clearCache() => _cache.clear();
}