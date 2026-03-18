import 'package:flutter/material.dart';
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/theme/type_colors.dart';

class PokemonDetailScreen extends StatefulWidget {
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
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen>
    with SingleTickerProviderStateMixin {
  late bool _caught;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _caught = widget.caught;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleCaught() {
    setState(() => _caught = !_caught);
    widget.onToggleCaught();
  }

  @override
  Widget build(BuildContext context) {
    final primaryType = widget.pokemon.types.isNotEmpty ? widget.pokemon.types[0] : 'normal';
    final typeColor = TypeColors.fromType(_ptType(primaryType));
    final secondaryColor = widget.pokemon.types.length > 1
        ? TypeColors.fromType(_ptType(widget.pokemon.types[1]))
        : typeColor;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          _buildHeader(context, typeColor, secondaryColor),
        ],
        body: Column(
          children: [
            // TabBar fixa abaixo do header
            TabBar(
              controller: _tabController,
              tabs: const [Tab(text: 'Info'), Tab(text: 'Status')],
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.primary,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _InfoTab(pokemon: widget.pokemon),
                  _StatusTab(pokemon: widget.pokemon),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color typeColor, Color secondaryColor) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: typeColor.withOpacity(0.85),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          onPressed: _toggleCaught,
          icon: Icon(
            _caught ? Icons.catching_pokemon : Icons.catching_pokemon_outlined,
            color: Colors.white,
            size: 28,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [typeColor.withOpacity(0.85), secondaryColor.withOpacity(0.65)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
              child: Row(
                children: [
                  // Sprite
                  widget.pokemon.spriteUrl.isNotEmpty
                      ? Image.network(
                          widget.pokemon.spriteUrl,
                          width: 110, height: 110,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.catching_pokemon, size: 80, color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.catching_pokemon, size: 80, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '#${widget.pokemon.id.toString().padLeft(3, '0')}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          widget.pokemon.name,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        // Badges de tipo
                        Wrap(
                          spacing: 6,
                          children: widget.pokemon.types.map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _ptType(t),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── ABA INFO ────────────────────────────────────────────────────

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
          // Informações básicas — grade 2x2
          _sectionTitle(context, 'INFORMAÇÕES'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _infoBox(context, 'Altura', _formatHeight(pokemon.id))),
              const SizedBox(width: 10),
              Expanded(child: _infoBox(context, 'Peso', _formatWeight(pokemon.id))),
              const SizedBox(width: 10),
              Expanded(child: _infoBox(context, 'Captura', _captureRate(pokemon.id))),
            ],
          ),
          const SizedBox(height: 20),

          // Habilidades (busca via PokéAPI — aqui mostramos as do modelo)
          _sectionTitle(context, 'HABILIDADES'),
          const SizedBox(height: 10),
          // Habilidades são parte do modelo Pokemon — por ora mostramos placeholder
          // Em versões futuras serão carregadas da API
          _AbilityList(pokemonId: pokemon.id),
          const SizedBox(height: 20),

          // Evoluções
          _sectionTitle(context, 'EVOLUÇÕES'),
          const SizedBox(height: 10),
          _EvolutionChain(pokemonId: pokemon.id, pokemonName: pokemon.name),
          const SizedBox(height: 20),

          // Disponível em
          _sectionTitle(context, 'DISPONÍVEL EM'),
          const SizedBox(height: 10),
          _AvailableIn(pokemonId: pokemon.id),
        ],
      ),
    );
  }

  Widget _infoBox(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )),
        ],
      ),
    );
  }

  // Altura e peso são hardcodados aqui como placeholder —
  // idealmente viriam do endpoint /pokemon-species/{id} via PokéAPI
  String _formatHeight(int id) => '—';
  String _formatWeight(int id) => '—';
  String _captureRate(int id) => '—';
}

// ─── HABILIDADES ────────────────────────────────────────────────

class _AbilityList extends StatefulWidget {
  final int pokemonId;
  const _AbilityList({required this.pokemonId});

  @override
  State<_AbilityList> createState() => _AbilityListState();
}

