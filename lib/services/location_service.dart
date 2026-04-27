import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Provides in-game location data for all main-series games.
/// Data shape: { "speciesId": { "dexId": [ {l, g?, m?, n?, x?, r?, t?, w?} ] } }
/// Keys: l=location, g=game version, m=method, n=minLevel, x=maxLevel,
///       r=rarity, t=time, w=weather
class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  LocationService._();

  Map<String, dynamic>? _data;
  Future<void>? _warmupFuture;

  /// Safe to call concurrently — all callers share the same Future.
  Future<void> warmup() {
    _warmupFuture ??= _doWarmup();
    return _warmupFuture!;
  }

  Future<void> _doWarmup() async {
    final raw = await rootBundle.loadString('assets/locations.json');
    if (kDebugMode) {
      _data = json.decode(raw) as Map<String, dynamic>;
    } else {
      _data = await compute<String, Map<String, dynamic>>(
        (s) => json.decode(s) as Map<String, dynamic>,
        raw,
      );
    }
  }

  /// Returns locations for a species in a specific dex/game.
  /// Each entry has: location, game, method, minLevel, maxLevel, rarity, time, weather
  List<Map<String, dynamic>> getLocations(int speciesId, String dexId) {
    if (_data == null) return [];
    final byDex = _data![speciesId.toString()] as Map<String, dynamic>?;
    if (byDex == null) return [];
    final raw = byDex[dexId] as List<dynamic>?;
    if (raw == null) return [];
    return raw.map((e) {
      final r = e as Map<String, dynamic>;
      return {
        'location':  r['l'] as String,
        'game':      r['g'] as String? ?? '',
        'method':    r['m'] as String? ?? '',
        'minLevel':  r['n'] as String? ?? '',
        'maxLevel':  r['x'] as String? ?? r['n'] as String? ?? '',
        'rarity':    r['r'] as String? ?? '',
        'time':      r['t'] as String? ?? '',
        'weather':   r['w'] as String? ?? '',
      };
    }).toList();
  }

  /// Returns all dexIds that have location data for a species.
  List<String> getAvailableDexIds(int speciesId) {
    if (_data == null) return [];
    final byDex = _data![speciesId.toString()] as Map<String, dynamic>?;
    if (byDex == null) return [];
    return byDex.keys.toList();
  }

  bool get isLoaded => _data != null;
}
