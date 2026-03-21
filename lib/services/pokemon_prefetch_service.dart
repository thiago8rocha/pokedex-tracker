import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pokedex_tracker/services/pokemon_cache_service.dart';

const String _base = 'https://pokeapi.co/api/v2';

/// Pré-carrega dados da PokeAPI em background após o app abrir.
/// Roda silenciosamente sem bloquear a UI.
/// Usa batches pequenos com pausa entre eles para não sobrecarregar a API.
class PokemonPrefetchService {
  static PokemonPrefetchService? _instance;
  static PokemonPrefetchService get instance =>
      _instance ??= PokemonPrefetchService._();
  PokemonPrefetchService._();

  bool _running = false;

  /// Inicia o prefetch em background.
  /// [priorityIds] — IDs a carregar primeiro (ex: Pokémon da Pokopia).
  /// [fullRangeEnd] — carrega 1..fullRangeEnd depois dos prioritários.
  Future<void> start({
    required List<int> priorityIds,
    int fullRangeEnd = 1025,
    int batchSize = 5,
    Duration pauseBetweenBatches = const Duration(milliseconds: 300),
  }) async {
    if (_running) return;
    _running = true;

    final cache = PokemonCacheService.instance;

    // Monta a fila: prioritários primeiro, depois o resto em ordem
    final prioritySet = priorityIds.toSet();
    final allIds = [
      ...priorityIds,
      ...List.generate(fullRangeEnd, (i) => i + 1)
          .where((id) => !prioritySet.contains(id)),
    ];

    // Processa em batches
    for (int i = 0; i < allIds.length; i += batchSize) {
      if (!_running) break;
      final batch = allIds.skip(i).take(batchSize).toList();
      await Future.wait(batch.map((id) => _prefetchOne(cache, id)));
      await Future.delayed(pauseBetweenBatches);
    }

    _running = false;
  }

  void stop() => _running = false;

  Future<void> _prefetchOne(PokemonCacheService cache, int id) async {
    try {
      // /pokemon/{id}
      if (await cache.getPokemon(id) == null) {
        final r = await http.get(Uri.parse('$_base/pokemon/$id'));
        if (r.statusCode == 200) {
          final data = json.decode(r.body) as Map<String, dynamic>;
          await cache.setPokemon(id, data);
          // Aproveita e cacheia as abilities encontradas
          final abilities = data['abilities'] as List<dynamic>? ?? [];
          for (final a in abilities) {
            final url = a['ability']['url'] as String;
            if (await cache.getAbility(url) == null) {
              try {
                final ra = await http.get(Uri.parse(url));
                if (ra.statusCode == 200) {
                  await cache.setAbility(url,
                      json.decode(ra.body) as Map<String, dynamic>);
                }
              } catch (_) {}
            }
          }
        }
      }

      // /pokemon-species/{id}
      if (await cache.getSpecies(id) == null) {
        final r = await http.get(Uri.parse('$_base/pokemon-species/$id'));
        if (r.statusCode == 200) {
          final data = json.decode(r.body) as Map<String, dynamic>;
          await cache.setSpecies(id, data);
          // Cacheia a cadeia evolutiva
          final evoUrl = data['evolution_chain']?['url'] as String?;
          if (evoUrl != null && await cache.getEvoChain(evoUrl) == null) {
            try {
              final re = await http.get(Uri.parse(evoUrl));
              if (re.statusCode == 200) {
                await cache.setEvoChain(evoUrl,
                    json.decode(re.body) as Map<String, dynamic>);
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {
      // Falha silenciosa — será tentado novamente na próxima abertura do app
    }
  }
}