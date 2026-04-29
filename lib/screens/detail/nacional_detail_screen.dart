import 'package:flutter/material.dart';
import 'package:dexcurator/models/pokemon.dart';
import 'package:dexcurator/screens/detail/detail_shared.dart';
import 'package:dexcurator/services/pokedex_data_service.dart';
import 'package:dexcurator/services/pokeapi_service.dart';
import 'package:dexcurator/services/location_service.dart';
import 'package:dexcurator/services/storage_service.dart';
import 'package:dexcurator/translations.dart';

const Map<String, String> _kGameToPokedexId = {
  'Red / Blue':                        'red___blue',
  'Yellow':                            'yellow',
  'Gold / Silver':                     'gold___silver',
  'Crystal':                           'crystal',
  'Ruby / Sapphire':                   'ruby___sapphire',
  'FireRed / LeafGreen (GBA)':         'firered___leafgreen_(gba)',
  'Emerald':                           'emerald',
  'Diamond / Pearl':                   'diamond___pearl',
  'Platinum':                          'platinum',
  'HeartGold / SoulSilver':            'heartgold___soulsilver',
  'Black / White':                     'black___white',
  'Black 2 / White 2':                 'black_2___white_2',
  'X / Y':                             'x___y',
  'Omega Ruby / Alpha Sapphire':       'omega_ruby___alpha_sapphire',
  'Sun / Moon':                        'sun___moon',
  'Ultra Sun / Ultra Moon':            'ultra_sun___ultra_moon',
  "Let's Go Pikachu / Eevee":          'lets_go_pikachu___eevee',
  'Sword / Shield':                    'sword___shield',
  'Brilliant Diamond / Shining Pearl': 'brilliant_diamond___shining_pearl',
  'Legends: Arceus':                   'legends_arceus',
  'Scarlet / Violet':                  'scarlet___violet',
  'Legends: Z-A':                      'legends_z-a',
  'FireRed / LeafGreen':               'firered___leafgreen_(gba)',
  'Pokémon GO':                        'pokémon_go',
  'Pokopia':                           'pokopia',
};

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

  final String pokedexId;

  const NacionalDetailScreen({
    super.key,
    required this.pokemon,
    required this.caught,
    required this.onToggleCaught,
    required this.pokedexId,
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
  final PokeApiService _api = PokeApiService();
  List<Map<String, dynamic>> _movesLevel = [];
  List<Map<String, dynamic>> _movesMT = [];
  List<Map<String, dynamic>> _movesTutor = [];
  List<Map<String, dynamic>> _movesEgg = [];
  bool _loading = true;
  List<Map<String, dynamic>> _flavorTexts = [];
  Set<String>? _activePokedexIds; // null = todas ativas
  Map<String, List<Map<String, dynamic>>> _encounters = {};
  bool _loadingEncounters = true;

  bool get _hasMultipleForms => !_loading && _forms.length > 1;

  List<String> get _tabs => _hasMultipleForms
      ? ['Sobre', 'Status', 'Formas', 'Golpes']
      : ['Sobre', 'Status', 'Golpes'];

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

    // Flavor text do bundle como fallback imediato
    _flavorTexts = svc.getFlavorTexts(id);
    if (mounted) setState(() => _loading = false);



    // Carrega moves em background
    _api.fetchPokemon(id).then((d) {
      if (d != null && mounted) _parseMoves(d);
    });

    // Localizations from bundled asset
    final locationSvc = LocationService.instance;
    if (!locationSvc.isLoaded) await locationSvc.warmup();
    if (mounted) {
      final enc = <String, List<Map<String, dynamic>>>{};
      for (final dexId in locationSvc.getAvailableDexIds(id)) {
        enc[dexId] = locationSvc.getLocations(id, dexId);
      }
      setState(() { _encounters = enc; _loadingEncounters = false; });
    }
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


  // Categoria já vem traduzida do JSON
  String get _category => PokedexDataService.instance.getCategory(widget.pokemon.id);

  // Mapeamento: nome do jogo no JSON → pokedexId no storage
  static const Map<String, String> _gameToPokedexId = _kGameToPokedexId;

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
                pokedexId: widget.pokedexId,
                category: _category,
                flavorTexts: _flavorTexts,
                height: _height,
                weight: _weight,
                availableGames: _availableGames,
                loading: _loading,
                encounters: _encounters,
                loadingEncounters: _loadingEncounters,
                activePokedexIds: _activePokedexIds,
              ),
              StatusTab(pokemon: widget.pokemon),
              if (_hasMultipleForms) FormsTab(forms: _forms, loading: _loading),
              MovesTab(level: _movesLevel, mt: _movesMT, tutor: _movesTutor, egg: _movesEgg, pokemonTypes: widget.pokemon.types),
            ],
          )),
        ]),
      ),
    );
  }
}

// ─── ORDEM CRONOLÓGICA DE JOGOS ─────────────────────────────────

