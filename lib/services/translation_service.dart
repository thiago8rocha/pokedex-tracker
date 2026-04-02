import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dexcurator/core/app_constants.dart';

/// Serviço de tradução centralizado do DexCurator.
///
/// - MyMemory API (gratuita, sem chave)
/// - Cache persistente via SharedPreferences
/// - Deduplicação de requisições em voo
/// - Pré-aquecimento em background no startup
///
/// NOTA: Este é o único ponto de tradução dinâmica do app.
/// Não usar endpoints alternativos (ex: translate.googleapis.com)
/// em outros arquivos — centralizar aqui.
class TranslationService {
  static const String   _cachePrefix = 'trcache_';
  static const Duration _timeout     = Duration(seconds: 8);

  static final Map<String, Future<String?>> _pending = {};
  static SharedPreferences? _prefs;

  // ── Inicialização ────────────────────────────────────────────────

  static Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ── API pública ──────────────────────────────────────────────────

  /// Traduz [text] de [from] para [to].
  /// Usa cache local — segunda chamada é instantânea.
  static Future<String?> translate(
    String text, {
    String from = 'en',
    String to   = 'pt-BR',
  }) async {
    if (text.trim().isEmpty) return null;

    final key = _key(from, to, text);

    await _ensurePrefs();
    final cached = _prefs!.getString(key);
    if (cached != null && cached.isNotEmpty) return cached;

    if (_pending.containsKey(key)) return _pending[key];

    final future = _fetch(text, from, to, key);
    _pending[key] = future;
    try {
      return await future;
    } finally {
      _pending.remove(key);
    }
  }

  /// Traduz uma lista em paralelo.
  static Future<List<String?>> translateAll(
    List<String> texts, {
    String from = 'en',
    String to   = 'pt-BR',
  }) async {
    return Future.wait(
        texts.map((t) => translate(t, from: from, to: to)));
  }

  /// Verifica se um texto já está cacheado (sem rede).
  static Future<bool> isCached(
    String text, {
    String from = 'en',
    String to   = 'pt-BR',
  }) async {
    await _ensurePrefs();
    return _prefs!.containsKey(_key(from, to, text));
  }

  /// Pré-aquece o cache traduzindo uma lista em background.
  static void warmup(
    List<String> texts, {
    String from = 'en',
    String to   = 'pt-BR',
  }) {
    Future(() async {
      const batchSize = 3;
      for (int i = 0; i < texts.length; i += batchSize) {
        final batch = texts.skip(i).take(batchSize).toList();
        await Future.wait(
          batch.map((t) => translate(t, from: from, to: to)),
        );
        if (i + batchSize < texts.length) {
          await Future.delayed(
              const Duration(milliseconds: 300));
        }
      }
    });
  }

  /// Limpa todo o cache de traduções.
  static Future<void> clearCache() async {
    await _ensurePrefs();
    final keys = _prefs!
        .getKeys()
        .where((k) => k.startsWith(_cachePrefix))
        .toList();
    for (final k in keys) await _prefs!.remove(k);
  }

  // ── Internos ─────────────────────────────────────────────────────

  static String _key(String from, String to, String text) =>
      '$_cachePrefix${from}_${to}_${text.hashCode}';

  static Future<String?> _fetch(
      String text, String from, String to, String key) async {
    const maxRetries = 3;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          await Future.delayed(
              Duration(seconds: 1 << attempt));
        }
        final url = Uri.parse(
          '${kMyMemoryBase}'
          '?q=${Uri.encodeComponent(text)}&langpair=$from|$to',
        );
        final res = await http.get(url, headers: {
          'User-Agent': kUserAgent,
        }).timeout(_timeout);

        if (res.statusCode == 200) {
          final json =
              jsonDecode(res.body) as Map<String, dynamic>;
          final result = json['responseData']
              ?['translatedText'] as String?;
          if (result != null &&
              result.isNotEmpty &&
              result !=
                  'PLEASE SELECT TWO DISTINCT LANGUAGES') {
            await _ensurePrefs();
            await _prefs!.setString(key, result);
            return result;
          }
        }
        if (res.statusCode == 429) {
          await Future.delayed(const Duration(seconds: 3));
        }
      } catch (_) {}
    }
    return null;
  }
}
