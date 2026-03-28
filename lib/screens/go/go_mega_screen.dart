import 'package:flutter/material.dart';
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart'
    show ptType, defaultSpriteNotifier;
import 'package:pokedex_tracker/screens/go/go_detail_screen.dart';
import 'package:pokedex_tracker/services/pokeapi_service.dart';
import 'package:pokedex_tracker/services/pokedex_data_service.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/theme/type_colors.dart';

// Megas disponíveis no Pokémon GO (mar/2026)
// Fonte: Bulbapedia - Mega Evolution (GO), Serebii, GO Hub
// spriteKey: chave do bundle local {id}_{FORMA}.webp (gerado por download_form_sprites.py)
const _goMegas = [
  // ── Gen 1 ──────────────────────────────────────────────────────
  _GoMega(id: 3,   name: 'Mega Venusaur',    spriteKey: '3_MEGA'),
  _GoMega(id: 6,   name: 'Mega Charizard X', spriteKey: '6_MEGAX'),
  _GoMega(id: 6,   name: 'Mega Charizard Y', spriteKey: '6_MEGAY'),
  _GoMega(id: 9,   name: 'Mega Blastoise',   spriteKey: '9_MEGA'),
  _GoMega(id: 15,  name: 'Mega Beedrill',    spriteKey: '15_MEGA'),
  _GoMega(id: 18,  name: 'Mega Pidgeot',     spriteKey: '18_MEGA'),
  _GoMega(id: 65,  name: 'Mega Alakazam',    spriteKey: '65_MEGA'),
  _GoMega(id: 80,  name: 'Mega Slowbro',     spriteKey: '80_MEGA'),
  _GoMega(id: 94,  name: 'Mega Gengar',      spriteKey: '94_MEGA'),
  _GoMega(id: 115, name: 'Mega Kangaskhan',  spriteKey: '115_MEGA'),
  _GoMega(id: 127, name: 'Mega Pinsir',      spriteKey: '127_MEGA'),
  _GoMega(id: 130, name: 'Mega Gyarados',    spriteKey: '130_MEGA'),
  _GoMega(id: 142, name: 'Mega Aerodactyl',  spriteKey: '142_MEGA'),
  _GoMega(id: 150, name: 'Mega Mewtwo X',    spriteKey: '150_MEGAX'),
  _GoMega(id: 150, name: 'Mega Mewtwo Y',    spriteKey: '150_MEGAY'),
  // ── Gen 2 ──────────────────────────────────────────────────────
  _GoMega(id: 181, name: 'Mega Ampharos',    spriteKey: '181_MEGA'),
  _GoMega(id: 208, name: 'Mega Steelix',     spriteKey: '208_MEGA'),
  _GoMega(id: 212, name: 'Mega Scizor',      spriteKey: '212_MEGA'),
  _GoMega(id: 214, name: 'Mega Heracross',   spriteKey: '214_MEGA'),
  _GoMega(id: 229, name: 'Mega Houndoom',    spriteKey: '229_MEGA'),
  _GoMega(id: 248, name: 'Mega Tyranitar',   spriteKey: '248_MEGA'),
  // ── Gen 3 ──────────────────────────────────────────────────────
  _GoMega(id: 254, name: 'Mega Sceptile',    spriteKey: '254_MEGA'),
  _GoMega(id: 257, name: 'Mega Blaziken',    spriteKey: '257_MEGA'),
  _GoMega(id: 260, name: 'Mega Swampert',    spriteKey: '260_MEGA'),
  _GoMega(id: 282, name: 'Mega Gardevoir',   spriteKey: '282_MEGA'),
  _GoMega(id: 302, name: 'Mega Sableye',     spriteKey: '302_MEGA'),
  _GoMega(id: 303, name: 'Mega Mawile',      spriteKey: '303_MEGA'),
  _GoMega(id: 306, name: 'Mega Aggron',      spriteKey: '306_MEGA'),
  _GoMega(id: 308, name: 'Mega Medicham',    spriteKey: '308_MEGA'),
  _GoMega(id: 310, name: 'Mega Manectric',   spriteKey: '310_MEGA'),
  _GoMega(id: 319, name: 'Mega Sharpedo',    spriteKey: '319_MEGA'),
  _GoMega(id: 323, name: 'Mega Camerupt',    spriteKey: '323_MEGA'),
  _GoMega(id: 334, name: 'Mega Altaria',     spriteKey: '334_MEGA'),
  _GoMega(id: 354, name: 'Mega Banette',     spriteKey: '354_MEGA'),
  _GoMega(id: 359, name: 'Mega Absol',       spriteKey: '359_MEGA'),
  _GoMega(id: 362, name: 'Mega Glalie',      spriteKey: '362_MEGA'),
  _GoMega(id: 373, name: 'Mega Salamence',   spriteKey: '373_MEGA'),
  _GoMega(id: 376, name: 'Mega Metagross',   spriteKey: '376_MEGA'),
  _GoMega(id: 380, name: 'Mega Latias',      spriteKey: '380_MEGA'),
  _GoMega(id: 381, name: 'Mega Latios',      spriteKey: '381_MEGA'),
  _GoMega(id: 382, name: 'Kyogre Primal',    spriteKey: '382_PRIMAL'),
  _GoMega(id: 383, name: 'Groudon Primal',   spriteKey: '383_PRIMAL'),
  _GoMega(id: 384, name: 'Mega Rayquaza',    spriteKey: '384_MEGA'),
  // ── Gen 4 ──────────────────────────────────────────────────────
  _GoMega(id: 428, name: 'Mega Lopunny',     spriteKey: '428_MEGA'),
  _GoMega(id: 445, name: 'Mega Garchomp',    spriteKey: '445_MEGA'),
  _GoMega(id: 448, name: 'Mega Lucario',     spriteKey: '448_MEGA'),
  _GoMega(id: 460, name: 'Mega Abomasnow',   spriteKey: '460_MEGA'),
  _GoMega(id: 475, name: 'Mega Gallade',     spriteKey: '475_MEGA'),
  // ── Gen 5/6 ────────────────────────────────────────────────────
  _GoMega(id: 531, name: 'Mega Audino',      spriteKey: '531_MEGA'),
  _GoMega(id: 719, name: 'Mega Diancie',     spriteKey: '719_MEGA'),
];

