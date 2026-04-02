import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dexcurator/screens/detail/detail_shared.dart' show kApiBase;
import 'package:dexcurator/services/storage_service.dart';
import 'package:dexcurator/services/pokeapi_service.dart';
import 'package:dexcurator/services/dex_bundle_service.dart';

/// Pré-carrega os detalhes (tipo, categoria, poder, precisão, PP)
/// de todos os moves do jogo ativo em background ao abrir o app.
/// Os dados ficam no [MoveDetailCache] que a MovesListScreen usa.
class MoveWarmupService {
  MoveWarmupService._();

  // Cache global singleton — compartilhado com as telas de moves
  static final Map<String, Map<String, dynamic>> cache = {};

  static bool _started = false;

  /// Inicia o warmup em background. Pode ser chamado múltiplas vezes — só executa uma vez.
  static void start() {
    if (_started) return;
    _started = true;
    _run();
  }

  /// Reinicia para um jogo diferente (chamado quando o usuário troca de jogo).
  static void startForGame(String gameId) {
    _runForGame(gameId);
  }

  static Future<void> _run() async {
    // Pequeno delay para não competir com o carregamento inicial da UI
    await Future.delayed(const Duration(seconds: 3));

    final lastDex = await StorageService().getLastPokedexId();
    if (lastDex == null ||
        lastDex.startsWith('pokopia') ||
        lastDex == 'pokémon_go') return;

    await _runForGame(lastDex);
  }

  static Future<void> _runForGame(String gameId) async {
    final sections = PokeApiService.pokedexSections[gameId];
    if (sections == null || sections.isEmpty) return;

    // Coletar todos os speciesIds do jogo
    final allIds = <int>{};
    for (final s in sections) {
      final entries = await DexBundleService.instance.loadSection(s.apiName);
      if (entries != null) {
        for (final e in entries) allIds.add(e['speciesId']!);
      }
    }
    if (allIds.isEmpty) return;

    // Coletar URLs de moves dos pokémon (sem buscar detalhes ainda)
    final moveUrls = <String, String>{}; // nameEn → url
    final ids      = allIds.toList()..sort();

    for (int i = 0; i < ids.length; i += 15) {
      final batch = ids.skip(i).take(15).toList();
      await Future.wait(batch.map((id) async {
        try {
          final res = await http.get(Uri.parse('$kApiBase/pokemon/$id'))
              .timeout(const Duration(seconds: 8));
          if (res.statusCode != 200) return;
          final data  = jsonDecode(res.body) as Map<String, dynamic>;
          final moves = data['moves'] as List<dynamic>? ?? [];
          for (final m in moves) {
            final name = m['move']['name'] as String;
            final url  = m['move']['url'] as String;
            if (!moveUrls.containsKey(name)) moveUrls[name] = url;
          }
        } catch (_) {}
      }));
      // Pequena pausa entre lotes para não saturar a rede
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Agora buscar detalhes de cada move que ainda não está cacheado
    final uncached = moveUrls.entries
        .where((e) => !cache.containsKey(e.value))
        .toList();

    for (int i = 0; i < uncached.length; i += 10) {
      final batch = uncached.skip(i).take(10).toList();
      await Future.wait(batch.map((e) async {
        try {
          final res = await http.get(Uri.parse(e.value))
              .timeout(const Duration(seconds: 8));
          if (res.statusCode == 200) {
            cache[e.value] = jsonDecode(res.body) as Map<String, dynamic>;
          }
        } catch (_) {}
      }));
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }
}
