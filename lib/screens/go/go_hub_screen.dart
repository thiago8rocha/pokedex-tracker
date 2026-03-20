import 'package:flutter/material.dart';
import 'package:pokedex_tracker/screens/pokedex_screen.dart';
import 'package:pokedex_tracker/screens/go/go_cp_calculator_screen.dart';

class GoHubScreen extends StatelessWidget {
  const GoHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokémon GO'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          _HubCard(
            icon: Icons.catching_pokemon_outlined,
            title: 'Pokédex GO',
            subtitle: 'Ver e registrar seus Pokémon capturados no GO',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const PokedexScreen(
                pokedexId: 'pokémon_go',
                pokedexName: 'Pokémon GO',
                totalPokemon: 941,
              ),
            )),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.calculate_outlined,
            title: 'Calculadora de CP',
            subtitle: 'Calcule CP por IVs, nível ou após evolução',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const GoCpCalculatorScreen(),
            )),
          ),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant, width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 26, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(
              fontSize: 12, color: scheme.onSurfaceVariant)),
          ])),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}