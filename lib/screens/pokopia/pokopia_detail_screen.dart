import 'package:flutter/material.dart';
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart';
import 'package:pokedex_tracker/data/pokopia_habitat_data.dart';
import 'package:pokedex_tracker/screens/pokopia/pokopia_habitat_detail_screen.dart';
import 'package:pokedex_tracker/screens/pokopia/pokopia_event_habitat_detail_screen.dart';
import 'package:pokedex_tracker/services/pokeapi_service.dart';

class PokopiaDetailScreen extends StatefulWidget {
  final Pokemon pokemon;
  final bool caught;
  final VoidCallback onToggleCaught;

  /// Habitat de origem — se preenchido, o botão de voltar vai para ele.
  final PokopiaHabitat? originHabitat;

  const PokopiaDetailScreen({
    super.key,
    required this.pokemon,
    required this.caught,
    required this.onToggleCaught,
    this.originHabitat,
  });

  @override
  State<PokopiaDetailScreen> createState() => _PokopiaDetailScreenState();
}

class _PokopiaDetailScreenState extends State<PokopiaDetailScreen>
    with SingleTickerProviderStateMixin {

  late bool _caught;
  late TabController _tabController;

  static const _tabs = ['Amigos', 'Habitats'];

  // Habitats deste Pokémon
  List<PokopiaHabitat> get _pokemonHabitats {
    final ids = pokemonHabitatMap[widget.pokemon.id] ?? [];
    return pokopiaHabitats.where((h) => ids.contains(h.id)).toList();
  }

  // Habitats de EVENTO deste Pokémon
  List<PokopiaEventHabitat> get _pokemonEventHabitats {
    final ids = pokemonEventHabitatMap[widget.pokemon.id] ?? [];
    return pokopiaEventHabitats.where((h) => ids.contains(h.id)).toList();
  }

  // Especialidades deste Pokémon
  List<String> get _specialties =>
      pokopiaSpecialtyMap[widget.pokemon.id] ?? [];

  @override
  void initState() {
    super.initState();
    _caught = widget.caught;
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          DetailHeader(
            pokemon: widget.pokemon,
            caught: _caught,
            caughtLabel: 'Amigo',
            onToggleCaught: () {
              setState(() => _caught = !_caught);
              widget.onToggleCaught();
            },
            // Se veio de um habitat, override do botão voltar
            customBackAction: widget.originHabitat != null
                ? () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PokopiaHabitatDetailScreen(
                          habitat: widget.originHabitat!,
                        ),
                      ),
                    )
                : null,
          ),
        ],
        body: Column(children: [
          Material(
            elevation: 0,
            child: TabBar(
              controller: _tabController,
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabAlignment: TabAlignment.fill,
            ),
          ),
          Expanded(child: TabBarView(
            controller: _tabController,
            children: [
              _AmigosTab(
                  pokemon: widget.pokemon,
                  specialties: _specialties),
              _HabitatsTab(
                  habitats: _pokemonHabitats,
                  eventHabitats: _pokemonEventHabitats,
                  originPokemon: widget.pokemon,
                  originCaught: _caught,
                  onToggleOrigin: widget.onToggleCaught),
            ],
          )),
        ]),
      ),
    );
  }
}

// ─── ABA AMIGOS ──────────────────────────────────────────────────

class _AmigosTab extends StatelessWidget {
  final Pokemon pokemon;
  final List<String> specialties;
  const _AmigosTab({required this.pokemon, required this.specialties});

  @override
  Widget build(BuildContext context) {
    final border = neutralBorder(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        secTitle(context, 'APARIÇÃO'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            _row(context, 'Raridade', border,
              widget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFFEAF3DE),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text('Comum',
                    style: TextStyle(
                        color: Color(0xFF3B6D11),
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              )),
            _row(context, 'Horário', border, value: 'Manhã / Dia'),
            _row(context, 'Clima', border,
                value: 'Ensolarado / Nublado', isLast: true),
          ]),
        ),
        const SizedBox(height: 16),