const _kGameOrder = [
  'red___blue', 'yellow', 'gold___silver', 'crystal',
  'ruby___sapphire', 'firered___leafgreen_(gba)', 'emerald',
  'diamond___pearl', 'platinum', 'heartgold___soulsilver',
  'black___white', 'black_2___white_2', 'x___y', 'omega_ruby___alpha_sapphire',
  'sun___moon', 'ultra_sun___ultra_moon', 'lets_go_pikachu___eevee',
  'sword___shield', 'brilliant_diamond___shining_pearl', 'legends:_arceus',
  'scarlet___violet', 'legends:_z-a',
];

const _kDexIdToGameName = <String, String>{
  'red___blue':                        'Red / Blue',
  'yellow':                            'Yellow',
  'gold___silver':                     'Gold / Silver',
  'crystal':                           'Crystal',
  'ruby___sapphire':                   'Ruby / Sapphire',
  'firered___leafgreen_(gba)':         'FireRed / LeafGreen',
  'emerald':                           'Emerald',
  'diamond___pearl':                   'Diamond / Pearl',
  'platinum':                          'Platinum',
  'heartgold___soulsilver':            'HeartGold / SoulSilver',
  'black___white':                     'Black / White',
  'black_2___white_2':                 'Black 2 / White 2',
  'x___y':                             'X / Y',
  'omega_ruby___alpha_sapphire':       'Omega Ruby / Alpha Sapphire',
  'sun___moon':                        'Sun / Moon',
  'ultra_sun___ultra_moon':            'Ultra Sun / Ultra Moon',
  'lets_go_pikachu___eevee':           "Let's Go Pikachu / Eevee",
  'sword___shield':                    'Sword / Shield',
  'brilliant_diamond___shining_pearl': 'Brilliant Diamond / Shining Pearl',
  'legends:_arceus':                   'Legends: Arceus',
  'scarlet___violet':                  'Scarlet / Violet',
  'legends:_z-a':                      'Legends: Z-A',
};

// ─── ABA ABOUT NACIONAL ──────────────────────────────────────────

class _NacionalInfoTab extends StatelessWidget {
  final Pokemon pokemon;
  final List<Map<String, dynamic>> abilities, evoChain;
  final List<Map<String, dynamic>> flavorTexts;
  final String category, height, weight, pokedexId;
  final List<String> availableGames;
  final bool loading;
  final Map<String, List<Map<String, dynamic>>> encounters;
  final bool loadingEncounters;
  final Set<String>? activePokedexIds;

  const _NacionalInfoTab({
    required this.pokemon, required this.abilities, required this.evoChain,
    required this.flavorTexts, required this.category,
    required this.height, required this.weight,
    required this.availableGames, required this.loading,
    required this.pokedexId,
    required this.encounters, required this.loadingEncounters,
    required this.activePokedexIds,
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
            flavorTexts: flavorTexts,
            height: height,
            weight: weight,
            types: pokemon.types,
            loading: loading,
            pokedexId: pokedexId,
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

        // ── Evoluções — só exibe se há evolução no jogo ativo ──
        if (!loading && filterEvoChainForGame(evoChain, pokedexId).length > 1) ...[
          SectionCard(
            title: 'EVOLUÇÕES',
            pokemonTypes: pokemon.types,
            child: EvoChainWidget(chain: evoChain, pokedexId: pokedexId),
          ),
          const SizedBox(height: 16),
        ],

        // ── Onde encontrar ──
        SectionCard(
          title: 'ONDE ENCONTRAR',
          pokemonTypes: pokemon.types,
          loading: loadingEncounters,
          child: _buildEncountersNacional(context),
        ),

        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildEncountersNacional(BuildContext context) {
    if (loadingEncounters) return const SizedBox(height: 40);

    final rows = <Widget>[];

    for (final dexId in _kGameOrder) {
      if (activePokedexIds != null && !activePokedexIds!.contains(dexId)) continue;

      final gameName = _kDexIdToGameName[dexId] ?? dexId;

      if (rows.isNotEmpty) rows.add(const Divider(height: 12, thickness: 0.5));

      final gameColor = dexColor(dexId);
      final gameTextColor = gameColor.computeLuminance() > 0.35
          ? Colors.black87 : Colors.white;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: gameColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(gameName,
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: gameTextColor, letterSpacing: 0.3)),
        ),
      ));

      final locs = encounters[dexId];
      if (locs == null || locs.isEmpty) {
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('Sem registro neste jogo.',
            style: TextStyle(fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ));
      } else {
        final regionGroups = groupEncountersByRegion(locs, dexId);
        if (regionGroups.length <= 1) {
          final groups = groupEncounters(locs);
          rows.add(Column(
            children: groups.values
                .map((g) => LocationRow(entries: g, pokemonTypes: pokemon.types))
                .toList(),
          ));
        } else {
          rows.add(Column(
            children: regionGroups.entries.map((e) => ExpandableRegionSection(
              region: e.key,
              groups: e.value,
              pokemonTypes: pokemon.types,
            )).toList(),
          ));
        }
      }
    }

    if (rows.isEmpty) {
      return Text(
        'Localizações não disponíveis para os jogos selecionados.',
        style: TextStyle(fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}