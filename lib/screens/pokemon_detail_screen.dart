import 'package:flutter/material.dart';
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/theme/type_colors.dart';

class PokemonDetailScreen extends StatelessWidget {
  final Pokemon pokemon;
  final bool caught;
  final VoidCallback onToggleCaught;

  const PokemonDetailScreen({
    super.key,
    required this.pokemon,
    required this.caught,
    required this.onToggleCaught,
  });

  @override
  Widget build(BuildContext context) {
    final primaryType = pokemon.types.isNotEmpty ? pokemon.types[0] : 'normal';
    final typeColor = TypeColors.fromType(_ptType(primaryType));
    final secondaryColor = pokemon.types.length > 1
        ? TypeColors.fromType(_ptType(pokemon.types[1]))
        : typeColor;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildHeader(context, typeColor, secondaryColor),
          SliverToBoxAdapter(
            child: _buildTabs(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color typeColor,
    Color secondaryColor,
  ) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                typeColor.withOpacity(0.8),
                secondaryColor.withOpacity(0.6),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Row(
                  children: [
                    const SizedBox(width: 16),
                    Hero(
                      tag: 'pokemon-${pokemon.id}',
                      child: pokemon.spriteUrl.isNotEmpty
                          ? Image.network(
                              pokemon.spriteUrl,
                              width: 100,
                              height: 100,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.catching_pokemon,
                                size: 80,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.catching_pokemon,
                              size: 80,
                              color: Colors.white,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${pokemon.id.toString().padLeft(3, '0')}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            pokemon.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: pokemon.types
                                .map(
                                  (t) => Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _ptType(t),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onToggleCaught,
                      icon: Icon(
                        caught
                            ? Icons.catching_pokemon
                            : Icons.catching_pokemon_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'Status'),
              Tab(text: 'Info'),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(
            height: 500,
            child: TabBarView(
              children: [
                _StatsTab(pokemon: pokemon),
                _InfoTab(pokemon: pokemon),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  final Pokemon pokemon;
  const _StatsTab({required this.pokemon});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'STATUS BASE'),
          const SizedBox(height: 10),
          _StatBar(label: 'HP', value: pokemon.baseHp, color: Colors.green),
          _StatBar(
            label: 'Ataque',
            value: pokemon.baseAttack,
            color: Colors.red,
          ),
          _StatBar(
            label: 'Defesa',
            value: pokemon.baseDefense,
            color: Colors.blue,
          ),
          _StatBar(
            label: 'At. Especial',
            value: pokemon.baseSpAttack,
            color: Colors.purple,
          ),
          _StatBar(
            label: 'Def. Especial',
            value: pokemon.baseSpDefense,
            color: Colors.blueAccent,
          ),
          _StatBar(
            label: 'Velocidade',
            value: pokemon.baseSpeed,
            color: Colors.amber,
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total: ${pokemon.totalStats}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 255,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  final Pokemon pokemon;
  const _InfoTab({required this.pokemon});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'TIPOS'),
          const SizedBox(height: 8),
          Row(
            children: pokemon.types
                .map(
                  (t) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: TypeColors.fromType(_ptType(t)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _ptType(t),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          _sectionTitle(context, 'FRAQUEZAS'),
          const SizedBox(height: 8),
          _WeaknessSection(types: pokemon.types),
        ],
      ),
    );
  }
}

class _WeaknessSection extends StatelessWidget {
  final List<String> types;
  const _WeaknessSection({required this.types});

  @override
  Widget build(BuildContext context) {
    final weaknesses = _calculateWeaknesses(types);

    if (weaknesses.isEmpty) {
      return Text(
        'Nenhuma fraqueza',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: weaknesses.entries.map((e) {
        final color = TypeColors.fromType(e.key);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.4), width: 0.5),
          ),
          child: Text(
            '${e.key} ×${e.value % 1 == 0 ? e.value.toInt() : e.value}',
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }
}

Widget _sectionTitle(BuildContext context, String title) {
  return Text(
    title,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
  );
}

String _ptType(String englishType) {
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

Map<String, double> _calculateWeaknesses(List<String> types) {
  const typeChart = {
    'normal': {'fighting': 2.0, 'ghost': 0.0},
    'fire': {
      'water': 2.0,
      'rock': 2.0,
      'ground': 2.0,
      'fire': 0.5,
      'grass': 0.5,
      'ice': 0.5,
      'bug': 0.5,
      'steel': 0.5,
      'fairy': 0.5,
    },
    'water': {
      'electric': 2.0,
      'grass': 2.0,
      'fire': 0.5,
      'water': 0.5,
      'ice': 0.5,
      'steel': 0.5,
    },
    'electric': {
      'ground': 2.0,
      'electric': 0.5,
      'flying': 0.5,
      'steel': 0.5,
    },
    'grass': {
      'fire': 2.0,
      'ice': 2.0,
      'poison': 2.0,
      'flying': 2.0,
      'bug': 2.0,
      'water': 0.5,
      'electric': 0.5,
      'grass': 0.5,
      'ground': 0.5,
    },
    'ice': {
      'fire': 2.0,
      'fighting': 2.0,
      'rock': 2.0,
      'steel': 2.0,
      'ice': 0.5,
    },
    'fighting': {
      'flying': 2.0,
      'psychic': 2.0,
      'fairy': 2.0,
      'rock': 0.5,
      'bug': 0.5,
      'dark': 0.5,
    },
    'poison': {
      'ground': 2.0,
      'psychic': 2.0,
      'fighting': 0.5,
      'poison': 0.5,
      'bug': 0.5,
      'grass': 0.5,
      'fairy': 0.5,
    },
    'ground': {
      'water': 2.0,
      'grass': 2.0,
      'ice': 2.0,
      'electric': 0.0,
      'poison': 0.5,
      'rock': 0.5,
    },
    'flying': {
      'electric': 2.0,
      'ice': 2.0,
      'rock': 2.0,
      'ground': 0.0,
      'fighting': 0.5,
      'bug': 0.5,
      'grass': 0.5,
    },
    'psychic': {
      'bug': 2.0,
      'ghost': 2.0,
      'dark': 2.0,
      'fighting': 0.5,
      'psychic': 0.5,
    },
    'bug': {
      'fire': 2.0,
      'flying': 2.0,
      'rock': 2.0,
      'fighting': 0.5,
      'ground': 0.5,
      'grass': 0.5,
    },
    'rock': {
      'water': 2.0,
      'grass': 2.0,
      'fighting': 2.0,
      'ground': 2.0,
      'steel': 2.0,
      'normal': 0.5,
      'fire': 0.5,
      'poison': 0.5,
      'flying': 0.5,
    },
    'ghost': {
      'ghost': 2.0,
      'dark': 2.0,
      'normal': 0.0,
      'fighting': 0.0,
      'poison': 0.5,
      'bug': 0.5,
    },
    'dragon': {
      'ice': 2.0,
      'dragon': 2.0,
      'fairy': 2.0,
      'fire': 0.5,
      'water': 0.5,
      'electric': 0.5,
      'grass': 0.5,
    },
    'dark': {
      'fighting': 2.0,
      'bug': 2.0,
      'fairy': 2.0,
      'ghost': 0.5,
      'dark': 0.5,
      'psychic': 0.0,
    },
    'steel': {
      'fire': 2.0,
      'fighting': 2.0,
      'ground': 2.0,
      'normal': 0.5,
      'grass': 0.5,
      'ice': 0.5,
      'flying': 0.5,
      'psychic': 0.5,
      'bug': 0.5,
      'rock': 0.5,
      'dragon': 0.5,
      'steel': 0.5,
      'fairy': 0.5,
      'poison': 0.0,
    },
    'fairy': {
      'poison': 2.0,
      'steel': 2.0,
      'fighting': 0.5,
      'bug': 0.5,
      'dark': 0.5,
      'dragon': 0.0,
    },
  };

  Map<String, double> multipliers = {};

  for (final type in types) {
    final chart = typeChart[type.toLowerCase()] ?? {};
    for (final entry in chart.entries) {
      final ptType = _ptType(entry.key);
      multipliers[ptType] = (multipliers[ptType] ?? 1.0) * entry.value;
    }
  }

  return Map.fromEntries(
    multipliers.entries
        .where((e) => e.value != 1.0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value)),
  );
}