        secTitle(context, 'HABITAT IDEAL'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                    color: const Color(0xFFFAEEDA),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.wb_sunny_outlined,
                    color: Color(0xFFc8a020), size: 18),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('Iluminado',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 5),
                  Text('(Bright)',
                      style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ]),
                Text('Prefere habitats ao ar livre ou bem iluminados',
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        secTitle(context, 'SABOR FAVORITO'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border, width: 0.5))),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Doce',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    Text('Sweet',
                        style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  'Leppa Salad', 'Fluffy Bread',
                  'Sweet Hamburger Steak', 'Leppa Berry'
                ]
                    .map((s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: border, width: 0.5)),
                          child: Text(s,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ))
                    .toList()),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        secTitle(context, 'COISAS FAVORITAS'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            ['Muita natureza', 'Lots of nature'],
            ['Coisas macias', 'Soft stuff'],
            ['Coisas fofas', 'Cute stuff'],
            ['Muita água', 'Lots of water'],
            ['Atividades em grupo', 'Group activities'],
          ].asMap().entries.map((e) {
            final isLast = e.key == 4;
            return Container(
              decoration: isLast
                  ? null
                  : BoxDecoration(
                      border: Border(
                          bottom:
                              BorderSide(color: border, width: 0.5))),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.value[0],
                        style: const TextStyle(fontSize: 13)),
                    Text(e.value[1],
                        style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ]),
            );
          }).toList()),
        ),
        const SizedBox(height: 16),

        // Especialidades
        if (specialties.isNotEmpty) ...[
          secTitle(context, 'ESPECIALIDADES'),
          ...specialties.map((sp) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        specialtyIconPath(sp),
                        width: 36,
                        height: 36,
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.auto_awesome_outlined,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                            Text(sp,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 3),
                            Text(
                              _specialtyDescription(sp),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  height: 1.4),
                            ),
                          ])),
                    ]),
              )),
        ],
      ]),
    );
  }

  Widget _row(BuildContext ctx, String label, Color border,
      {String? value, Widget? widget, bool isLast = false}) {
    return Container(
      decoration: isLast
          ? null
          : BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: border, width: 0.5))),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
        widget ??
            Text(value ?? '',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  String _specialtyDescription(String sp) {
    const descriptions = {
      'Grow': 'Acelera o crescimento de flores, árvores e colheitas.',
      'Burn': 'Acende fogueiras, fornalhas e outros objetos de fogo.',
      'Water': 'Rega plantas e enche fontes d\'água no mapa.',
      'Build': 'Auxilia na construção de estruturas e edifícios.',
      'Chop': 'Transforma troncos em madeira enquanto você faz outras tarefas.',
      'Fly': 'Carrega Ditto até outros Pokémon ou locais distantes.',
      'Teleport': 'Permite viagens instantâneas entre áreas da cidade.',
      'Generate': 'Alimenta geradores elétricos e dispositivos.',
      'Gather': 'Coleta itens e os deposita nas Community Boxes.',
      'Gather Honey': 'Coleta mel de flores e arbustos.',
      'Search': 'Localiza tesouros enterrados no solo.',
      'Bulldoze': 'Derruba estruturas ou realoca edifícios.',
      'Crush': 'Quebra itens transformando-os em novos materiais.',
      'Recycle': 'Transforma lixo em minério de ferro.',
      'Litter': 'Pode largar itens úteis ou transformar lixo em minério.',
      'Trade': 'Oferece trocas especiais de itens por recursos.',
      'Storage': 'Guarda itens como um baú portátil.',
      'Hype': 'Anima outros Pokémon, aumentando a velocidade deles.',
      'Yawn': 'Faz Pokémon ao redor ficarem sonolentos, aumentando a tranquilidade.',
      'Rarify': 'Aumenta a chance de aparecerem Pokémon raros nos habitats.',
      'Transform': 'Permite que Ditto se transforme temporariamente.',
      'Explode': 'Pode ser lançado contra objetos como uma aríete.',
      'Collect': 'Comerciante — oferece itens raros em troca de outros recursos.',
      'Dream Island': 'Carrega Ditto até as Dream Islands.',
      'Paint': 'Repinta móveis e estruturas.',
      'Party': 'Ajuda a preparar refeições em grande quantidade.',
      'Engineer': 'Lidera grandes projetos de construção.',
      'Eat': 'Aceita alimentos e concede efeitos especiais para o dia.',
      'Illuminate': 'Alimenta a rede elétrica da cidade inteira.',
      'Appraise': 'Avalia Relíquias Perdidas encontradas na jornada.',
      'DJ': 'Toca CDs, alterando a música ambiente da cidade.',
    };
    return descriptions[sp] ?? sp;
  }
}

