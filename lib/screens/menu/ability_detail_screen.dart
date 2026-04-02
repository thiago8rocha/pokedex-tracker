import 'package:flutter/material.dart';
import 'package:dexcurator/models/pokemon.dart';
import 'package:dexcurator/screens/detail/detail_shared.dart' show neutralBg;
import 'package:dexcurator/screens/detail/mainline_detail_screen.dart';
import 'package:dexcurator/screens/detail/nacional_detail_screen.dart';
import 'package:dexcurator/services/pokedex_data_service.dart';
import 'package:dexcurator/services/storage_service.dart';
import 'package:dexcurator/translations.dart';
import 'package:dexcurator/screens/menu/abilities_list_screen.dart' show AbilityEntry;

class AbilityDetailScreen extends StatefulWidget {
  final AbilityEntry entry;
  const AbilityDetailScreen({super.key, required this.entry});
  @override State<AbilityDetailScreen> createState() => _AbilityDetailScreenState();
}

class _AbilityDetailScreenState extends State<AbilityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _openPokemon(int id) async {
    final svc  = PokedexDataService.instance;
    final poke = Pokemon(
      id: id,
      entryNumber: id, name: svc.getName(id), types: svc.getTypes(id),
      baseHp: 0, baseAttack: 0, baseDefense: 0,
      baseSpAttack: 0, baseSpDefense: 0, baseSpeed: 0,
      spriteUrl:      'assets/sprites/artwork/$id.webp',
      spritePixelUrl: 'assets/sprites/pixel/$id.webp',
      spriteHomeUrl:  'assets/sprites/home/$id.webp',
    );
    final lastDex  = await StorageService().getLastPokedexId() ?? 'nacional';
    final isCaught = await StorageService().isCaught(lastDex, id);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => lastDex == 'nacional'
          ? NacionalDetailScreen(
              pokemon: poke, caught: isCaught,
              pokedexId: 'nacional',
              onToggleCaught: () async {
                final cur = await StorageService().isCaught(lastDex, id);
                await StorageService().setCaught(lastDex, id, !cur);
              })
          : SwitchDetailScreen(
              pokemon: poke, caught: isCaught, pokedexId: lastDex,
              onToggleCaught: () async {
                final cur = await StorageService().isCaught(lastDex, id);
                await StorageService().setCaught(lastDex, id, !cur);
              }),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme    = Theme.of(context).colorScheme;
    final e         = widget.entry;
    final namePt    = translateAbility(e.nameEn);

    return Scaffold(
      appBar: AppBar(
        title: Text(namePt),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Efeito curto (effect_short ou desc como fallback)
            if (e.description.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: neutralBg(context),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(e.description, style: TextStyle(
                    fontSize: 13, color: scheme.onSurface, height: 1.5)),
              ),

            // Flavor text
            if (e.flavor.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: neutralBg(context),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Descrição no jogo', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant, letterSpacing: 0.6)),
                  const SizedBox(height: 6),
                  Text(e.flavor, style: TextStyle(fontSize: 13,
                      color: scheme.onSurface, height: 1.5,
                      fontStyle: FontStyle.italic)),
                ]),
              ),
            ],

            // Efeito detalhado
            if (e.effectLong.isNotEmpty && e.effectLong != e.description) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: neutralBg(context),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Efeito detalhado', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant, letterSpacing: 0.6)),
                  const SizedBox(height: 6),
                  Text(e.effectLong, style: TextStyle(fontSize: 13,
                      color: scheme.onSurface, height: 1.5)),
                ]),
              ),
            ],

            const SizedBox(height: 12),
          ]),
        ),

        TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'Principal'), Tab(text: 'Oculta')],
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
        ),

        Expanded(child: TabBarView(controller: _tab, children: [
          _PokemonList(ids: e.mainIds,   onTap: _openPokemon),
          _PokemonList(ids: e.hiddenIds, onTap: _openPokemon),
        ])),
      ]),
    );
  }
}

class _PokemonList extends StatelessWidget {
  final List<int> ids; final Future<void> Function(int) onTap;
  const _PokemonList({required this.ids, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (ids.isEmpty) return Center(child: Text(
        'Nenhum Pokémon com esta habilidade.',
        style: TextStyle(color: scheme.onSurfaceVariant)));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: ids.length,
      itemBuilder: (ctx, i) => _PokemonTile(id: ids[i], scheme: scheme, onTap: onTap),
    );
  }
}

class _PokemonTile extends StatelessWidget {
  final int id; final ColorScheme scheme; final Future<void> Function(int) onTap;
  const _PokemonTile({required this.id, required this.scheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = PokedexDataService.instance.getName(id);
    return GestureDetector(
      onTap: () => onTap(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: scheme.outlineVariant, width: 0.5)),
        child: Row(children: [
          Image.asset('assets/sprites/artwork/$id.webp',
              width: 40, height: 40, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => SizedBox(width: 40, height: 40,
                  child: Icon(Icons.catching_pokemon, size: 22,
                      color: scheme.onSurfaceVariant.withOpacity(0.3)))),
          const SizedBox(width: 10),
          Text('#${id.toString().padLeft(3, '0')}', style: TextStyle(
              fontSize: 11, color: scheme.onSurfaceVariant.withOpacity(0.6))),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500))),
          Icon(Icons.chevron_right, size: 14,
              color: scheme.onSurfaceVariant.withOpacity(0.4)),
        ]),
      ),
    );
  }
}
