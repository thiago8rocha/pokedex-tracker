import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dexcurator/core/app_constants.dart';
import 'package:dexcurator/services/pokedex_data_service.dart';
import 'package:dexcurator/translations.dart';

/// Baixa dados de todos os 1025 pokémon em batches paralelos
/// e salva compacto no PokedexDataService.
/// Chamado silenciosamente na tela de disclaimer.
class PokedexDownloadService {
  static PokedexDownloadService? _instance;
  static PokedexDownloadService get instance =>
      _instance ??= PokedexDownloadService._();
  PokedexDownloadService._();

  bool _running = false;
  bool get isRunning => _running;

  void Function(double)? onProgress;

  Future<void> downloadAll({
    int totalPokemon = kTotalPokemon,
    int batchSize = 20,
  }) async {
    if (_running) return;
    if (await PokedexDataService.instance.isReady()) {
      await PokedexDataService.instance.load();
      return;
    }
    _running = true;

    final allData = <int, Map<String, dynamic>>{};
    final ids = List.generate(totalPokemon, (i) => i + 1);
    int done = 0;

    // ── Fase 1: /pokemon e /species em paralelo por batch ─────────
    for (int i = 0; i < ids.length; i += batchSize) {
      if (!_running) break;
      final batch = ids.skip(i).take(batchSize).toList();

      final results =
          await Future.wait(batch.map((id) => _fetchPokemonAndSpecies(id)));

      for (final r in results) {
        if (r != null) allData[r['id'] as int] = r;
      }

      done += batch.length;
      onProgress?.call(done / totalPokemon * 0.7);
    }

    // ── Fase 2: evolution chains ───────────────────────────────────
    final evoUrls = <String>{};
    for (final d in allData.values) {
      final url = d['_evoUrl'] as String?;
      if (url != null) evoUrls.add(url);
    }

    final evoCache = <String, List<Map<String, dynamic>>>{};
    final evoList = evoUrls.toList();
    for (int i = 0; i < evoList.length; i += batchSize) {
      if (!_running) break;
      final batch = evoList.skip(i).take(batchSize).toList();
      final results =
          await Future.wait(batch.map((u) => _fetchEvoChain(u)));
      for (int j = 0; j < batch.length; j++) {
        if (results[j] != null) evoCache[batch[j]] = results[j]!;
      }
      onProgress?.call(0.7 + (i / evoList.length) * 0.3);
    }

    for (final d in allData.values) {
      final url = d.remove('_evoUrl') as String?;
      if (url != null && evoCache.containsKey(url)) {
        d['evoChain'] = evoCache[url];
      } else {
        d['evoChain'] = <Map<String, dynamic>>[];
      }
    }

    await PokedexDataService.instance.saveAll(allData);
    onProgress?.call(1.0);
    _running = false;
  }

  void stop() => _running = false;

  Future<Map<String, dynamic>?> _fetchPokemonAndSpecies(int id) async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('${kPokeApiBase}/pokemon/$id')),
        http.get(Uri.parse('${kPokeApiBase}/pokemon-species/$id')),
      ]);

      if (responses[0].statusCode != 200 ||
          responses[1].statusCode != 200) return null;

      final p =
          json.decode(responses[0].body) as Map<String, dynamic>;
      final s =
          json.decode(responses[1].body) as Map<String, dynamic>;

      final types = (p['types'] as List<dynamic>)
          .map((t) => t['type']['name'] as String)
          .toList();

      final height =
          '${((p['height'] as int) / 10).toStringAsFixed(1)} m';
      final weight =
          '${((p['weight'] as int) / 10).toStringAsFixed(1)} kg';

      final abilities = (p['abilities'] as List<dynamic>).map((a) {
        final nameEn = a['ability']['name'] as String;
        final isHidden = a['is_hidden'] as bool;
        final namePt = translateAbility(nameEn);
        return {
          'nameEn': nameEn,
          'namePt': namePt,
          'isHidden': isHidden,
          'description': '',
          'abilityUrl': a['ability']['url'] as String,
        };
      }).toList();

      String category = '';
      for (final g in (s['genera'] as List<dynamic>? ?? [])) {
        if (g['language']['name'] == 'pt-BR') {
          category = g['genus'] as String;
          break;
        }
      }
      if (category.isEmpty) {
        for (final g in (s['genera'] as List<dynamic>? ?? [])) {
          if (g['language']['name'] == 'en') {
            final parts = (g['genus'] as String)
                .replaceAll(' Pokémon', '')
                .trim();
            category = 'Pokémon $parts';
            break;
          }
        }
      }

      String flavorText = '';
      for (final e
          in (s['flavor_text_entries'] as List<dynamic>? ?? [])) {
        if (e['language']['name'] == 'en') {
          flavorText = (e['flavor_text'] as String)
              .replaceAll('\n', ' ')
              .replaceAll('\f', ' ')
              .trim();
          break;
        }
      }

      final games = (s['pokedex_numbers'] as List<dynamic>? ?? [])
          .map((g) => g['pokedex']['name'] as String)
          .toList();

      final evoUrl = s['evolution_chain']?['url'] as String?;

      return {
        'id': id,
        'types': types,
        'height': height,
        'weight': weight,
        'abilities': abilities,
        'category': category,
        'flavorText': flavorText,
        'games': games,
        '_evoUrl': evoUrl,
      };
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _fetchEvoChain(
      String url) async {
    try {
      final r = await http.get(Uri.parse(url));
      if (r.statusCode != 200) return null;

      final d = json.decode(r.body) as Map<String, dynamic>;
      final chain = <Map<String, dynamic>>[];
      Map<String, dynamic>? cur =
          d['chain'] as Map<String, dynamic>?;

      while (cur != null) {
        final su = cur['species']['url'] as String;
        final parts = su.split('/');
        final id =
            int.tryParse(parts[parts.length - 2]) ?? 0;
        final name = cur['species']['name'] as String;

        final details =
            (cur['evolution_details'] as List<dynamic>?)
                ?.firstOrNull;
        String cond = '';
        if (details != null) {
          final lvl = details['min_level'];
          final item = details['item']?['name'];
          final happiness = details['min_happiness'];
          if (lvl != null) {
            cond = 'Nv. $lvl';
          } else if (item != null) {
            cond = (item as String).replaceAll('-', ' ');
          } else if (happiness != null) {
            cond = 'Amizade';
          } else {
            cond = 'Evoluir';
          }
        }

        chain.add({
          'id': id,
          'name': name,
          'condition': cond,
          'types': <String>[],
        });
        final next = cur['evolves_to'] as List<dynamic>;
        cur = next.isNotEmpty
            ? next[0] as Map<String, dynamic>
            : null;
      }

      return chain;
    } catch (_) {
      return null;
    }
  }
}
