import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/services/pokeapi_service.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/theme/type_colors.dart';
import 'package:pokedex_tracker/screens/pokemon_detail_screen.dart';

class PokedexScreen extends StatefulWidget {
  final String pokedexId;
  final String pokedexName;
  final int totalPokemon;
  final List<int> pokemonIds;

  const PokedexScreen({
    super.key,
    required this.pokedexId,
    required this.pokedexName,
    required this.totalPokemon,
    required this.pokemonIds,
  });

  @override
  State<PokedexScreen> createState() => _PokedexScreenState();
}

class _PokedexScreenState extends State<PokedexScreen> {
  final PokeApiService _pokeApi = PokeApiService();
  final StorageService _storage = StorageService();
  final List<Pokemon> _pokemons = [];
  Set<int> _caught = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final caught = await _storage.getCaught(widget.pokedexId);
    final results = await Future.wait(
      widget.pokemonIds.map((id) => _pokeApi.fetchPokemon(id)),
    );
    if (mounted) {
      setState(() {
        _caught = caught;
        _pokemons.addAll(results.whereType<Pokemon>());
        _loading = false;
      });
    }
  }

  Future<void> _toggleCaught(int pokemonId) async {
    setState(() {
      if (_caught.contains(pokemonId)) {
        _caught.remove(pokemonId);
      } else {
        _caught.add(pokemonId);
      }
    });
    await _storage.saveCaught(widget.pokedexId, _caught);
  }

  void _showCaughtFeedback(BuildContext context, String pokemonName, bool nowCaught) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nowCaught ? '$pokemonName capturado!' : '$pokemonName removido',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
                  onLongPress: () {
                    final nowCaught = !caught;
                    _toggleCaught(pokemon.id);
                    _showCaughtFeedback(context, pokemon.name, nowCaught);
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
  final VoidCallback onLongPress;

  const _PokemonCard({
    required this.pokemon,
    required this.caught,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final primaryType = pokemon.types.isNotEmpty ? pokemon.types[0] : 'Normal';
    final typeColor = TypeColors.fromType(_typeInPortuguese(primaryType));

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: typeColor.withOpacity(caught ? 0.2 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: caught
                ? typeColor.withOpacity(0.6)
                : typeColor.withOpacity(0.2),
            width: caught ? 1.5 : 0.5,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: caught ? 1.0 : 0.45,
                  child: pokemon.spriteUrl.isNotEmpty
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
            if (caught)
              Positioned(
                top: 5,
                right: 5,
                child: _PokeballIcon(size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

class _PokeballIcon extends StatelessWidget {
  final double size;
  const _PokeballIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PokeballPainter(),
      ),
    );
  }
}

class _PokeballPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final topPaint = Paint()..color = const Color(0xFFE53935);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159,
      3.14159,
      true,
      topPaint,
    );

    final bottomPaint = Paint()..color = Colors.white;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      3.14159,
      true,
      bottomPaint,
    );

    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = size.width * 0.12;
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      linePaint,
    );

    final outerCirclePaint = Paint()..color = Colors.black;
    canvas.drawCircle(center, radius * 0.32, outerCirclePaint);

    final innerCirclePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.20, innerCirclePaint);

    final borderPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = size.width * 0.08
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(
      center,
      radius - borderPaint.strokeWidth / 2,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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