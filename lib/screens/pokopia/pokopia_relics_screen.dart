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
    _tab = TabController(length: 2, vsync: this);
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
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Relíquias Perdidas'),
            Tab(text: 'Fósseis'),
          ],
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
          tabAlignment: TabAlignment.fill,
        ),
      ),
      body: Column(children: [
        // Busca
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Buscar...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: scheme.outlineVariant),
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
              _RelicList(items: _relics, search: _search),
              _FossilList(items: _fossils, search: _search),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── LISTAS ───────────────────────────────────────────────────────

class _RelicList extends StatelessWidget {
  final List<_RelicData> items;
  final String search;
  const _RelicList({required this.items, required this.search});

  @override
  Widget build(BuildContext context) {
    final filtered = items
        .where((r) =>
            r.name.toLowerCase().contains(search.toLowerCase()) ||
            r.description.toLowerCase().contains(search.toLowerCase()))
        .toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: filtered.isEmpty ? 1 : filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text('Nenhuma relíquia encontrada.',
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            ),
          );
        }
        return _RelicTile(data: filtered[i]);
      },
    );
  }
}

class _FossilList extends StatelessWidget {
  final List<_FossilData> items;
  final String search;
  const _FossilList({required this.items, required this.search});

  @override
  Widget build(BuildContext context) {
    final filtered = items
        .where((f) =>
            f.name.toLowerCase().contains(search.toLowerCase()) ||
            f.pokemon.toLowerCase().contains(search.toLowerCase()) ||
            f.description.toLowerCase().contains(search.toLowerCase()))
        .toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: filtered.isEmpty ? 1 : filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text('Nenhum fóssil encontrado.',
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            ),
          );
        }
        return _FossilTile(data: filtered[i]);
      },
    );
  }
}

// ─── TILES ────────────────────────────────────────────────────────

class _RelicTile extends StatelessWidget {
  final _RelicData data;
  const _RelicTile({required this.data});

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
        // Ícone de relíquia
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant, width: 0.5),
          ),
          child: Icon(Icons.diamond_outlined,
              size: 20, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(data.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600))),
              // Badge de raridade
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _rarityColor(data.rarity).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(data.rarity,
                  style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w600,
                    color: _rarityColor(data.rarity))),
              ),
            ]),
            const SizedBox(height: 3),
            Text('Encontrado em: ${data.location}',
              style: TextStyle(fontSize: 10,
                  color: scheme.onSurfaceVariant)),
            const SizedBox(height: 5),
            Text(data.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant, height: 1.4)),
          ],
        )),
      ]),
    );
  }

  Color _rarityColor(String rarity) {
    switch (rarity) {
      case 'Comum':    return const Color(0xFF4CAF50);
      case 'Incomum':  return const Color(0xFF2196F3);
      case 'Raro':     return const Color(0xFF9C27B0);
      case 'Épico':    return const Color(0xFFFF9800);
      default:         return const Color(0xFF9E9E9E);
    }
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
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant, width: 0.5),
          ),
          child: Icon(Icons.pest_control_outlined,
              size: 20, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('Pokémon: ${data.pokemon}  •  ${data.location}',
              style: TextStyle(fontSize: 10,
                  color: scheme.onSurfaceVariant)),
            const SizedBox(height: 5),
            Text(data.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant, height: 1.4)),
          ],
        )),
      ]),
    );
  }
}

// ─── DADOS ────────────────────────────────────────────────────────

class _RelicData {
  final String name;
  final String rarity;
  final String location;
  final String description;
  const _RelicData({
    required this.name,
    required this.rarity,
    required this.location,
    required this.description,
  });
}