// Helper: monta o asset path para sprites de formas, com fallback para base
String _megaSprite(String spriteKey, int id, String type) {
  final folder = type == 'pixel' ? 'pixel' : type == 'home' ? 'home' : 'artwork';
  return 'assets/sprites/$folder/$spriteKey.webp';
}

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
    final key = '${mega.id}_${mega.spriteKey}';
    if (!_statsCache.containsKey(key)) {
      final data = await _api.fetchPokemon(mega.id)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      _statsCache[key] = data;
    }
    final apiData = _statsCache[key];

    int statVal(String name) {
      final raw = apiData?['stats'] as List<dynamic>?;
      if (raw == null) return 0;
      final s = raw.firstWhere((s) => s['stat']['name'] == name, orElse: () => null);
      return (s?['base_stat'] as int?) ?? 0;
    }

    final svc   = PokedexDataService.instance;
    final types = svc.getTypes(mega.id);
    final st    = defaultSpriteNotifier.value;
    const base  = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';

    final pokemon = Pokemon(
      id: mega.id, entryNumber: mega.id,
      name: mega.name.replaceFirst('Mega ', '').replaceFirst(' Primal', ''),
      types: types.isNotEmpty ? types : ['normal'],
      baseHp: statVal('hp'), baseAttack: statVal('attack'),
      baseDefense: statVal('defense'), baseSpAttack: statVal('special-attack'),
      baseSpDefense: statVal('special-defense'), baseSpeed: statVal('speed'),
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
        title: const Text('Mega Evoluções'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${_goMegas.length} Mega Evoluções disponíveis no Pokémon GO',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
        Expanded(child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 0.85,
            crossAxisSpacing: 8, mainAxisSpacing: 8,
          ),
          itemCount: _goMegas.length,
          itemBuilder: (ctx, i) => _MegaTile(
            mega: _goMegas[i], scheme: scheme,
            onTap: () => _openDetail(ctx, _goMegas[i]),
          ),
        )),
      ]),
    );
  }
}

class _MegaTile extends StatefulWidget {
  final _GoMega mega;
  final ColorScheme scheme;
  final VoidCallback onTap;
  const _MegaTile({required this.mega, required this.scheme, required this.onTap});
  @override
  State<_MegaTile> createState() => _MegaTileState();
}

class _MegaTileState extends State<_MegaTile> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final svc   = PokedexDataService.instance;
    final types = svc.getTypes(widget.mega.id);
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
                  _megaSprite(widget.mega.spriteKey, widget.mega.id, 'artwork'),
                  width: 64, height: 64, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/sprites/artwork/${widget.mega.id}.webp',
                    width: 64, height: 64, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.catching_pokemon,
                        size: 40, color: widget.scheme.onSurfaceVariant),
                  ),
                ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(widget.mega.name,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

class _GoMega {
  final int    id;
  final String name;
  final String spriteKey;
  const _GoMega({required this.id, required this.name, required this.spriteKey});
}
