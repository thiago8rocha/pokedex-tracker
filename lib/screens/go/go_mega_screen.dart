import 'package:flutter/material.dart';
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart'
    show ptType, defaultSpriteNotifier;
import 'package:pokedex_tracker/screens/go/go_detail_screen.dart';
import 'package:pokedex_tracker/services/pokeapi_service.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/theme/type_colors.dart';

// Tipos verificados individualmente para cada mega/primal.
// Fonte: Bulbapedia + PokeAPI (mar/2026).
// Megas que NÃO mudam tipo herdam os tipos da forma base.
const _goMegas = [
  // ── Gen 1 ──────────────────────────────────────────────────────
  _GoMega(id: 3,   name: 'Mega Venusaur',    spriteKey: '3_MEGA',     types: ['grass','poison']),
  _GoMega(id: 6,   name: 'Mega Charizard X', spriteKey: '6_MEGAX',    types: ['fire','dragon']),
  _GoMega(id: 6,   name: 'Mega Charizard Y', spriteKey: '6_MEGAY',    types: ['fire','flying']),
  _GoMega(id: 9,   name: 'Mega Blastoise',   spriteKey: '9_MEGA',     types: ['water']),
  _GoMega(id: 15,  name: 'Mega Beedrill',    spriteKey: '15_MEGA',    types: ['bug','poison']),
  _GoMega(id: 18,  name: 'Mega Pidgeot',     spriteKey: '18_MEGA',    types: ['normal','flying']),
  _GoMega(id: 65,  name: 'Mega Alakazam',    spriteKey: '65_MEGA',    types: ['psychic']),
  _GoMega(id: 80,  name: 'Mega Slowbro',     spriteKey: '80_MEGA',    types: ['water','psychic']),
  _GoMega(id: 94,  name: 'Mega Gengar',      spriteKey: '94_MEGA',    types: ['ghost','poison']),
  _GoMega(id: 115, name: 'Mega Kangaskhan',  spriteKey: '115_MEGA',   types: ['normal']),
  _GoMega(id: 127, name: 'Mega Pinsir',      spriteKey: '127_MEGA',   types: ['bug','flying']),
  _GoMega(id: 130, name: 'Mega Gyarados',    spriteKey: '130_MEGA',   types: ['water','dark']),
  _GoMega(id: 142, name: 'Mega Aerodactyl',  spriteKey: '142_MEGA',   types: ['rock','flying']),
  _GoMega(id: 150, name: 'Mega Mewtwo X',    spriteKey: '150_MEGAX',  types: ['psychic','fighting']),
  _GoMega(id: 150, name: 'Mega Mewtwo Y',    spriteKey: '150_MEGAY',  types: ['psychic']),
  // ── Gen 2 ──────────────────────────────────────────────────────
  _GoMega(id: 181, name: 'Mega Ampharos',    spriteKey: '181_MEGA',   types: ['electric','dragon']),
  _GoMega(id: 208, name: 'Mega Steelix',     spriteKey: '208_MEGA',   types: ['steel','ground']),
  _GoMega(id: 212, name: 'Mega Scizor',      spriteKey: '212_MEGA',   types: ['bug','steel']),
  _GoMega(id: 214, name: 'Mega Heracross',   spriteKey: '214_MEGA',   types: ['bug','fighting']),
  _GoMega(id: 229, name: 'Mega Houndoom',    spriteKey: '229_MEGA',   types: ['dark','fire']),
  _GoMega(id: 248, name: 'Mega Tyranitar',   spriteKey: '248_MEGA',   types: ['rock','dark']),
  // ── Gen 3 ──────────────────────────────────────────────────────
  _GoMega(id: 254, name: 'Mega Sceptile',    spriteKey: '254_MEGA',   types: ['grass','dragon']),
  _GoMega(id: 257, name: 'Mega Blaziken',    spriteKey: '257_MEGA',   types: ['fire','fighting']),
  _GoMega(id: 260, name: 'Mega Swampert',    spriteKey: '260_MEGA',   types: ['water','ground']),
  _GoMega(id: 282, name: 'Mega Gardevoir',   spriteKey: '282_MEGA',   types: ['psychic','fairy']),
  _GoMega(id: 302, name: 'Mega Sableye',     spriteKey: '302_MEGA',   types: ['dark','ghost']),
  _GoMega(id: 303, name: 'Mega Mawile',      spriteKey: '303_MEGA',   types: ['steel','fairy']),
  _GoMega(id: 306, name: 'Mega Aggron',      spriteKey: '306_MEGA',   types: ['steel']),
  _GoMega(id: 308, name: 'Mega Medicham',    spriteKey: '308_MEGA',   types: ['fighting','psychic']),
  _GoMega(id: 310, name: 'Mega Manectric',   spriteKey: '310_MEGA',   types: ['electric']),
  _GoMega(id: 319, name: 'Mega Sharpedo',    spriteKey: '319_MEGA',   types: ['water','dark']),
  _GoMega(id: 323, name: 'Mega Camerupt',    spriteKey: '323_MEGA',   types: ['fire','ground']),
  _GoMega(id: 334, name: 'Mega Altaria',     spriteKey: '334_MEGA',   types: ['dragon','fairy']),
  _GoMega(id: 354, name: 'Mega Banette',     spriteKey: '354_MEGA',   types: ['ghost']),
  _GoMega(id: 359, name: 'Mega Absol',       spriteKey: '359_MEGA',   types: ['dark']),
  _GoMega(id: 362, name: 'Mega Glalie',      spriteKey: '362_MEGA',   types: ['ice']),
  _GoMega(id: 373, name: 'Mega Salamence',   spriteKey: '373_MEGA',   types: ['dragon','flying']),
  _GoMega(id: 376, name: 'Mega Metagross',   spriteKey: '376_MEGA',   types: ['steel','psychic']),
  _GoMega(id: 380, name: 'Mega Latias',      spriteKey: '380_MEGA',   types: ['dragon','psychic']),
  _GoMega(id: 381, name: 'Mega Latios',      spriteKey: '381_MEGA',   types: ['dragon','psychic']),
  _GoMega(id: 382, name: 'Kyogre Primal',    spriteKey: '382_PRIMAL', types: ['water']),
  _GoMega(id: 383, name: 'Groudon Primal',   spriteKey: '383_PRIMAL', types: ['ground','fire']),
  _GoMega(id: 384, name: 'Mega Rayquaza',    spriteKey: '384_MEGA',   types: ['dragon','flying']),
  // ── Gen 4 ──────────────────────────────────────────────────────
  _GoMega(id: 428, name: 'Mega Lopunny',     spriteKey: '428_MEGA',   types: ['normal','fighting']),
  _GoMega(id: 445, name: 'Mega Garchomp',    spriteKey: '445_MEGA',   types: ['dragon','ground']),
  _GoMega(id: 448, name: 'Mega Lucario',     spriteKey: '448_MEGA',   types: ['fighting','steel']),
  _GoMega(id: 460, name: 'Mega Abomasnow',   spriteKey: '460_MEGA',   types: ['grass','ice']),
  _GoMega(id: 475, name: 'Mega Gallade',     spriteKey: '475_MEGA',   types: ['psychic','fighting']),
  // ── Gen 5/6 ────────────────────────────────────────────────────
  _GoMega(id: 531, name: 'Mega Audino',      spriteKey: '531_MEGA',   types: ['normal','fairy']),
  _GoMega(id: 719, name: 'Mega Diancie',     spriteKey: '719_MEGA',   types: ['rock','fairy']),
];

