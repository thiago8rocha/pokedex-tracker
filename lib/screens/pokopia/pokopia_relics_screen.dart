import 'package:flutter/material.dart';

class PokopiaRelicsScreen extends StatefulWidget {
  const PokopiaRelicsScreen({super.key});

  @override
  State<PokopiaRelicsScreen> createState() => _PokopiaRelicsScreenState();
}

class _PokopiaRelicsScreenState extends State<PokopiaRelicsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relíquias e Fósseis'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(children: [
        TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Relíquias Grandes'),
            Tab(text: 'Relíquias Pequenas'),
            Tab(text: 'Fósseis'),
          ],
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
        ),
        // Info geral
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant, width: 0.5),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Relíquias são encontradas em pontos brilhantes no chão de qualquer bioma. '
                'Quebre com Rock Smash e leve ao Professor Tangrowth para avaliar. '
                'As localizações são aleatórias — você pode encontrar duplicatas.',
                style: TextStyle(fontSize: 11,
                    color: scheme.onSurfaceVariant, height: 1.4))),
            ]),
          ),
        ),

        // Busca
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Buscar...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ),

        // Conteúdo
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _RelicList(
                items: _largeRelics
                    .where((r) => r.toLowerCase().contains(_search.toLowerCase()))
                    .toList(),
                icon: Icons.chair_outlined,
                emptyMessage: 'Nenhuma relíquia grande encontrada.',
                isSmall: false,
              ),
              _RelicList(
                items: _smallRelics
                    .where((r) => r.toLowerCase().contains(_search.toLowerCase()))
                    .toList(),
                icon: Icons.diamond_outlined,
                emptyMessage: 'Nenhuma relíquia pequena encontrada.',
                isSmall: true,
              ),
              _FossilList(
                items: _fossils
                    .where((f) =>
                        f.name.toLowerCase().contains(_search.toLowerCase()) ||
                        f.pokemon.toLowerCase().contains(_search.toLowerCase()))
                    .toList(),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── LISTAS ───────────────────────────────────────────────────────

class _RelicList extends StatelessWidget {
  final List<String> items;
  final IconData icon;
  final String emptyMessage;
  final bool isSmall;
  const _RelicList({
    required this.items,
    required this.icon,
    required this.emptyMessage,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return Center(
        child: Text(emptyMessage,
          style: TextStyle(color: scheme.onSurfaceVariant)));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(items[i],
            style: const TextStyle(fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isSmall ? 'Small' : 'Large',
              style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
          ),
        ]),
      ),
    );
  }
}

class _FossilList extends StatelessWidget {
  final List<_FossilData> items;
  const _FossilList({required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return Center(
        child: Text('Nenhum fóssil encontrado.',
          style: TextStyle(color: scheme.onSurfaceVariant)));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _FossilTile(data: items[i]),
    );
  }
}

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
        Icon(Icons.pest_control_outlined,
            size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('Pokémon: ${data.pokemon}',
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
            if (data.description != null) ...[
              const SizedBox(height: 5),
              Text(data.description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant, height: 1.4)),
            ],
          ],
        )),
      ]),
    );
  }
}

// ─── DADOS ────────────────────────────────────────────────────────

// 37 relíquias grandes — mobiliário temático
const _largeRelics = [
  'Polygonal Shelf',
  'Avalugg Table',
  'Naptime Bed',
  'Wiggly Mirror',
  'Pitcher-plant Pot',
  'Arcade Machine',
  'Funky Diffuser',
  'Gold Teeth',
  'Big Nugget',
  'Boo-in-the-Box',
  'Mysterious Statue',
  'Fiery Magby Statue',
  'Gym Emblem Statue',
  'Spacesuit',
  'Model Space Shuttle',
  'Spaceship',
  'Rowlet Clock',
  'Castform Weather Charm',
  'Eerie Candle',
  'Garden Ornament',
  'Bike',
  'Horsea Fountain',
  'Fishing Rod',
  'Raichu Sign',
  'Photo Cutout Board',
  'Meteor Lamp',
  'Slowpoke Rug',
  'Town Map',
];

// 46 relíquias pequenas — itens de jogos anteriores
const _smallRelics = [
  'Miracle Seed',
  'Hard Stone',
  'Black Glasses',
  'Black Belt',
  'Spell Tag',
  'Destiny Knot',
  'Life Orb',
  'Iron Ball',
  'Metal Powder',
  'Adrenaline Orb',
  'Throat Spray',
  'Flame Orb',
  'Room Service',
  'Choice Band',
  'Choice Scarf',
  'Choice Specs',
  'Toxic Orb',
  'Weakness Policy',
  'Assault Vest',
  'Rocky Helmet',
  'Safety Goggles',
  'Eject Button',
  'Red Card',
  'Eject Pack',
  'Heavy-Duty Boots',
  'Clear Amulet',
  'Covert Cloak',
  'Loaded Dice',
  'Booster Energy',
];

class _FossilData {
  final String name;
  final String pokemon;
  final String? description;
  const _FossilData({
    required this.name,
    required this.pokemon,
    this.description,
  });
}

const _fossils = [
  _FossilData(
    name: 'Dome Fossil',
    pokemon: 'Kabuto',
    description: 'Fóssil em forma de cúpula. Kabuto habitou os oceanos antigos.',
  ),
  _FossilData(
    name: 'Helix Fossil',
    pokemon: 'Omanyte',
    description: 'Fóssil espiral encontrado nas rochas costeiras.',
  ),
  _FossilData(
    name: 'Old Amber',
    pokemon: 'Aerodactyl',
    description: 'Âmbar translúcido com inseto preservado. Registra um Pokémon voador dos tempos primordiais.',
  ),
  _FossilData(
    name: 'Root Fossil',
    pokemon: 'Lileep',
    description: 'Fóssil de raiz antiga. O Pokémon se enraizava no fundo do mar.',
  ),
  _FossilData(
    name: 'Claw Fossil',
    pokemon: 'Anorith',
    description: 'Garra fossilizada de um crustáceo primitivo.',
  ),
  _FossilData(
    name: 'Skull Fossil',
    pokemon: 'Cranidos',
    description: 'Crânio com protuberância dura. Usado para investidas.',
  ),
  _FossilData(
    name: 'Armor Fossil',
    pokemon: 'Shieldon',
    description: 'Armadura craniana fossilizada. Usada como defesa.',
  ),
  _FossilData(
    name: 'Cover Fossil',
    pokemon: 'Tirtouga',
    description: 'Fóssil de carapaça de tartaruga marinha pré-histórica.',
  ),
  _FossilData(
    name: 'Plume Fossil',
    pokemon: 'Archen',
    description: 'Fóssil de penas. Pertenceu a um dos primeiros Pokémon voadores.',
  ),
  _FossilData(
    name: 'Jaw Fossil',
    pokemon: 'Tyrunt',
    description: 'Mandíbula fossilizada com dentes imponentes.',
  ),
  _FossilData(
    name: 'Sail Fossil',
    pokemon: 'Amaura',
    description: 'Fóssil de uma vela dorsal. Pertenceu a um Pokémon do tipo Gelo.',
  ),
];