const _relics = [
  _RelicData(
    name: 'Fragmento Antigo',
    rarity: 'Comum',
    location: 'Withered Wasteland',
    description: 'Um pedaço de cerâmica de uma era passada. O Professor Tangrowth diz que era parte de um pote de cozinha.',
  ),
  _RelicData(
    name: 'Moeda Desgastada',
    rarity: 'Comum',
    location: 'Bleak Beach',
    description: 'Moeda encontrada nas areias da praia. A inscrição foi apagada pelo tempo, mas ainda se vê uma silueta de Pokémon.',
  ),
  _RelicData(
    name: 'Sino de Bronze',
    rarity: 'Incomum',
    location: 'Withered Wasteland',
    description: 'Pequeno sino com gravuras de Pokémon do tipo Psíquico. Quando agitado, emite um som cristalino.',
  ),
  _RelicData(
    name: 'Vaso de Jade',
    rarity: 'Incomum',
    location: 'Rocky Ridges',
    description: 'Vaso intacto feito de jade verde. Provavelmente pertencia a um comerciante que vivia na área.',
  ),
  _RelicData(
    name: 'Estátua de Pedra',
    rarity: 'Raro',
    location: 'Rocky Ridges',
    description: 'Uma pequena estátua esculpida à mão representando o que parece ser um Onix. Impecavelmente preservada.',
  ),
  _RelicData(
    name: 'Medalha Real',
    rarity: 'Raro',
    location: 'Sparkling Skylands',
    description: 'Medalha dourada com a forma de uma Coroa. O Professor Tangrowth suspeita que pertenceu a um Líder de Ginásio.',
  ),
  _RelicData(
    name: 'Cristal Luminoso',
    rarity: 'Épico',
    location: 'Sparkling Skylands',
    description: 'Um cristal que pulsa com uma luz fraca. O Professor Tangrowth não consegue explicar a origem de sua energia.',
  ),
  _RelicData(
    name: 'Tabuleta Misteriosa',
    rarity: 'Épico',
    location: 'Palette Town',
    description: 'Uma das 27 Tabuletas Misteriosas que, quando combinadas corretamente, revelam uma imagem de Mew.',
  ),
];

class _FossilData {
  final String name;
  final String pokemon;
  final String location;
  final String description;
  const _FossilData({
    required this.name,
    required this.pokemon,
    required this.location,
    required this.description,
  });
}

const _fossils = [
  _FossilData(
    name: 'Fóssil Dome',
    pokemon: 'Kabuto',
    location: 'Rocky Ridges',
    description: 'Fóssil em forma de cúpula. Contém o registro de um Pokémon que habitou os oceanos antigos.',
  ),
  _FossilData(
    name: 'Fóssil Helix',
    pokemon: 'Omanyte',
    location: 'Bleak Beach',
    description: 'Fóssil espiral encontrado nas rochas costeiras. Pertenceu a um Pokémon de concha.',
  ),
  _FossilData(
    name: 'Fóssil Old Amber',
    pokemon: 'Aerodactyl',
    location: 'Rocky Ridges',
    description: 'Âmbar translúcido com inseto preservado dentro. Registra a existência de um Pokémon voador dos tempos primordiais.',
  ),
  _FossilData(
    name: 'Fóssil Root',
    pokemon: 'Lileep',
    location: 'Withered Wasteland',
    description: 'Fóssil de uma raiz antiga. O Pokémon que o originou se enraizava no fundo do mar.',
  ),
  _FossilData(
    name: 'Fóssil Claw',
    pokemon: 'Anorith',
    location: 'Bleak Beach',
    description: 'Garra fossilizada de um crustáceo primitivo. O Professor Tangrowth fica empolgado toda vez que vê um.',
  ),
  _FossilData(
    name: 'Fóssil Skull',
    pokemon: 'Cranidos',
    location: 'Rocky Ridges',
    description: 'Crânio com uma protuberância dura. Pertenceu a um Pokémon que usava a cabeça para lutar.',
  ),
  _FossilData(
    name: 'Fóssil Shield',
    pokemon: 'Shieldon',
    location: 'Rocky Ridges',
    description: 'Armadura craniana fossilizada. O Pokémon de origem usava a face blindada como defesa.',
  ),
];