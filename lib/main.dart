import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pokedex_tracker/theme/app_theme.dart';
import 'package:pokedex_tracker/screens/pokedex_screen.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/services/pokedex_data_service.dart';
import 'package:pokedex_tracker/services/translation_warmup.dart';
import 'package:pokedex_tracker/services/move_warmup_service.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart'
    show initBilingualMode, initDefaultSprite, PokeballLoader;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Aumentar cache de imagens: 256MB e 1000 entradas
  // Evita re-decodificação de sprites ao navegar entre pokedexes
  PaintingBinding.instance.imageCache.maximumSize      = 1000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 256 * 1024 * 1024;

  // Limpar cache antigo do PokemonCacheService (prefixo pkcache_)
  // que causava OutOfMemoryError ao ser carregado pelo SharedPreferences.
  await _clearLegacyCacheIfNeeded();

  final savedThemeId = await StorageService().getThemeId();
  appThemeController.setTheme(savedThemeId, _themeModeFromId(savedThemeId));

  await initBilingualMode();
  await initDefaultSprite();

  // Carrega dados locais instantaneamente antes de mostrar qualquer tela
  await PokedexDataService.instance.load();

  runApp(const PokedexTrackerApp());
  TranslationWarmup.start();
  MoveWarmupService.start();
}

Future<void> _clearLegacyCacheIfNeeded() async {
  const sentinelKey = 'legacy_cache_cleared_v1';
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(sentinelKey) == true) return;

  final legacyKeys = prefs.getKeys()
      .where((k) => k.startsWith('pkcache_'))
      .toList();

  // Remove todas as chaves legadas em paralelo
  await Future.wait(legacyKeys.map((k) => prefs.remove(k)));

  await prefs.setBool(sentinelKey, true);
}

ThemeMode _themeModeFromId(String id) {
  if (id == 'system') return ThemeMode.system;
  const darkIds = <String>{'dark'};
  return darkIds.contains(id) ? ThemeMode.dark : ThemeMode.light;
}

class PokedexTrackerApp extends StatefulWidget {
  const PokedexTrackerApp({super.key});

  @override
  State<PokedexTrackerApp> createState() => _PokedexTrackerAppState();
}

class _PokedexTrackerAppState extends State<PokedexTrackerApp> {
  @override
  void initState() {
    super.initState();
    appThemeController.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    appThemeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokedex Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: appThemeController.themeMode,
      theme:     AppThemes.light(appThemeController.themeId),
      darkTheme: AppThemes.dark(appThemeController.themeId),
      home: _LastDexLoader(),
    );
  }
}

// ─── LOADER DA ÚLTIMA POKEDEX ─────────────────────────────────────

class _LastDexLoader extends StatefulWidget {
  const _LastDexLoader();
  @override State<_LastDexLoader> createState() => _LastDexLoaderState();
}

class _LastDexLoaderState extends State<_LastDexLoader> {
  // Mapa de id → nome/total para restaurar a tela certa
  static const _idToName = <String, String>{
    'nacional': 'Nacional',
    'pokémon_go': 'Pokémon GO',
    'red___blue': 'Red / Blue',
    'yellow': 'Yellow',
    'gold___silver': 'Gold / Silver',
    'crystal': 'Crystal',
    'ruby___sapphire': 'Ruby / Sapphire',
    'firered___leafgreen_(gba)': 'FireRed / LeafGreen (GBA)',
    'emerald': 'Emerald',
    'diamond___pearl': 'Diamond / Pearl',
    'platinum': 'Platinum',
    'heartgold___soulsilver': 'HeartGold / SoulSilver',
    'black___white': 'Black / White',
    'black_2___white_2': 'Black 2 / White 2',
    'x___y': 'X / Y',
    'omega_ruby___alpha_sapphire': 'Omega Ruby / Alpha Sapphire',
    'sun___moon': 'Sun / Moon',
    'ultra_sun___ultra_moon': 'Ultra Sun / Ultra Moon',
    "let's_go_pikachu___eevee": "Let's Go Pikachu / Eevee",
    'sword___shield': 'Sword / Shield',
    'brilliant_diamond___shining_pearl': 'Brilliant Diamond / Shining Pearl',
    'legends:_arceus': 'Legends: Arceus',
    'scarlet___violet': 'Scarlet / Violet',
    'legends:_z-a': 'Legends: Z-A',
    'firered___leafgreen': 'FireRed / LeafGreen',
  };

  static const _idToTotal = <String, int>{
    'nacional': 1025, 'pokémon_go': 941,
    'red___blue': 151, 'yellow': 151,
    'gold___silver': 251, 'crystal': 251,
    'ruby___sapphire': 386, 'firered___leafgreen_(gba)': 386, 'emerald': 386,
    'diamond___pearl': 493, 'platinum': 493, 'heartgold___soulsilver': 493,
    'black___white': 649, 'black_2___white_2': 649,
    'x___y': 721, 'omega_ruby___alpha_sapphire': 721,
    'sun___moon': 807, 'ultra_sun___ultra_moon': 807,
    "let's_go_pikachu___eevee": 153,
    'sword___shield': 400, 'brilliant_diamond___shining_pearl': 493,
    'legends:_arceus': 242, 'scarlet___violet': 400,
    'legends:_z-a': 132, 'firered___leafgreen': 386,
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: StorageService().getLastPokedexId(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: PokeballLoader()));
        }
        final lastId = snap.data;
        final id    = (lastId != null && _idToName.containsKey(lastId)) ? lastId : 'nacional';
        final name  = _idToName[id] ?? 'Nacional';
        final total = _idToTotal[id] ?? 1025;
        return PokedexScreen(
          pokedexId: id,
          pokedexName: name,
          totalPokemon: total,
        );
      },
    );
  }
}