import 'package:flutter/material.dart';
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart';
import 'package:pokedex_tracker/services/pokedex_data_service.dart';
import 'package:pokedex_tracker/translations.dart';

class SwitchDetailScreen extends StatefulWidget {
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

  const SwitchDetailScreen({
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
  State<SwitchDetailScreen> createState() => _SwitchDetailScreenState();
}

class _SwitchDetailScreenState extends State<SwitchDetailScreen>
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

  String get _height => PokedexDataService.instance.getHeight(widget.pokemon.id);
  String get _weight => PokedexDataService.instance.getWeight(widget.pokemon.id);
  String get _captureRate {
    final rate = PokedexDataService.instance.getCaptureRate(widget.pokemon.id);
    return rate > 0 ? '$rate' : '—';
  }

  String get _flavorText => _flavorTextPt;
  // Categoria já vem traduzida do JSON
  String get _category => PokedexDataService.instance.getCategory(widget.pokemon.id);

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
              _SwitchInfoTab(
                pokemon: widget.pokemon,
                abilities: _abilities,
                evoChain: _evoChain,
                category: _category,
                flavorText: _flavorText,
                height: _height,
                weight: _weight,
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

// ─── ABA ABOUT MAINLINE ───────────────────────────────────────────

class _SwitchInfoTab extends StatelessWidget {
  final Pokemon pokemon;
  final List<Map<String, dynamic>> abilities, evoChain;
  final String category, flavorText, height, weight;
  final bool loading;

  const _SwitchInfoTab({
    required this.pokemon, required this.abilities, required this.evoChain,
    required this.category, required this.flavorText,
    required this.height, required this.weight,
    required this.loading,
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

        // ── Onde encontrar ──
        SectionCard(
          title: 'ONDE ENCONTRAR',
          pokemonTypes: pokemon.types,
          child: _whereToFindPlaceholder(context),
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
      ]),
    );
  }

  Widget _whereToFindPlaceholder(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: neutralBg(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: neutralBorder(context), width: 0.5),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(
          'Localizações específicas por jogo serão adicionadas via curadoria.',
          style: TextStyle(fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
        )),
      ]),
    );
  }
}