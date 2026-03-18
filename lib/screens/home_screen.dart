import 'package:flutter/material.dart';
import 'package:pokedex_tracker/theme/type_colors.dart';
import 'package:pokedex_tracker/screens/pokedex_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokedex'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NacionalCard(),
            const SizedBox(height: 16),
            _PokedexGrid(),
          ],
        ),
      ),
    );
  }
}

class _NacionalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nacional',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '0 / 1025',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PokedexGrid extends StatelessWidget {
  final List<_PokedexEntry> entries = const [
    _PokedexEntry(name: "Let's Go Pikachu / Eevee", year: '2018', total: 153),
    _PokedexEntry(name: 'Sword / Shield', year: '2019', total: 400),
    _PokedexEntry(
      name: 'Brilliant Diamond / Shining Pearl',
      year: '2021',
      total: 493,
    ),
    _PokedexEntry(name: 'Legends: Arceus', year: '2022', total: 242),
    _PokedexEntry(name: 'Scarlet / Violet', year: '2022', total: 400),
    _PokedexEntry(name: 'Legends: Z-A', year: '2025', total: 132),
    _PokedexEntry(name: 'FireRed / LeafGreen', year: '2026', total: 386),
    _PokedexEntry(name: 'Pokopia', year: '2026', total: 311),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.55,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) => _PokedexCard(entry: entries[index]),
        ),
        const SizedBox(height: 8),
        _SectionLabel(label: 'MOBILE'),
        const SizedBox(height: 8),
        _PokedexCard(
          entry: const _PokedexEntry(
            name: 'Pokémon GO',
            year: '2016',
            total: 941,
          ),
          fullWidth: true,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1.1,
          ),
    );
  }
}

class _PokedexCard extends StatelessWidget {
  final _PokedexEntry entry;
  final bool fullWidth;

  const _PokedexCard({required this.entry, this.fullWidth = false});

  void _openPokedex(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PokedexScreen(
          pokedexName: entry.name,
          totalPokemon: entry.total,
          pokemonIds: List.generate(
            entry.total > 20 ? 20 : entry.total,
            (i) => i + 1,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool complete = entry.caught >= entry.total;

    return GestureDetector(
      onTap: () => _openPokedex(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: complete
                ? Colors.green.withOpacity(0.4)
                : Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        child: fullWidth
            ? Row(
                children: [
                  _cardIcon(context),
                  const SizedBox(width: 10),
                  Expanded(child: _cardInfo(context, complete)),
                  if (complete)
                    const Text('👑', style: TextStyle(fontSize: 18)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _cardIcon(context),
                      if (complete)
                        const Text('👑', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _cardInfo(context, complete),
                ],
              ),
      ),
    );
  }

  Widget _cardIcon(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.catching_pokemon, size: 18),
    );
  }

  Widget _cardInfo(BuildContext context, bool complete) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.name,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          '${entry.caught} / ${entry.total}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: complete ? Colors.green : null,
              ),
        ),
      ],
    );
  }
}

class _PokedexEntry {
  final String name;
  final String year;
  final int total;
  final int caught;

  const _PokedexEntry({
    required this.name,
    required this.year,
    required this.total,
    this.caught = 0,
  });
}