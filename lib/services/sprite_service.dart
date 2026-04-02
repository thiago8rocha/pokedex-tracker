import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:dexcurator/core/app_constants.dart';

/// Gerencia download e cache local de sprites de pokémon.
///
/// Tipos:
///   'artwork' — official artwork (grid + detalhe) — cacheado localmente
///   'pixel'   — pixel sprite pequeno — cacheado localmente
///   outros    — shiny, home, etc. carregam via rede normalmente
///
/// Cache em disco: <appSupportDir>/sprites/{tipo}/{id}.png
class SpriteService {
  static SpriteService? _instance;
  static SpriteService get instance =>
      _instance ??= SpriteService._();
  SpriteService._();

  // Usa constante centralizada.
  static const String _base = kSpriteBase;

  final _downloaded =
      StreamController<(int, String)>.broadcast();
  Stream<(int, String)> get onDownloaded => _downloaded.stream;

  final _inProgress = <String>{};
  Directory? _cacheDir;

  Future<Directory> get _dir async {
    _cacheDir ??= Directory(
      '${(await getApplicationSupportDirectory()).path}/sprites',
    );
    return _cacheDir!;
  }

  String _url(int id, String type) {
    switch (type) {
      case 'pixel':
        return '$_base/$id.png';
      case 'artwork':
      default:
        return '$_base/other/official-artwork/$id.png';
    }
  }

  String _key(int id, String type) => '${type}_$id';

  Future<File?> getCached(int id, String type) async {
    final file =
        File('${(await _dir).path}/$type/$id.png');
    return (await file.exists()) ? file : null;
  }

  Future<File?> download(int id, String type) async {
    final key = _key(id, type);
    if (_inProgress.contains(key)) return null;

    final file =
        File('${(await _dir).path}/$type/$id.png');
    if (await file.exists()) return file;

    _inProgress.add(key);
    try {
      await file.parent.create(recursive: true);
      final res = await http
          .get(Uri.parse(_url(id, type)))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200 &&
          res.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(res.bodyBytes);
        _downloaded.add((id, type));
        return file;
      }
    } catch (_) {
    } finally {
      _inProgress.remove(key);
    }
    return null;
  }

  Future<void> prefetchDexWithFallback(
      List<int> ids) async {
    const batchSize = 20;

    for (int i = 0; i < ids.length; i += batchSize) {
      final batch =
          ids.skip(i).take(batchSize).toList();
      await Future.wait(
          batch.map((id) => download(id, 'pixel')));
    }

    _downloadBackground(ids);
  }

  void _downloadBackground(List<int> priorityIds) async {
    const batchSize = 6;
    final allIds = List.generate(kTotalPokemon, (i) => i + 1);
    final rest = allIds
        .where((id) => !priorityIds.contains(id))
        .toList();
    final ordered = [...priorityIds, ...rest];

    for (int i = 0; i < ordered.length; i += batchSize) {
      final batch =
          ordered.skip(i).take(batchSize).toList();
      await Future.wait(
          batch.map((id) => download(id, 'artwork')));
      await Future.delayed(
          const Duration(milliseconds: 50));
    }
  }

  Future<List<int>> checkStaleSprites(
      List<int> sampleIds, String type) async {
    final stale = <int>[];
    for (final id in sampleIds) {
      final file = await getCached(id, type);
      if (file == null) continue;
      try {
        final res = await http
            .head(Uri.parse(_url(id, type)))
            .timeout(const Duration(seconds: 5));
        final remoteSize = int.tryParse(
                res.headers['content-length'] ?? '') ??
            0;
        final localSize = await file.length();
        if (remoteSize > 0 && remoteSize != localSize) {
          stale.add(id);
        }
      } catch (_) {}
    }
    return stale;
  }

  Future<int> cacheSize() async {
    final dir = await _dir;
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity
        in dir.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> clearCache() async {
    final dir = await _dir;
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    _cacheDir = null;
  }
}
