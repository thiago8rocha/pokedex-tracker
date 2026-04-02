import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dexcurator/core/app_constants.dart';
import 'package:dexcurator/services/pokedex_data_service.dart';
import 'package:dexcurator/translations.dart';

/// Verifica silenciosamente em background se os dados da PokeAPI mudaram.
///
/// Estratégia:
/// - Roda após o app abrir, sem bloquear nada
/// - Verifica um sample aleatório de pokémon por sessão (~20)
/// - Se detectar divergência, refaz o download completo em background
/// - Dados corrigidos ficam disponíveis na PRÓXIMA abertura do app
/// - Nunca afeta a sessão atual — zero impacto visual
class PokedexSilentRefreshService {
  static const String _lastCheckKey     = 'silent_refresh_last_check';
  static const String _pendingKey       = 'silent_refresh_pending_file';
  static const int    _checkIntervalDays = 7;
  static const int    _sampleSize        = 20;
  static const int    _batchSize         = 10;
  static const String _pendingFileName   = 'pokedex_data_pending.json';

  static PokedexSilentRefreshService? _instance;
  static PokedexSilentRefreshService get instance =>
      _instance ??= PokedexSilentRefreshService._();
  PokedexSilentRefreshService._();

  bool _running = false;

  void startInBackground() {
    if (_running) return;
    _runAsync();
  }

  Future<void> _runAsync() async {
    _running = true;
    try {
      await _applyPendingUpdateIfExists();

      if (!await _shouldCheck()) {
        _running = false;
        return;
      }

      final hasChanges = await _checkSample();

      if (hasChanges) {
        await _downloadAndSavePending();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _lastCheckKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
    _running = false;
  }

  Future<void> _applyPendingUpdateIfExists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPending = prefs.getBool(_pendingKey) ?? false;
      if (!hasPending) return;

      final dir = await getApplicationDocumentsDirectory();
      final pendingFile = File('${dir.path}/$_pendingFileName');
      if (!await pendingFile.exists()) {
        await prefs.remove(_pendingKey);
        return;
      }

      final raw = await pendingFile.readAsString();
      final decoded = json.decode(raw) as Map<String, dynamic>;
      if (decoded.length < 100) {
        await pendingFile.delete();
        await prefs.remove(_pendingKey);
        return;
      }

      final activeFile =
          File('${dir.path}/pokedex_data_override.json');
      await pendingFile.rename(activeFile.path);
      await prefs.remove(_pendingKey);
    } catch (_) {}
  }

  Future<bool> _shouldCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastCheckKey);
    if (lastCheck == null) return true;
    final daysSince = DateTime.now()
        .difference(
            DateTime.fromMillisecondsSinceEpoch(lastCheck))
        .inDays;
    return daysSince >= _checkIntervalDays;
  }

  Future<bool> _checkSample() async {
    final svc = PokedexDataService.instance;
    if (!svc.isLoaded) return false;

    final step = kTotalPokemon ~/ _sampleSize;
    final sampleIds =
        List.generate(_sampleSize, (i) => (i * step) + 1);

    int divergencias = 0;

    for (int i = 0; i < sampleIds.length; i += _batchSize) {
      final batch =
          sampleIds.skip(i).take(_batchSize).toList();
      final results = await Future.wait(
          batch.map((id) => _checkOne(svc, id)));
      divergencias +=
          results.where((changed) => changed).length;

      if (divergencias >= 2) return true;

      await Future.delayed(const Duration(milliseconds: 500));
    }

    return divergencias > 0;
  }

  Future<bool> _checkOne(
      PokedexDataService svc, int id) async {
    try {
      final r = await http
          .get(Uri.parse('${kPokeApiBase}/pokemon/$id'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return false;

      final remote =
          json.decode(r.body) as Map<String, dynamic>;
      final local = svc.get(id);
      if (local == null) return true;

      final remoteTypes = (remote['types'] as List<dynamic>)
          .map((t) => t['type']['name'] as String)
          .toList();
      final localTypes =
          (local['types'] as List<dynamic>?)?.cast<String>() ??
              [];

      final remoteHeight =
          '${(remote['height'] as int) / 10} m';
      final localHeight = local['height'] as String? ?? '';

      return remoteTypes.join(',') != localTypes.join(',') ||
          remoteHeight != localHeight;
    } catch (_) {
      return false;
    }
  }

  Future<void> _downloadAndSavePending() async {
    final allData = <int, Map<String, dynamic>>{};

    for (int i = 1; i <= kTotalPokemon; i += _batchSize) {
      final batch = List.generate(_batchSize, (j) => i + j)
          .where((id) => id <= kTotalPokemon)
          .toList();

      final results = await Future.wait(
          batch.map((id) => _fetchCompact(id)));

      for (final r in results) {
        if (r != null) allData[r['id'] as int] = r;
      }

      await Future.delayed(
          const Duration(milliseconds: 400));
    }

    if (allData.length < 900) return;

    final dir = await getApplicationDocumentsDirectory();
    final pending = File('${dir.path}/$_pendingFileName');
    await pending.writeAsString(json.encode(
        allData.map((k, v) => MapEntry(k.toString(), v))));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, true);
  }

  Future<Map<String, dynamic>?> _fetchCompact(int id) async {
    try {
      final responses = await Future.wait([
        http
            .get(Uri.parse('${kPokeApiBase}/pokemon/$id'))
            .timeout(const Duration(seconds: 10)),
        http
            .get(
                Uri.parse('${kPokeApiBase}/pokemon-species/$id'))
            .timeout(const Duration(seconds: 10)),
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

      final abilities =
          (p['abilities'] as List<dynamic>).map((a) {
        final nameEn = a['ability']['name'] as String;
        final isHidden = a['is_hidden'] as bool;
        return {
          'nameEn': nameEn,
          'namePt': translateAbility(nameEn),
          'isHidden': isHidden,
          'description': '',
        };
      }).toList();

      String category = '';
      for (final g in (s['genera'] as List<dynamic>? ?? [])) {
        if (g['language']['name'] == 'pt-BR') {
          category = g['genus'];
          break;
        }
      }
      if (category.isEmpty) {
        for (final g
            in (s['genera'] as List<dynamic>? ?? [])) {
          if (g['language']['name'] == 'en') {
            category = g['genus'];
            break;
          }
        }
      }

      String flavorEn = '';
      for (final e in (s['flavor_text_entries']
                  as List<dynamic>? ??
              [])
          .reversed
          .toList()) {
        if (e['language']['name'] == 'en') {
          flavorEn = (e['flavor_text'] as String)
              .replaceAll('\n', ' ')
              .replaceAll('\f', ' ')
              .trim();
          break;
        }
      }

      return {
        'id': id,
        'types': types,
        'height': '${(p['height'] as int) / 10} m',
        'weight': '${(p['weight'] as int) / 10} kg',
        'abilities': abilities,
        'category': category,
        'flavorEn': flavorEn,
        'generation': s['generation']?['name'] ?? '',
        'captureRate': s['capture_rate'] ?? 0,
        'evoChain': <Map<String, dynamic>>[],
      };
    } catch (_) {
      return null;
    }
  }
}
