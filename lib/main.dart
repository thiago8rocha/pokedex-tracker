import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dexcurator/core/app_constants.dart';
import 'package:dexcurator/theme/app_theme.dart';
import 'package:dexcurator/screens/pokedex_screen.dart';
import 'package:dexcurator/services/storage_service.dart';
import 'package:dexcurator/services/pokedex_data_service.dart';
import 'package:dexcurator/services/pokedex_silent_refresh_service.dart';
import 'package:dexcurator/screens/detail/detail_shared.dart'
    show initBilingualMode, initDefaultSprite;
import 'package:dexcurator/screens/disclaimer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Aumentar cache de imagens: 256MB e 1000 entradas
  PaintingBinding.instance.imageCache.maximumSize = 1000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 256 * 1024 * 1024;

  // Limpar cache legado do PokemonCacheService (pkcache_*)
  await _clearLegacyCacheIfNeeded();

  final savedThemeId = await StorageService().getThemeId();
  appThemeController.setTheme(savedThemeId, _themeModeFromId(savedThemeId));

  await initBilingualMode();
  await initDefaultSprite();

  // Carrega dados locais instantaneamente antes de mostrar qualquer tela
  await PokedexDataService.instance.load();

  // Verificar se o disclaimer já foi aceito
  final disclaimerSeen = await StorageService().isDisclaimerSeen();

  runApp(PokedexTrackerApp(showDisclaimer: !disclaimerSeen));

  // Verificação silenciosa em background — sem impacto visual
  PokedexSilentRefreshService.instance.startInBackground();
}

Future<void> _clearLegacyCacheIfNeeded() async {
  const sentinelKey = 'legacy_cache_cleared_v1';
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(sentinelKey) == true) return;

  final legacyKeys =
      prefs.getKeys().where((k) => k.startsWith('pkcache_')).toList();
  for (final k in legacyKeys) {
    await prefs.remove(k);
  }
  await prefs.setBool(sentinelKey, true);
}

ThemeMode _themeModeFromId(String id) {
  if (id == 'system') return ThemeMode.system;
  const darkIds = <String>{'dark'};
  return darkIds.contains(id) ? ThemeMode.dark : ThemeMode.light;
}

// ─── APP ─────────────────────────────────────────────────────────

class PokedexTrackerApp extends StatefulWidget {
  final bool showDisclaimer;
  const PokedexTrackerApp({super.key, this.showDisclaimer = false});

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
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: AppThemes.light(appThemeController.themeId),
      darkTheme: AppThemes.dark(appThemeController.themeId),
      themeMode: appThemeController.themeMode,
      home: widget.showDisclaimer
          ? const _DisclaimerGate()
          : const _LastDexLoader(),
    );
  }
}

// ─── DISCLAIMER GATE ─────────────────────────────────────────────

class _DisclaimerGate extends StatelessWidget {
  const _DisclaimerGate();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: DisclaimerScreen(isFromSettings: false),
      ),
    );
  }
}

// ─── LAST DEX LOADER ─────────────────────────────────────────────

class _LastDexLoader extends StatefulWidget {
  const _LastDexLoader();

  @override
  State<_LastDexLoader> createState() => _LastDexLoaderState();
}

class _LastDexLoaderState extends State<_LastDexLoader> {
  // Mapa de id → nome para restaurar a tela certa
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
    'pokopia': 'Pokopia',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lastId = await StorageService().getLastPokedexId();
    if (!mounted) return;
    final id = lastId ?? 'nacional';
    final name = _idToName[id] ?? 'Nacional';
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PokedexScreen(
          pokedexId: id,
          pokedexName: name,
          totalPokemon: id == 'nacional' ? 1025
              : id == 'pokémon_go' ? 941
              : id == 'pokopia' ? 304
              : 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}
