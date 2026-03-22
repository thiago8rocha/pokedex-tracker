import 'package:flutter/material.dart';
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart';
import 'package:pokedex_tracker/services/pokedex_data_service.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/theme/type_colors.dart';
import 'package:pokedex_tracker/translations.dart';

class NacionalDetailScreen extends StatefulWidget {
  final Pokemon pokemon;
  final bool caught;
  final VoidCallback onToggleCaught;
  final String? prevName;
  final int?    prevId;
  final String? nextName;
  final int?    nextId;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const NacionalDetailScreen({
    super.key,
    required this.pokemon,
    required this.caught,
    required this.onToggleCaught,
    this.prevName, this.prevId,
    this.nextName, this.nextId,
    this.onPrev, this.onNext,
  });

  @override
  State<NacionalDetailScreen> createState() => _NacionalDetailScreenState();
}

class _NacionalDetailScreenState extends State<NacionalDetailScreen>
    with SingleTickerProviderStateMixin {

  late bool _caught;
  late TabController _tabController;

  List<Map<String, dynamic>> _abilities = [];
  List<Map<String, dynamic>> _evoChain = [];
  List<Map<String, dynamic>> _forms = [];
  List<Map<String, dynamic>> _movesLevel = [];
  List<Map<String, dynamic>> _movesMT = [];
  List<Map<String, dynamic>> _movesTutor = [];
  List<Map<String, dynamic>> _movesEgg = [];
  bool _loading = true;
  String _flavorTextPt = '';
  Set<String>? _activePokedexIds; // null = todas ativas

  bool get _hasMultipleForms => !_loading && _forms.length > 1;

  List<String> get _tabs => _hasMultipleForms
      ? ['Sobre', 'Status', 'Formas', 'Moves']
      : ['Sobre', 'Status', 'Moves'];

  @override
  void initState() {
    super.initState();
    _caught = widget.caught;
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  void _rebuildTabController() {
    final newLength = _hasMultipleForms ? 4 : 3;
    if (_tabController.length != newLength) {
      final oldIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
        length: newLength,
        vsync: this,
        initialIndex: oldIndex.clamp(0, newLength - 1),
      );
    }
  }

  Future<void> _loadAll() async {
    final id  = widget.pokemon.id;
    final svc = PokedexDataService.instance;

    // Pokedex ativas (local, instantâneo)
    final active = await StorageService().getActivePokedexIds();
    if (mounted) setState(() => _activePokedexIds = active);

    _abilities = svc.getAbilities(id).map((a) => {
      'nameEn'     : a['nameEn'] as String,
      'namePt'     : translateAbility(a['nameEn'] as String),
      'description': a['description'] as String? ?? '',
      'isHidden'   : a['isHidden'] as bool,
    }).toList();

    _evoChain = svc.getEvoChain(id);

    _flavorTextPt = svc.getFlavorText(id);

    if (mounted) setState(() => _loading = false);
  }

  void _parseForms(Map<String, dynamic> d) {
    _forms = [{'name': widget.pokemon.name, 'id': widget.pokemon.id,
      'types': widget.pokemon.types, 'isDefault': true}];
    if (mounted) setState(() {});
  }

  Future<void> _loadAlternateForms() async {
    // Formas alternativas carregadas via asset quando disponível
  }

  void _parseMoves(Map<String, dynamic> d) {
    final level = <Map<String, dynamic>>[], mt = <Map<String, dynamic>>[];
    final tutor = <Map<String, dynamic>>[], egg = <Map<String, dynamic>>[];
    for (final m in d['moves'] as List<dynamic>) {
      final name = m['move']['name'] as String;
      final url = m['move']['url'] as String;
      for (final vg in (m['version_group_details'] as List<dynamic>).reversed) {
        final method = vg['move_learn_method']['name'] as String;
        final lvl = vg['level_learned_at'] as int;
        final entry = {'name': name, 'nameEn': name, 'namePt': '', 'url': url, 'level': lvl, 'method': method};
        if (method == 'level-up') { level.add(entry); break; }
        else if (method == 'machine') { mt.add(entry); break; }
        else if (method == 'tutor') { tutor.add(entry); break; }
        else if (method == 'egg') { egg.add(entry); break; }
      }
    }
    level.sort((a, b) => (a['level'] as int).compareTo(b['level'] as int));
    if (mounted) setState(() { _movesLevel = level; _movesMT = mt; _movesTutor = tutor; _movesEgg = egg; });
  }

  // ─── ACCESSORS ───────────────────────────────────────────────

  String get _height => PokedexDataService.instance.getHeight(widget.pokemon.id);
  String get _weight => PokedexDataService.instance.getWeight(widget.pokemon.id);
  String get _captureRate {
    final rate = PokedexDataService.instance.getCaptureRate(widget.pokemon.id);
    return rate > 0 ? '$rate' : '—';
  }

  String get _flavorText => _flavorTextPt;

  // Categoria já vem traduzida do JSON
  String get _category => PokedexDataService.instance.getCategory(widget.pokemon.id);

  // Mapeamento: nome do jogo no JSON → pokedexId no storage
  // Usado para filtrar apenas as pokedexes que o usuário tem ativas
  static const Map<String, String> _gameToPokedexId = {
    'Red / Blue':                      'red___blue',
    'Gold / Silver':                   'gold___silver',
    'Ruby / Sapphire':                 'ruby___sapphire',
    'FireRed / LeafGreen (GBA)':       'firered___leafgreen_(gba)',
    'Emerald':                         'emerald',
    'Diamond / Pearl':                 'diamond___pearl',
    'Platinum':                        'platinum',
    'HeartGold / SoulSilver':          'heartgold___soulsilver',
    'Black / White':                   'black___white',
    'Black 2 / White 2':               'black_2___white_2',
    'X / Y':                           'x___y',
    'Omega Ruby / Alpha Sapphire':     'omega_ruby___alpha_sapphire',
    'Sun / Moon':                      'sun___moon',
    'Ultra Sun / Ultra Moon':          'ultra_sun___ultra_moon',
    "Let's Go Pikachu / Eevee":        'let\'s_go_pikachu___eevee',
    'Sword / Shield':                  'sword___shield',
    'Brilliant Diamond / Shining Pearl': 'brilliant_diamond___shining_pearl',
    'Legends: Arceus':                 'legends_arceus',
    'Scarlet / Violet':                'scarlet___violet',
    'Legends: Z-A':                    'legends_z-a',
    'FireRed / LeafGreen':             'firered___leafgreen',
    'Pokémon GO':                      'pokémon_go',
    'Pokopia':                         'pokopia',
  };

  List<String> get _availableGames {
    // Dados reais do JSON — lista exata de jogos onde o pokémon aparece
    final allGames = PokedexDataService.instance.getGames(widget.pokemon.id);

    // Se não há filtro de pokedexes ativas, retorna tudo
    if (_activePokedexIds == null) return allGames;

    // Filtra mantendo só os jogos cuja pokedex está ativa
    return allGames.where((game) {
      final dexId = _gameToPokedexId[game];
      if (dexId == null) return true; // não mapeado = sempre exibe
      return _activePokedexIds!.contains(dexId);
    }).toList();
  }

  // ─── BUILD ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          DetailHeader(
            pokemon: widget.pokemon,
            caught: _caught,
            onToggleCaught: () { setState(() => _caught = !_caught); widget.onToggleCaught(); },
            prevName: widget.prevName, prevId: widget.prevId,
            nextName: widget.nextName, nextId: widget.nextId,
            onPrev: widget.onPrev, onNext: widget.onNext,
          ),
        ],
        body: Column(children: [
          Material(
            elevation: 0,
            child: TabBar(
              controller: _tabController,
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabAlignment: TabAlignment.fill,
            ),
          ),
          Expanded(child: TabBarView(
            controller: _tabController,
            children: [
              _NacionalInfoTab(
                pokemon: widget.pokemon,
                abilities: _abilities,
                evoChain: _evoChain,
                category: _category,
                flavorText: _flavorText,
                height: _height,
                weight: _weight,
                availableGames: _availableGames,
                loading: _loading,
              ),
              StatusTab(pokemon: widget.pokemon),
              if (_hasMultipleForms) FormsTab(forms: _forms, loading: _loading),
              MovesTab(level: _movesLevel, mt: _movesMT, tutor: _movesTutor, egg: _movesEgg),
            ],
          )),
        ]),
      ),
    );
  }
}