String _megaSprite(String key, int id, String type) {
  final folder = type == 'pixel' ? 'pixel' : 'artwork';
  return 'assets/sprites/$folder/$key.webp';
}

// ─── Widget de badge de tipo compacto (igual ao das raids) ────────
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

// ─── Screen ───────────────────────────────────────────────────────
class GoMegaScreen extends StatefulWidget {
  const GoMegaScreen({super.key});
  @override
  State<GoMegaScreen> createState() => _GoMegaScreenState();
}

class _GoMegaScreenState extends State<GoMegaScreen> {
  final _api     = PokeApiService();
  final _storage = StorageService();
  final Map<String, Map<String, dynamic>?> _statsCache = {};

  Future<void> _openDetail(BuildContext ctx, _GoMega mega) async {
    if (!_statsCache.containsKey(mega.spriteKey)) {
      final data = await _api.fetchPokemon(mega.id)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      _statsCache[mega.spriteKey] = data;
    }
    final d = _statsCache[mega.spriteKey];
    int sv(String n) {
      final raw = d?['stats'] as List?;
      if (raw == null) return 0;
      final s = raw.firstWhere((s) => s['stat']['name'] == n, orElse: () => null);
      return (s?['base_stat'] as int?) ?? 0;
    }
    final st = defaultSpriteNotifier.value;
    const base = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';
    final pokemon = Pokemon(
      id: mega.id, entryNumber: mega.id, name: mega.name,
      types: mega.types,
      baseHp: sv('hp'), baseAttack: sv('attack'), baseDefense: sv('defense'),
      baseSpAttack: sv('special-attack'), baseSpDefense: sv('special-defense'),
      baseSpeed: sv('speed'),
      spriteUrl:           _megaSprite(mega.spriteKey, mega.id, st),
      spriteShinyUrl:      '$base/other/official-artwork/shiny/${mega.id}.png',
      spritePixelUrl:      _megaSprite(mega.spriteKey, mega.id, 'pixel'),
      spritePixelShinyUrl: '$base/shiny/${mega.id}.png',
      spritePixelFemaleUrl: null,
      spriteHomeUrl:       _megaSprite(mega.spriteKey, mega.id, 'artwork'),
      spriteHomeShinyUrl:  '$base/other/home/shiny/${mega.id}.png',
      spriteHomeFemaleUrl: null,
    );
    if (!ctx.mounted) return;
    bool caught = await _storage.isCaught('pokémon_go', mega.id);
    if (!ctx.mounted) return;
    Navigator.push(ctx, PageRouteBuilder(
      pageBuilder: (_, __, ___) => GoDetailScreen(
        pokemon: pokemon, caught: caught,
        onToggleCaught: () async {
          caught = !caught;
          await _storage.setCaught('pokémon_go', mega.id, caught);
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
      appBar: AppBar(title: const Text('Mega Evoluções'),
          scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('${_goMegas.length} Mega Evoluções disponíveis no Pokémon GO',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))),
        Expanded(child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, childAspectRatio: 0.78,
              crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: _goMegas.length,
          itemBuilder: (ctx, i) => _MegaTile(
              mega: _goMegas[i], scheme: scheme,
              onTap: () => _openDetail(ctx, _goMegas[i])),
        )),
      ]),
    );
  }
}

class _MegaTile extends StatefulWidget {
  final _GoMega mega; final ColorScheme scheme; final VoidCallback onTap;
  const _MegaTile({required this.mega, required this.scheme, required this.onTap});
  @override State<_MegaTile> createState() => _MegaTileState();
}

class _MegaTileState extends State<_MegaTile> {
  bool _tapping = false;

  @override
  Widget build(BuildContext context) {
    final types  = widget.mega.types;
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
          Image.asset(_megaSprite(widget.mega.spriteKey, widget.mega.id, 'artwork'),
            width: 64, height: 64, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/sprites/artwork/${widget.mega.id}.webp',
              width: 64, height: 64, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(Icons.catching_pokemon,
                  size: 40, color: widget.scheme.onSurfaceVariant))),
          const SizedBox(height: 4),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(widget.mega.name,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center, maxLines: 2,
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

class _GoMega {
  final int id; final String name; final String spriteKey;
  final List<String> types;
  const _GoMega({required this.id, required this.name,
      required this.spriteKey, required this.types});
}
