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
    show initBilingualMode, initDefaultSprite, initShowFormsInList;
import 'package:dexcurator/screens/disclaimer_screen.dart';
import 'package:dexcurator/services/tcg_pocket_service.dart'
    show kPocketSetOrder, boosterAssetPath;
import 'package:dexcurator/services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PaintingBinding.instance.imageCache.maximumSize = 500;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;

  // Inicializar SharedPreferences uma vez e reutilizar
  final prefs = await SharedPreferences.getInstance();

  // Limpar cache legado em paralelo com outras operações leves
  // Cada Future é tipado separadamente para evitar cast errors
  final themeIdFuture      = StorageService().getThemeId();
  final disclaimerFuture   = StorageService().isDisclaimerSeen();
  final bilingualFuture    = initBilingualMode();
  final spriteFuture       = initDefaultSprite();
  final showFormsFuture    = initShowFormsInList();
  final warmupFuture       = StorageService.warmup();
  final legacyFuture       = _clearLegacyCacheIfNeeded(prefs);

  // Aguardar todas em paralelo — void futures não precisam de resultado
  final savedThemeId   = await themeIdFuture;
  final disclaimerSeen = await disclaimerFuture;
  await bilingualFuture;
  await spriteFuture;
  await showFormsFuture;
  await warmupFuture;
  await legacyFuture;

  appThemeController.setTheme(savedThemeId, _themeModeFromId(savedThemeId));

  // Dispara carregamentos em background — runApp() não espera por eles
  PokedexDataService.instance.load();
  LocationService.instance.warmup();

  runApp(DexCuratorApp(showDisclaimer: !disclaimerSeen));

  // Verificação silenciosa em background — sem impacto visual
  PokedexSilentRefreshService.instance.startInBackground();
}

Future<void> _clearLegacyCacheIfNeeded(SharedPreferences prefs) async {
  const sentinelKey = 'legacy_cache_cleared_v1';
  if (prefs.getBool(sentinelKey) == true) return;

  final legacyKeys =
      prefs.getKeys().where((k) => k.startsWith('pkcache_')).toList();

  // Remover todas as chaves em paralelo
  await Future.wait(legacyKeys.map((k) => prefs.remove(k)));
  await prefs.setBool(sentinelKey, true);
}

ThemeMode _themeModeFromId(String id) {
  if (id == 'system') return ThemeMode.system;
  const darkIds = <String>{'dark'};
  return darkIds.contains(id) ? ThemeMode.dark : ThemeMode.light;
}

// ─── APP ─────────────────────────────────────────────────────────

class DexCuratorApp extends StatefulWidget {
  final bool showDisclaimer;
  const DexCuratorApp({super.key, this.showDisclaimer = false});

  @override
  State<DexCuratorApp> createState() => _DexCuratorAppState();
}

class _DexCuratorAppState extends State<DexCuratorApp> {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final id in kPocketSetOrder) {
      precacheImage(AssetImage(boosterAssetPath(id)), context).catchError((_) {});
    }
  }

  Future<void> _load() async {
    // Aguarda PokedexDataService terminar o carregamento em background
    while (!PokedexDataService.instance.isLoaded) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }
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
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
