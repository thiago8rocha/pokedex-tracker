import 'package:flutter/material.dart';
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/services/pokeapi_service.dart';
import 'package:pokedex_tracker/theme/type_colors.dart';
import 'package:pokedex_tracker/screens/pokemon_detail_screen.dart';

class PokedexScreen extends StatefulWidget {
  final String pokedexName;
  final int totalPokemon;
  final List<int> pokemonIds;

  const PokedexScreen({
    super.key,
    required this.pokedexName,
    required this.totalPokemon,
    required this.pokemonIds,
  });

  @override
  State<PokedexScreen> createState() => _PokedexScreenState();
}

class _PokedexScreenState extends State<PokedexScreen> {
  final PokeApiService _service = PokeApiService();
  final List<Pokemon> _pokemons = [];
  final Set<int> _caught = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPokemons();
  }

  Future<void> _loadPokemons() async {
    final results = await Future.wait(
      widget.pokemonIds.map((id) => _service.fetchPokemon(id)),
    );
    if (mounted) {
      setState(() {
        _pokemons.addAll(results.whereType<Pokemon>());
        _loading = false;
      });
    }
  }

  void _toggleCaught(int pokemonId) {
    setState(() {
      if (_caught.contains(pokemonId)) {
        _caught.remove(pokemonId);
      } else {
        _caught.add(pokemonId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pokedexName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_caught.length} / ${widget.totalPokemon} capturados',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: _pokemons.length,
              itemBuilder: (context, index) {
                final pokemon = _pokemons[index];
                final caught = _caught.contains(pokemon.id);
                return _PokemonCard(
                  pokemon: pokemon,
                  caught: caught,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PokemonDetailScreen(
                          pokemon: pokemon,
                          caught: caught,
                          onToggleCaught: () => _toggleCaught(pokemon.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _PokemonCard extends StatelessWidget {
  final Pokemon pokemon;
  final bool caught;
  final VoidCallback onTap;

  const _PokemonCard({
    required this.pokemon,
    required this.caught,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryType = pokemon.types.isNotEmpty ? pokemon.types[0] : 'Normal';
    final typeColor = TypeColors.fromType(_typeInPortuguese(primaryType));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: typeColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: caught
                ? Colors.green.withOpacity(0.6)
                : typeColor.withOpacity(0.3),
            width: caught ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                pokemon.spriteUrl.isNotEmpty
                    ? Image.network(
                        pokemon.spriteUrl,
                        width: 64,
                        height: 64,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.catching_pokemon,
                          size: 40,
                        ),
                      )
                    : const Icon(Icons.catching_pokemon, size: 40),
                if (caught)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '#${pokemon.id.toString().padLeft(3, '0')}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Text(
              pokemon.name,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: pokemon.types
                  .map((t) => _TypeBadge(type: _typeInPortuguese(t)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = TypeColors.fromType(type);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

String _typeInPortuguese(String englishType) {
  const map = {
    'normal': 'Normal',
    'fire': 'Fogo',
    'water': 'Água',
    'electric': 'Elétrico',
    'grass': 'Planta',
    'ice': 'Gelo',
    'fighting': 'Lutador',
    'poison': 'Veneno',
    'ground': 'Terreno',
    'flying': 'Voador',
    'psychic': 'Psíquico',
    'bug': 'Inseto',
    'rock': 'Pedra',
    'ghost': 'Fantasma',
    'dragon': 'Dragão',
    'dark': 'Sombrio',
    'steel': 'Aço',
    'fairy': 'Fada',
  };
  return map[englishType.toLowerCase()] ?? englishType;
}