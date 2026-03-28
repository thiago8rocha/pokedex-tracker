import 'package:flutter/material.dart';

class PokopiaFossilsScreen extends StatefulWidget {
  const PokopiaFossilsScreen({super.key});

  @override
  State<PokopiaFossilsScreen> createState() => _PokopiaFossilsScreenState();
}

class _PokopiaFossilsScreenState extends State<PokopiaFossilsScreen> {
  String _search = '';

  List<_FossilData> get _filtered {
    if (_search.isEmpty) return _fossils;
    final q = _search.toLowerCase();
    return _fossils.where((f) =>
      f.pokemon.toLowerCase().contains(q) ||
      f.fossilName.toLowerCase().contains(q) ||
      (f.description?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fósseis'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(children: [
        // Busca
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Buscar fóssil ou Pokémon...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ),

        // Lista
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('Nenhum fóssil encontrado.',
                  style: TextStyle(color: scheme.onSurfaceVariant)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _FossilTile(data: filtered[i]),
                ),
        ),
      ]),
    );
  }
}

// ─── TILE ─────────────────────────────────────────────────────────

class _FossilTile extends StatelessWidget {
  final _FossilData data;
  const _FossilTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.pest_control_outlined, size: 22, color: scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pokémon
            Text(data.pokemon,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            // Fóssil(is) necessário(s)
            Text(data.fossilName,
              style: TextStyle(fontSize: 11,
                color: scheme.primary, fontWeight: FontWeight.w500)),
            if (data.parts != null) ...[ 
              const SizedBox(height: 2),
              Text('${data.parts} ${data.parts == 1 ? 'parte' : 'partes'}',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
            ],
            if (data.description != null) ...[
              const SizedBox(height: 6),
              Text(data.description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant, height: 1.4)),
            ],
          ],
        )),
        // Badge de partes
        if (data.parts != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('×${data.parts}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer)),
          ),
      ]),
    );
  }
}

// ─── DADOS ─────────────────────────────────────────────────────────
// Fonte: Nintendo Life, Game8, Dexerto (Março 2026)
// 9 Pokémon fósseis, 22 partes no total

class _FossilData {
  final String pokemon;
  final String fossilName;
  final int? parts;           // null = 1 fóssil inteiro
  final String? description;
  const _FossilData({
    required this.pokemon,
    required this.fossilName,
    this.parts,
    this.description,
  });
}

const _fossils = [
  _FossilData(
    pokemon: 'Aerodactyl',
    fossilName: 'Wing Fossil Display',
    parts: 5,
    description: 'Wing Fossil (Head), Wing Fossil (Body), Wing Fossil (Tail), '
        'Wing Fossil (Left Wing), Wing Fossil (Right Wing). '
        'Encontrado principalmente em Sparkling Skylands.',
  ),
  _FossilData(
    pokemon: 'Cranidos',
    fossilName: 'Skull Fossil',
    parts: 1,
    description: 'Um único fóssil de crânio. '
        'Encontrado principalmente em Withered Wasteland.',
  ),
  _FossilData(
    pokemon: 'Rampardos',
    fossilName: 'Headbutt Fossil Display',
    parts: 3,
    description: 'Headbutt Fossil (Head), Headbutt Fossil (Body), Headbutt Fossil (Tail). '
        'Evolução do Cranidos.',
  ),
  _FossilData(
    pokemon: 'Shieldon',
    fossilName: 'Armor Fossil',
    parts: 1,
    description: 'Um único fóssil de armadura craniana. '
        'Encontrado principalmente em Withered Wasteland.',
  ),
  _FossilData(
    pokemon: 'Bastiodon',
    fossilName: 'Shield Fossil Display',
    parts: 3,
    description: 'Shield Fossil (Left), Shield Fossil (Right), Shield Fossil (Top). '
        'Encontrado principalmente em Withered Wasteland.',
  ),
  _FossilData(
    pokemon: 'Tyrunt',
    fossilName: 'Jaw Fossil',
    parts: 1,
    description: 'Um único fóssil de mandíbula. '
        'Encontrado principalmente em Rocky Ridges.',
  ),
  _FossilData(
    pokemon: 'Tyrantrum',
    fossilName: 'Despot Fossil Display',
    parts: 4,
    description: 'Despot Fossil (Head), Despot Fossil (Body), Despot Fossil (Tail), '
        'Despot Fossil (Legs). Evolução do Tyrunt, encontrado em Rocky Ridges.',
  ),
  _FossilData(
    pokemon: 'Amaura',
    fossilName: 'Sail Fossil',
    parts: 1,
    description: 'Um único fóssil de vela dorsal. '
        'Encontrado principalmente em Bleak Beach.',
  ),
  _FossilData(
    pokemon: 'Aurorus',
    fossilName: 'Tundra Fossil Display',
    parts: 3,
    description: 'Tundra Fossil (Head), Tundra Fossil (Body), Tundra Fossil (Tail). '
        'Encontrado principalmente em Bleak Beach.',
  ),
];
