import 'package:flutter/material.dart';
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart'
    show ptType, defaultSpriteNotifier;
import 'package:pokedex_tracker/screens/go/go_detail_screen.dart';
import 'package:pokedex_tracker/services/pokeapi_service.dart';
import 'package:pokedex_tracker/services/pokedex_data_service.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/theme/type_colors.dart';

// Gigantamax confirmados no Pokémon GO (mar/2026)
// Fontes: Bulbapedia (Gigantamax GO), Pokemon.com, GO Hub, Fandom Wiki
// Não incluídos: Orbeetle, Drednaw, Coalossal, Flapple, Appletun, Sandaconda,
// Toxtricity, Centiskorch, Hatterene, Grimmsnarl, Copperajah, Duraludon,
// Dragapult, Urshifu, Corviknight, Alcremie, Frosmoth — ainda não lançados no GO.
const _goGmax = [
  _GmaxEntry(id: 3,   name: 'Venusaur',   spriteKey: '3_GMAX'),
  _GmaxEntry(id: 6,   name: 'Charizard',  spriteKey: '6_GMAX'),
  _GmaxEntry(id: 9,   name: 'Blastoise',  spriteKey: '9_GMAX'),
  _GmaxEntry(id: 12,  name: 'Butterfree', spriteKey: '12_GMAX'),
  _GmaxEntry(id: 25,  name: 'Pikachu',    spriteKey: '25_GMAX'),
  _GmaxEntry(id: 52,  name: 'Meowth',     spriteKey: '52_GMAX'),
  _GmaxEntry(id: 68,  name: 'Machamp',    spriteKey: '68_GMAX'),
  _GmaxEntry(id: 94,  name: 'Gengar',     spriteKey: '94_GMAX'),
  _GmaxEntry(id: 99,  name: 'Kingler',    spriteKey: '99_GMAX'),
  _GmaxEntry(id: 131, name: 'Lapras',     spriteKey: '131_GMAX'),
  _GmaxEntry(id: 143, name: 'Snorlax',    spriteKey: '143_GMAX'),
  _GmaxEntry(id: 569, name: 'Garbodor',   spriteKey: '569_GMAX'),
  _GmaxEntry(id: 809, name: 'Melmetal',   spriteKey: '809_GMAX'),
  _GmaxEntry(id: 812, name: 'Rillaboom',  spriteKey: '812_GMAX'),
  _GmaxEntry(id: 815, name: 'Cinderace',  spriteKey: '815_GMAX'),
  _GmaxEntry(id: 818, name: 'Inteleon',   spriteKey: '818_GMAX'),
];

String _gmaxSprite(String key, int id, String type) {
  final folder = type == 'pixel' ? 'pixel' : type == 'home' ? 'home' : 'artwork';
  return 'assets/sprites/$folder/$key.webp';
}

class GoGigantamaxScreen extends StatefulWidget {
  const GoGigantamaxScreen({super.key});
  @override
  State<GoGigantamaxScreen> createState() => _GoGigantamaxScreenState();
}

class _GoGigantamaxScreenState extends State<GoGigantamaxScreen> {
  final _api     = PokeApiService();
  final _storage = StorageService();
  final Map<int, Map<String, dynamic>?> _statsCache = {};

  Future<void> _openDetail(BuildContext ctx, _GmaxEntry entry) async {
    if (!_statsCache.containsKey(entry.id)) {
      final data = await _api.fetchPokemon(entry.id)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      _statsCache[entry.id] = data;
    }
    final apiData = _statsCache[entry.id];

    int statVal(String name) {
      final raw = apiData?['stats'] as List<dynamic>?;
      if (raw == null) return 0;
      final s = raw.firstWhere((s) => s['stat']['name'] == name, orElse: () => null);
      return (s?['base_stat'] as int?) ?? 0;
    }

    final svc   = PokedexDataService.instance;
    final types = svc.getTypes(entry.id);
    final st    = defaultSpriteNotifier.value;
    const base  = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';

    final pokemon = Pokemon(
      id: entry.id, entryNumber: entry.id, name: entry.name,
      types: types.isNotEmpty ? types : ['normal'],
      baseHp: statVal('hp'), baseAttack: statVal('attack'),
      baseDefense: statVal('defense'), baseSpAttack: statVal('special-attack'),
      baseSpDefense: statVal('special-defense'), baseSpeed: statVal('speed'),
      spriteUrl:           _gmaxSprite(entry.spriteKey, entry.id, st),
      spriteShinyUrl:      '$base/other/official-artwork/shiny/${entry.id}.png',
      spritePixelUrl:      _gmaxSprite(entry.spriteKey, entry.id, 'pixel'),
      spritePixelShinyUrl: '$base/shiny/${entry.id}.png',
      spritePixelFemaleUrl: null,
      spriteHomeUrl:       _gmaxSprite(entry.spriteKey, entry.id, 'artwork'),
      spriteHomeShinyUrl:  '$base/other/home/shiny/${entry.id}.png',
      spriteHomeFemaleUrl: null,
    );

    if (!ctx.mounted) return;
    bool caught = await _storage.isCaught('pokémon_go', entry.id);
    if (!ctx.mounted) return;

    Navigator.push(ctx, PageRouteBuilder(
      pageBuilder: (_, __, ___) => GoDetailScreen(
        pokemon: pokemon, caught: caught,
        onToggleCaught: () async {
          caught = !caught;
          await _storage.setCaught('pokémon_go', entry.id, caught);
        },
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 180),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gigantamax'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${_goGmax.length} Pokémon com Gigantamax disponíveis no GO',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
        Expanded(child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 0.85,
            crossAxisSpacing: 8, mainAxisSpacing: 8,
          ),
          itemCount: _goGmax.length,
          itemBuilder: (ctx, i) => _GmaxTile(
            entry: _goGmax[i], scheme: scheme,
            onTap: () => _openDetail(ctx, _goGmax[i]),
          ),
        )),
      ]),
    );
  }
}

class _GmaxTile extends StatefulWidget {
  final _GmaxEntry  entry;
  final ColorScheme scheme;
  final VoidCallback onTap;
  const _GmaxTile({required this.entry, required this.scheme, required this.onTap});
  @override
  State<_GmaxTile> createState() => _GmaxTileState();
}

class _GmaxTileState extends State<_GmaxTile> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final svc   = PokedexDataService.instance;
    final types = svc.getTypes(widget.entry.id);
    final color = types.isNotEmpty
        ? TypeColors.fromType(ptType(types[0]))
        : widget.scheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _loading ? null : () async {
        setState(() => _loading = true);
        widget.onTap();
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) setState(() => _loading = false);
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3), width: 0.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          _loading
              ? SizedBox(width: 64, height: 64,
                  child: Center(child: SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color))))
              : Image.asset(
                  _gmaxSprite(widget.entry.spriteKey, widget.entry.id, 'artwork'),
                  width: 64, height: 64, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/sprites/artwork/${widget.entry.id}.webp',
                    width: 64, height: 64, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.catching_pokemon,
                        size: 40, color: widget.scheme.onSurfaceVariant),
                  ),
                ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(widget.entry.name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center, maxLines: 1,
              overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

class _GmaxEntry {
  final int    id;
  final String name;
  final String spriteKey;
  const _GmaxEntry({required this.id, required this.name, required this.spriteKey});
}