class _AbilityListState extends State<_AbilityList> {
  // Placeholder — em versão futura busca via API
  // A PokéAPI tem /pokemon/{id} com campo "abilities" contendo
  // name, is_hidden e url para descrição em /ability/{id}
  static const List<Map<String, dynamic>> _mockAbilities = [
    {'name': 'Blaze', 'description': 'Aumenta poder de ataques Fogo quando o HP está baixo.', 'isHidden': false},
    {'name': 'Solar Power', 'description': 'Aumenta At. Especial sob sol forte, mas perde HP.', 'isHidden': true},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _mockAbilities.map((ability) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        ability['name'] as String,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (ability['isHidden'] as bool) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Oculta',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Text(
                      ability['description'] as String,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

// ─── CADEIA DE EVOLUÇÃO ──────────────────────────────────────────

class _EvolutionChain extends StatelessWidget {
  final int pokemonId;
  final String pokemonName;
  const _EvolutionChain({required this.pokemonId, required this.pokemonName});

  @override
  Widget build(BuildContext context) {
    // Placeholder visual — em versão futura carrega /pokemon-species/{id}
    // e então /evolution-chain/{id} para montar a cadeia real
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _evoNode(context, pokemonId, pokemonName),
          _evoArrow(context, 'Nv. 16'),
          _evoPlaceholder(context),
          _evoArrow(context, 'Nv. 36'),
          _evoPlaceholder(context),
        ],
      ),
    );
  }

  Widget _evoNode(BuildContext context, int id, String name) {
    final sprite = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
        'sprites/pokemon/other/official-artwork/$id.png';
    return Column(
      children: [
        Image.network(sprite, width: 56, height: 56,
            errorBuilder: (_, __, ___) => const Icon(Icons.catching_pokemon, size: 40)),
        const SizedBox(height: 4),
        Text(name, style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600, fontSize: 9,
        ), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _evoPlaceholder(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Icon(Icons.catching_pokemon_outlined,
              size: 28, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text('?', style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        )),
      ],
    );
  }

  Widget _evoArrow(BuildContext context, String condition) {
    return Expanded(
      child: Column(
        children: [
          Row(children: [
            const Expanded(child: Divider()),
            Icon(Icons.arrow_forward_ios,
                size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ]),
          Text(condition, style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 9, color: Theme.of(context).colorScheme.onSurfaceVariant,
          )),
        ],
      ),
    );
  }
}

// ─── DISPONÍVEL EM ───────────────────────────────────────────────

class _AvailableIn extends StatelessWidget {
  final int pokemonId;
  const _AvailableIn({required this.pokemonId});

  // Mapeia ID nacional → jogos onde aparece (simplificado)
  // Em versão futura usa game_indices da PokéAPI
  static const Map<String, String> _gameIcons = {
    "Let's Go P/E": '#EAF3DE',
    'Sword / Shield': '#E6F1FB',
    'BD / SP': '#FBEAF0',
    'Legends: Arceus': '#EEEDFE',
    'Scarlet / Violet': '#FAECE7',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _gameIcons.entries.map((e) {
        Color bg;
        try { bg = Color(int.parse(e.value.replaceAll('#', '0xFF'))); }
        catch (_) { bg = Colors.grey.shade100; }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            e.key,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11, fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── ABA STATUS ──────────────────────────────────────────────────

class _StatusTab extends StatelessWidget {
  final Pokemon pokemon;
  const _StatusTab({required this.pokemon});

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
          _StatBar(label: 'Ataque', value: pokemon.baseAttack, color: Colors.red),
          _StatBar(label: 'Defesa', value: pokemon.baseDefense, color: Colors.blue),
          _StatBar(label: 'At. Especial', value: pokemon.baseSpAttack, color: Colors.purple),
          _StatBar(label: 'Def. Especial', value: pokemon.baseSpDefense, color: Colors.blueAccent),
          _StatBar(label: 'Velocidade', value: pokemon.baseSpeed, color: Colors.amber),
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
          const SizedBox(height: 20),
          _sectionTitle(context, 'TIPOS'),
          const SizedBox(height: 8),
          Row(
            children: pokemon.types.map((t) => Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: TypeColors.fromType(_ptType(t)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_ptType(t), style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500,
              )),
            )).toList(),
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

class _StatBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatBar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ))),
          SizedBox(width: 36, child: Text('$value', style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ), textAlign: TextAlign.right)),
          const SizedBox(width: 10),
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 255,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          )),
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
      return Text('Nenhuma fraqueza', style: Theme.of(context).textTheme.bodySmall);
    }
    return Wrap(
      spacing: 6, runSpacing: 6,
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
            style: TextStyle(color: color.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w500),
          ),
        );
      }).toList(),
    );
  }
}

// ─── HELPERS ─────────────────────────────────────────────────────

Widget _sectionTitle(BuildContext context, String title) {
  return Text(title, style: Theme.of(context).textTheme.labelSmall?.copyWith(
    letterSpacing: 0.8,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    fontWeight: FontWeight.w500,
  ));
}