// ─── ABA HABITATS ─────────────────────────────────────────────────

class _HabitatsTab extends StatelessWidget {
  final List<PokopiaHabitat> habitats;
  final List<PokopiaEventHabitat> eventHabitats;
  final Pokemon originPokemon;
  final bool originCaught;
  final VoidCallback onToggleOrigin;

  const _HabitatsTab({
    required this.habitats,
    required this.eventHabitats,
    required this.originPokemon,
    required this.originCaught,
    required this.onToggleOrigin,
  });

  @override
  Widget build(BuildContext context) {
    final border = neutralBorder(context);
    final scheme = Theme.of(context).colorScheme;
    final hasAny = habitats.isNotEmpty || eventHabitats.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        secTitle(context, 'HABITATS'),
        Text(
          'Locais onde este Pokémon pode ser encontrado em Pokopia.',
          style: TextStyle(
              fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),

        if (!hasAny)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: border, width: 0.5),
              borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.info_outline, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                'Dados de habitat ainda não disponíveis para este Pokémon.',
                style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                    height: 1.4),
              )),
            ]),
          ),

        // Habitats padrão
        ...habitats.map((h) => _HabitatCard(
              habitat: h,
              originPokemon: originPokemon,
              originCaught: originCaught,
              onToggleOrigin: onToggleOrigin,
            )),

        // Habitats de evento
        if (eventHabitats.isNotEmpty) ...[
          if (habitats.isNotEmpty) const SizedBox(height: 4),
          ...eventHabitats.map((h) => _EventHabitatCard(
                habitat: h,
                originPokemon: originPokemon,
                originCaught: originCaught,
                onToggleOrigin: onToggleOrigin,
              )),
        ],
      ]),
    );
  }
}

class _HabitatCard extends StatelessWidget {
  final PokopiaHabitat habitat;
  final Pokemon originPokemon;
  final bool originCaught;
  final VoidCallback onToggleOrigin;

  const _HabitatCard({
    required this.habitat,
    required this.originPokemon,
    required this.originCaught,
    required this.onToggleOrigin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final biomeColorVal =
        biomeColor[habitat.biomes.isNotEmpty ? habitat.biomes.first : ''] ?? 0xFF607D8B;
    final color = Color(biomeColorVal);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PokopiaHabitatDetailScreen(
            habitat: habitat,
            originPokemon: originPokemon,
            originCaught: originCaught,
            onToggleOrigin: onToggleOrigin,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: Column(children: [
          // Preview da imagem
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 100,
              width: double.infinity,
              child: Image.asset(
                habitat.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: color.withOpacity(0.1),
                  child: Center(
                    child: Icon(Icons.landscape_outlined,
                        size: 36, color: color.withOpacity(0.4)),
                  ),
                ),
              ),
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text(habitat.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                // Badge bioma
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    habitat.biomes.isNotEmpty
                        ? habitat.biomes.first
                        : '',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: color),
                  ),
                ),
              ])),
              Icon(Icons.chevron_right,
                  size: 18, color: scheme.outlineVariant),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _EventHabitatCard extends StatelessWidget {
  final PokopiaEventHabitat habitat;
  final Pokemon originPokemon;
  final bool originCaught;
  final VoidCallback onToggleOrigin;

  const _EventHabitatCard({
    required this.habitat,
    required this.originPokemon,
    required this.originCaught,
    required this.onToggleOrigin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PokopiaEventHabitatDetailScreen(
            habitat: habitat,
            originPokemon: originPokemon,
            originCaught: originCaught,
            onToggleOrigin: onToggleOrigin,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: Column(children: [
          // Preview da imagem
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 100,
              width: double.infinity,
              child: Image.asset(
                habitat.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: scheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(Icons.landscape_outlined,
                        size: 36, color: scheme.onSurfaceVariant.withOpacity(0.3)),
                  ),
                ),
              ),
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habitat.name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    // Badge de evento
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        habitat.eventName,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: scheme.onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: scheme.outlineVariant),
            ]),
          ),
        ]),
      ),
    );
  }
}