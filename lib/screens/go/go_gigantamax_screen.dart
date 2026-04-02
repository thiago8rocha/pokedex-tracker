import 'package:flutter/material.dart';
import 'package:dexcurator/models/pokemon.dart';
import 'package:dexcurator/screens/detail/detail_shared.dart'
    show ptType, defaultSpriteNotifier;
import 'package:dexcurator/screens/go/go_detail_screen.dart';
import 'package:dexcurator/services/pokeapi_service.dart';
import 'package:dexcurator/services/pokedex_data_service.dart';
import 'package:dexcurator/services/storage_service.dart';
import 'package:dexcurator/theme/type_colors.dart';

// Gigantamax confirmados no GO (mar/2026). Tipos = forma base (Gmax não altera tipo).
const _goGmax = [
  _GmaxEntry(id: 3,   name: 'Venusaur',   spriteKey: '3_GMAX',   types: ['grass','poison']),
  _GmaxEntry(id: 6,   name: 'Charizard',  spriteKey: '6_GMAX',   types: ['fire','flying']),
  _GmaxEntry(id: 9,   name: 'Blastoise',  spriteKey: '9_GMAX',   types: ['water']),
  _GmaxEntry(id: 12,  name: 'Butterfree', spriteKey: '12_GMAX',  types: ['bug','flying']),
  _GmaxEntry(id: 25,  name: 'Pikachu',    spriteKey: '25_GMAX',  types: ['electric']),
  _GmaxEntry(id: 52,  name: 'Meowth',     spriteKey: '52_GMAX',  types: ['normal']),
  _GmaxEntry(id: 68,  name: 'Machamp',    spriteKey: '68_GMAX',  types: ['fighting']),
  _GmaxEntry(id: 94,  name: 'Gengar',     spriteKey: '94_GMAX',  types: ['ghost','poison']),
  _GmaxEntry(id: 99,  name: 'Kingler',    spriteKey: '99_GMAX',  types: ['water']),
  _GmaxEntry(id: 131, name: 'Lapras',     spriteKey: '131_GMAX', types: ['water','ice']),
  _GmaxEntry(id: 143, name: 'Snorlax',    spriteKey: '143_GMAX', types: ['normal']),
  _GmaxEntry(id: 569, name: 'Garbodor',   spriteKey: '569_GMAX', types: ['poison']),
  _GmaxEntry(id: 809, name: 'Melmetal',   spriteKey: '809_GMAX', types: ['steel']),
  _GmaxEntry(id: 812, name: 'Rillaboom',  spriteKey: '812_GMAX', types: ['grass']),
  _GmaxEntry(id: 815, name: 'Cinderace',  spriteKey: '815_GMAX', types: ['fire']),
  _GmaxEntry(id: 818, name: 'Inteleon',   spriteKey: '818_GMAX', types: ['water']),
];

String _gmaxSprite(String key, int id, String type) {
  final folder = type == 'pixel' ? 'pixel' : type == 'home' ? 'home' : 'artwork';
  return 'assets/sprites/$folder/$key.webp';
}

class _TypeChip extends StatelessWidget {
  final String type;
  const _TypeChip(this.type);
  static const _names = {
    'normal':'Normal','fire':'Fogo','water':'Água','electric':'Elétrico',
    'grass':'Planta','ice':'Gelo','fighting':'Lutador','poison':'Veneno',
    'ground':'Terreno','flying':'Voador','psychic':'Psíquico','bug':'Inseto',
    'rock':'Pedra','ghost':'Fantasma','dragon':'Dragão','dark':'Sombrio',
    'steel':'Aço','fairy':'Fada',
  };
  @override
  Widget build(BuildContext context) {
    final color = TypeColors.fromType(ptType(type));
    return Container(
      height: 16, constraints: const BoxConstraints(minWidth: 60),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      child: Row(mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset('assets/types/$type.png', width: 9, height: 9,
              errorBuilder: (_, __, ___) => const SizedBox(width: 9)),
          const SizedBox(width: 3),
          Text(_names[type] ?? type, style: const TextStyle(
              fontSize: 8, fontWeight: FontWeight.w700,
              color: Colors.white, height: 1.0)),
        ]),
    );
  }
}

class GoGigantamaxScreen extends StatefulWidget {
  const GoGigantamaxScreen({super.key});
  @override State<GoGigantamaxScreen> createState() => _GoGigantamaxScreenState();
}

class _GoGigantamaxScreenState extends State<GoGigantamaxScreen> {
  final _api     = PokeApiService();
  final _storage = StorageService();
  final Map<String, Map<String, dynamic>?> _statsCache = {};

