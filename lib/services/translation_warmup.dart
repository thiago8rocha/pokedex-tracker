import 'package:dexcurator/services/tcg_pocket_service.dart';
import 'package:dexcurator/services/translation_service.dart';

/// Pré-aquece o cache de traduções em background no startup do app.
///
/// Estratégia:
/// - No startup: traduz descrições dos sets mais recentes (usuário tende a abrir esses)
/// - Ao abrir um set: traduz todas as cartas daquele set em background
///
/// Uso em main.dart:
/// ```dart
/// void main() {
///   runApp(const MyApp());
///   TranslationWarmup.start(); // ← adicionar esta linha
/// }
/// ```
class TranslationWarmup {
  static bool _started = false;

  /// Inicia o warmup no startup. Seguro chamar múltiplas vezes.
  static void start() {
    if (_started) return;
    _started = true;
    Future(() => _runStartup());
  }

  /// Chamado ao abrir a lista de cartas de um set.
  /// Pré-traduz todas as descrições do set em background.
  static void warmupSet(String setId) {
    Future(() => _runSetWarmup(setId));
  }

  // ── Startup: sets mais recentes primeiro ─────────────────────────

  static Future<void> _runStartup() async {
    // Aguardar app inicializar antes de usar rede
    await Future.delayed(const Duration(seconds: 3));

    // Ordem: mais recentes primeiro (usuário tende a ir para os novos)
    // Baseado em kPocketSetOrder invertido
    final setsToWarmup = [
      'B2b', 'B2a', 'B2',   // Série B mais recentes
      'B1a', 'B1',
      'A4b', 'A4a', 'A4',   // Série A mais recentes
      'A3b', 'A3a', 'A3',
      'A2b', 'A2a', 'A2',
      'A1a', 'A1',
      'P-B', 'P-A',
    ];

    for (final setId in setsToWarmup) {
      await _runSetWarmup(setId);
      // Pausa entre sets para não saturar API e bateria
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  // ── Set warmup: buscar cartas e traduzir descrições ───────────────

  static Future<void> _runSetWarmup(String setId) async {
    try {
      final set = await TcgPocketService.fetchSet(setId);
      if (set == null || set.cards.isEmpty) return;

      // Para cada carta, buscar detalhes e traduzir em background
      // Processar em lotes de 5 para não sobrecarregar
      const batchSize = 5;
      final cards = set.cards;

      for (int i = 0; i < cards.length; i += batchSize) {
        final batch = cards.skip(i).take(batchSize).toList();

        await Future.wait(batch.map((card) async {
          try {
            // Extrair localId da imageUrl (já funciona em outros lugares)
            String localId = card.localId;
            final imgUrl = card.imageUrlLow;
            if (imgUrl != null) {
              final parts = imgUrl.split('/');
              if (parts.length >= 2) localId = parts[parts.length - 2];
            }

            // Verificar se description já está cacheada antes de fetchCard
            // (economiza requisições de rede)
            final detail = await TcgPocketService.fetchCard(
              card.id, setId: setId, localId: localId);

            if (detail?.description != null &&
                detail!.description!.isNotEmpty) {
              // Só traduz se não está cacheado ainda
              final alreadyCached = await TranslationService.isCached(
                  detail.description!);
              if (!alreadyCached) {
                await TranslationService.translate(detail.description!);
              }
            }
          } catch (_) {}
        }));

        // Pausa entre lotes dentro do set
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (_) {}
  }
}