String _ptType(String englishType) {
  const map = {
    'normal': 'Normal', 'fire': 'Fogo', 'water': 'Água', 'electric': 'Elétrico',
    'grass': 'Planta', 'ice': 'Gelo', 'fighting': 'Lutador', 'poison': 'Veneno',
    'ground': 'Terreno', 'flying': 'Voador', 'psychic': 'Psíquico', 'bug': 'Inseto',
    'rock': 'Pedra', 'ghost': 'Fantasma', 'dragon': 'Dragão', 'dark': 'Sombrio',
    'steel': 'Aço', 'fairy': 'Fada',
  };
  return map[englishType.toLowerCase()] ?? englishType;
}

Map<String, double> _calculateWeaknesses(List<String> types) {
  const typeChart = {
    'normal': {'fighting': 2.0, 'ghost': 0.0},
    'fire': {'water': 2.0, 'rock': 2.0, 'ground': 2.0, 'fire': 0.5, 'grass': 0.5, 'ice': 0.5, 'bug': 0.5, 'steel': 0.5, 'fairy': 0.5},
    'water': {'electric': 2.0, 'grass': 2.0, 'fire': 0.5, 'water': 0.5, 'ice': 0.5, 'steel': 0.5},
    'electric': {'ground': 2.0, 'electric': 0.5, 'flying': 0.5, 'steel': 0.5},
    'grass': {'fire': 2.0, 'ice': 2.0, 'poison': 2.0, 'flying': 2.0, 'bug': 2.0, 'water': 0.5, 'electric': 0.5, 'grass': 0.5, 'ground': 0.5},
    'ice': {'fire': 2.0, 'fighting': 2.0, 'rock': 2.0, 'steel': 2.0, 'ice': 0.5},
    'fighting': {'flying': 2.0, 'psychic': 2.0, 'fairy': 2.0, 'rock': 0.5, 'bug': 0.5, 'dark': 0.5},
    'poison': {'ground': 2.0, 'psychic': 2.0, 'fighting': 0.5, 'poison': 0.5, 'bug': 0.5, 'grass': 0.5, 'fairy': 0.5},
    'ground': {'water': 2.0, 'grass': 2.0, 'ice': 2.0, 'electric': 0.0, 'poison': 0.5, 'rock': 0.5},
    'flying': {'electric': 2.0, 'ice': 2.0, 'rock': 2.0, 'ground': 0.0, 'fighting': 0.5, 'bug': 0.5, 'grass': 0.5},
    'psychic': {'bug': 2.0, 'ghost': 2.0, 'dark': 2.0, 'fighting': 0.5, 'psychic': 0.5},
    'bug': {'fire': 2.0, 'flying': 2.0, 'rock': 2.0, 'fighting': 0.5, 'ground': 0.5, 'grass': 0.5},
    'rock': {'water': 2.0, 'grass': 2.0, 'fighting': 2.0, 'ground': 2.0, 'steel': 2.0, 'normal': 0.5, 'fire': 0.5, 'poison': 0.5, 'flying': 0.5},
    'ghost': {'ghost': 2.0, 'dark': 2.0, 'normal': 0.0, 'fighting': 0.0, 'poison': 0.5, 'bug': 0.5},
    'dragon': {'ice': 2.0, 'dragon': 2.0, 'fairy': 2.0, 'fire': 0.5, 'water': 0.5, 'electric': 0.5, 'grass': 0.5},
    'dark': {'fighting': 2.0, 'bug': 2.0, 'fairy': 2.0, 'ghost': 0.5, 'dark': 0.5, 'psychic': 0.0},
    'steel': {'fire': 2.0, 'fighting': 2.0, 'ground': 2.0, 'normal': 0.5, 'grass': 0.5, 'ice': 0.5, 'flying': 0.5, 'psychic': 0.5, 'bug': 0.5, 'rock': 0.5, 'dragon': 0.5, 'steel': 0.5, 'fairy': 0.5, 'poison': 0.0},
    'fairy': {'poison': 2.0, 'steel': 2.0, 'fighting': 0.5, 'bug': 0.5, 'dark': 0.5, 'dragon': 0.0},
  };
  Map<String, double> multipliers = {};
  for (final type in types) {
    final chart = typeChart[type.toLowerCase()] ?? {};
    for (final e in chart.entries) {
      final ptType = _ptType(e.key);
      multipliers[ptType] = (multipliers[ptType] ?? 1.0) * e.value;
    }
  }
  return Map.fromEntries(
    multipliers.entries.where((e) => e.value != 1.0).toList()
      ..sort((a, b) => b.value.compareTo(a.value)),
  );
}