  Future<void> _openDetail(BuildContext ctx, _GmaxEntry entry) async {
    if (!_statsCache.containsKey(entry.spriteKey)) {
      final data = await _api.fetchPokemon(entry.id)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      _statsCache[entry.spriteKey] = data;
    }
    final d = _statsCache[entry.spriteKey];
    int sv(String n) {
      final raw = d?['stats'] as List?;
      if (raw == null) return 0;
      final s = raw.firstWhere((s) => s['stat']['name'] == n, orElse: () => null);
      return (s?['base_stat'] as int?) ?? 0;
    }
    final svc  = PokedexDataService.instance;
    final st   = defaultSpriteNotifier.value;
    const base = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';

    // Abre o Pokemon BASE direto na aba Formas
    final baseName  = svc.getName(entry.id);
    final baseTypes = svc.getTypes(entry.id);
    final pokemon = Pokemon(
      id: entry.id, entryNumber: entry.id, name: baseName,
      types: baseTypes.isNotEmpty ? baseTypes : ['normal'],
      baseHp: sv('hp'), baseAttack: sv('attack'), baseDefense: sv('defense'),
      baseSpAttack: sv('special-attack'), baseSpDefense: sv('special-defense'),
      baseSpeed: sv('speed'),
      spriteUrl:           'assets/sprites/${st == 'pixel' ? 'pixel' : st == 'home' ? 'home' : 'artwork'}/${entry.id}.webp',
      spriteShinyUrl:      '$base/other/official-artwork/shiny/${entry.id}.png',
      spritePixelUrl:      'assets/sprites/pixel/${entry.id}.webp',
      spritePixelShinyUrl: '$base/shiny/${entry.id}.png',
      spritePixelFemaleUrl: null,
      spriteHomeUrl:       'assets/sprites/home/${entry.id}.webp',
      spriteHomeShinyUrl:  '$base/other/home/shiny/${entry.id}.png',
      spriteHomeFemaleUrl: null,
    );

    if (!ctx.mounted) return;
    bool caught = await _storage.isCaught('pokémon_go', entry.id);
    if (!ctx.mounted) return;
    Navigator.push(ctx, PageRouteBuilder(
      pageBuilder: (_, __, ___) => GoDetailScreen(
        pokemon: pokemon, caught: caught,
        initialTab: 3,
        onToggleCaught: () async {
          caught = !caught;
          await _storage.setCaught('pokémon_go', entry.id, caught);
        },
      ),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 180),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Gigantamax'),
          scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('${_goGmax.length} Pokémon com Gigantamax disponíveis no GO',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))),
        Expanded(child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, childAspectRatio: 0.75,
              crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: _goGmax.length,
          itemBuilder: (ctx, i) => _GmaxTile(
              entry: _goGmax[i], scheme: scheme,
              onTap: () => _openDetail(ctx, _goGmax[i])),
        )),
      ]),
    );
  }
}

class _GmaxTile extends StatefulWidget {
  final _GmaxEntry entry; final ColorScheme scheme; final VoidCallback onTap;
  const _GmaxTile({required this.entry, required this.scheme, required this.onTap});
  @override State<_GmaxTile> createState() => _GmaxTileState();
}

class _GmaxTileState extends State<_GmaxTile> {
  bool _tapping = false;
  @override
  Widget build(BuildContext context) {
    final types  = widget.entry.types;
    final color1 = TypeColors.fromType(ptType(types[0]));
    final color2 = types.length > 1 ? TypeColors.fromType(ptType(types[1])) : color1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgOp   = isDark ? 0.15 : 0.09;

    return GestureDetector(
      onTap: _tapping ? null : () async {
        setState(() => _tapping = true);
        widget.onTap();
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) setState(() => _tapping = false);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: types.length > 1
                ? [color1.withOpacity(bgOp), color2.withOpacity(bgOp)]
                : [color1.withOpacity(bgOp), color1.withOpacity(bgOp * 0.5)]),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color1.withOpacity(0.25), width: 0.5)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Image.asset(_gmaxSprite(widget.entry.spriteKey, widget.entry.id, 'artwork'),
            width: 64, height: 64, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/sprites/artwork/${widget.entry.id}.webp',
              width: 64, height: 64, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(Icons.catching_pokemon,
                  size: 40, color: widget.scheme.onSurfaceVariant))),
          const SizedBox(height: 4),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(widget.entry.name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center, maxLines: 1,
              overflow: TextOverflow.ellipsis)),
          const SizedBox(height: 4),
          Column(mainAxisSize: MainAxisSize.min,
            children: types.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _TypeChip(t))).toList()),
        ]),
      ),
    );
  }
}

class _GmaxEntry {
  final int id; final String name; final String spriteKey;
  final List<String> types;
  const _GmaxEntry({required this.id, required this.name,
      required this.spriteKey, required this.types});
}