// ─── ABA ABOUT NACIONAL ──────────────────────────────────────────

class _NacionalInfoTab extends StatelessWidget {
  final Pokemon pokemon;
  final List<Map<String, dynamic>> abilities, evoChain;
  final String category, flavorText, height, weight;
  final List<String> availableGames;
  final bool loading;

  const _NacionalInfoTab({
    required this.pokemon, required this.abilities, required this.evoChain,
    required this.category, required this.flavorText,
    required this.height, required this.weight,
    required this.availableGames, required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Espécies + descrição + altura/tipo/peso ──
        SectionCard(
          title: 'DESCRIÇÃO',
          pokemonTypes: pokemon.types,
          child: AboutHeader(
            category: category,
            flavorText: flavorText,
            height: height,
            weight: weight,
            types: pokemon.types,
            loading: loading,
          ),
        ),

        const SizedBox(height: 16),

        // ── Habilidades ──
        SectionCard(
          title: 'HABILIDADES',
          pokemonTypes: pokemon.types,
          loading: loading,
          child: abilities.isEmpty
              ? Text('Sem dados',
                  style: TextStyle(fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant))
              : Column(children: abilities.map((a) => AbilityCard(
                  nameEn: a['nameEn'] as String,
                  namePt: a['namePt'] as String? ?? '',
                  description: a['description'] as String,
                  isHidden: a['isHidden'] as bool,
                )).toList()),
        ),

        const SizedBox(height: 16),

        // ── Evoluções ──
        SectionCard(
          title: 'EVOLUÇÕES',
          pokemonTypes: pokemon.types,
          child: evoChain.isEmpty
              ? Text(loading ? 'Carregando...' : 'Sem dados',
                  style: TextStyle(fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant))
              : EvoChainWidget(chain: evoChain),
        ),

        const SizedBox(height: 16),

        // ── Disponível em ──
        SectionCard(
          title: 'DISPONÍVEL EM',
          pokemonTypes: pokemon.types,
          child: availableGames.isEmpty
              ? Text(loading ? 'Carregando...' : 'Dados não disponíveis.',
                  style: TextStyle(fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant))
              : Wrap(spacing: 8, runSpacing: 8,
                  children: availableGames.map((g) {
                    final typeColor = TypeColors.fromType(
                        ptType(pokemon.types.isNotEmpty ? pokemon.types[0] : 'normal'));
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8)),
                      child: Text(g, style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 11, fontWeight: FontWeight.w500)),
                    );
                  }).toList()),
        ),

        const SizedBox(height: 16),
      ]),
    );
  }
}