import 'package:flutter/material.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart'
    show PokeballLoader;
import 'package:pokedex_tracker/data/pokopia_habitat_data.dart';
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/services/pokeapi_service.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/screens/pokopia/pokopia_detail_screen.dart';
import 'package:pokedex_tracker/screens/pokopia/pokopia_habitats_screen.dart';

class PokopiaEventHabitatDetailScreen extends StatefulWidget {
  final PokopiaEventHabitat habitat;

  /// Pokémon de origem — se preenchido, o botão de voltar vai para ele.
  final Pokemon? originPokemon;
  final bool? originCaught;
  final VoidCallback? onToggleOrigin;

  const PokopiaEventHabitatDetailScreen({
    super.key,
    required this.habitat,
    this.originPokemon,
    this.originCaught,
    this.onToggleOrigin,
  });

  @override
  State<PokopiaEventHabitatDetailScreen> createState() =>
      _PokopiaEventHabitatDetailScreenState();
}

class _PokopiaEventHabitatDetailScreenState
    extends State<PokopiaEventHabitatDetailScreen> {
  final PokeApiService _api = PokeApiService();
  final StorageService _storage = StorageService();

  final Map<int, Pokemon?> _pokemonCache = {};
  final Map<int, bool> _caughtMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPokemon();
  }

  Future<void> _loadPokemon() async {
    final ids = widget.habitat.pokemon.map((e) => e.speciesId).toList();
    if (ids.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final results = await _api.fetchPokemonBatch(ids);
    // Evento usa pokopia_event como pokedexId
    final caught = await _storage.getCaughtMap('pokopia_event', ids);

    if (!mounted) return;
    setState(() {
      for (final d in results) {
        final id = d['id'] as int;
        _pokemonCache[id] = _buildPokemon(d);
      }
      _caughtMap.addAll(caught);
      _loading = false;
    });
  }

  Pokemon _buildPokemon(Map<String, dynamic> d) {
    final types = (d['types'] as List)
        .map((t) => t['type']['name'] as String)
        .toList();
    final stats = {
      for (final s in d['stats'] as List)
        s['stat']['name'] as String: s['base_stat'] as int
    };
    return Pokemon(
      id: d['id'] as int,
      entryNumber: d['id'] as int,
      name: d['name'] as String,
      types: types,
      baseHp: stats['hp'] ?? 0,
      baseAttack: stats['attack'] ?? 0,
      baseDefense: stats['defense'] ?? 0,
      baseSpAttack: stats['special-attack'] ?? 0,
      baseSpDefense: stats['special-defense'] ?? 0,
      baseSpeed: stats['speed'] ?? 0,
      spriteUrl: d['sprites']?['other']?['official-artwork']
              ?['front_default'] as String? ??
          '',
    );
  }

  Future<void> _toggleCaught(int speciesId) async {
    final current = _caughtMap[speciesId] ?? false;
    final newVal = !current;
    setState(() => _caughtMap[speciesId] = newVal);
    await _storage.setCaught('pokopia_event', speciesId, newVal);
  }

  void _openPokemonDetail(PokopiaHabitatEntry entry) {
    final pokemon = _pokemonCache[entry.speciesId];
    if (pokemon == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PokopiaDetailScreen(
          pokemon: pokemon,
          caught: _caughtMap[entry.speciesId] ?? false,
          onToggleCaught: () => _toggleCaught(entry.speciesId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final habitat = widget.habitat;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar com imagem ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (widget.originPokemon != null) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PokopiaDetailScreen(
                        pokemon: widget.originPokemon!,
                        caught: widget.originCaught ?? false,
                        onToggleCaught: widget.onToggleOrigin ?? () {},
                      ),
                    ),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PokopiaHabitatsScreen(),
                    ),
                  );
                }
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.zero,
              title: null,
              background: _EventHabitatImage(habitat: habitat),
            ),
          ),

          // ── Nome e conteúdo ────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Badge de evento
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    habitat.eventName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  habitat.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (habitat.flavorText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    habitat.flavorText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Itens necessários
                _SectionTitle(text: 'ITENS NECESSÁRIOS'),
                const SizedBox(height: 8),
                _ItemsList(items: habitat.items),
                const SizedBox(height: 20),

                // Pokémon possíveis
                _SectionTitle(text: 'POKÉMON POSSÍVEIS'),
                const SizedBox(height: 8),
                if (_loading)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(24),
                    child: PokeballLoader(),
                  ))
                else if (habitat.pokemon.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Dados ainda não disponíveis.',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  )
                else
                  ...habitat.pokemon.map((entry) => _PokemonEntry(
                        entry: entry,
                        pokemon: _pokemonCache[entry.speciesId],
                        caught: _caughtMap[entry.speciesId] ?? false,
                        onTap: () => _openPokemonDetail(entry),
                        onToggle: () => _toggleCaught(entry.speciesId),
                      )),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── WIDGETS ──────────────────────────────────────────────────────────────────

class _EventHabitatImage extends StatelessWidget {
  final PokopiaEventHabitat habitat;
  const _EventHabitatImage({required this.habitat});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0x1A607D8B)),
        Positioned.fill(
          child: Image.asset(
            habitat.imageAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.landscape_outlined,
                  size: 48, color: Color(0x7F607D8B)),
            ),
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0, height: 80,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xCC000000), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _ItemsList extends StatelessWidget {
  final List<String> items;
  const _ItemsList({required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant, width: 1),
                ),
                child: Text(item,
                    style: TextStyle(fontSize: 12, color: scheme.onSurface)),
              ))
          .toList(),
    );
  }
}

class _PokemonEntry extends StatelessWidget {
  final PokopiaHabitatEntry entry;
  final Pokemon? pokemon;
  final bool caught;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _PokemonEntry({
    required this.entry,
    required this.pokemon,
    required this.caught,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: Row(children: [
          SizedBox(
            width: 52,
            height: 52,
            child: pokemon?.spriteUrl != null && pokemon!.spriteUrl.isNotEmpty
                ? Image.network(
                    pokemon!.spriteUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.catching_pokemon,
                      size: 32,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : Icon(Icons.catching_pokemon,
                    size: 32, color: scheme.outlineVariant),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(entry.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    _RarityBadge(rarity: entry.rarity),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    if (entry.time != null) ...[
                      _SmallChip(
                          icon: Icons.schedule_outlined, label: entry.time!),
                      const SizedBox(width: 5),
                    ],
                    if (entry.weather != null)
                      _SmallChip(
                          icon: Icons.wb_cloudy_outlined, label: entry.weather!),
                  ]),
                ]),
          ),
          Column(children: [
            GestureDetector(
              onTap: onToggle,
              child: Icon(
                caught ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 22,
                color: caught ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            const SizedBox(height: 4),
            Icon(Icons.chevron_right, size: 16, color: scheme.outlineVariant),
          ]),
        ]),
      ),
    );
  }
}

class _RarityBadge extends StatelessWidget {
  final String rarity;
  const _RarityBadge({required this.rarity});

  Color _color() {
    switch (rarity) {
      case 'Comum':      return const Color(0xFF4CAF50);
      case 'Incomum':    return const Color(0xFF2196F3);
      case 'Raro':       return const Color(0xFF9C27B0);
      case 'Muito Raro': return const Color(0xFFFF9800);
      default:           return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(rarity,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: c)),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SmallChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: c),
      const SizedBox(width: 2),
      Text(label, style: TextStyle(fontSize: 10, color: c)),
    ]);
  }
}
