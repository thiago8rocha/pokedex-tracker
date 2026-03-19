import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart';

class NacionalDetailScreen extends StatefulWidget {
  final Pokemon pokemon;
  final bool caught;
  final VoidCallback onToggleCaught;

  const NacionalDetailScreen({
    super.key,
    required this.pokemon,
    required this.caught,
    required this.onToggleCaught,
  });

  @override
  State<NacionalDetailScreen> createState() => _NacionalDetailScreenState();
}

class _NacionalDetailScreenState extends State<NacionalDetailScreen>
    with SingleTickerProviderStateMixin {

  late bool _caught;
  late TabController _tabController;

  Map<String, dynamic>? _speciesData;
  Map<String, dynamic>? _pokemonData;
  List<Map<String, dynamic>> _abilities = [];
  List<Map<String, dynamic>> _evoChain = [];
  List<Map<String, dynamic>> _forms = [];
  List<Map<String, dynamic>> _movesLevel = [];
  List<Map<String, dynamic>> _movesMT = [];
  List<Map<String, dynamic>> _movesTutor = [];
  List<Map<String, dynamic>> _movesEgg = [];
  bool _loading = true;

  static const _tabs = ['Info', 'Status', 'Formas', 'Moves'];

  @override
  void initState() {
    super.initState();
    _caught = widget.caught;
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadAll();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    try {
      final r1 = await http.get(Uri.parse('$kApiBase/pokemon/${widget.pokemon.id}'));
      if (r1.statusCode == 200 && mounted) {
        final d = json.decode(r1.body) as Map<String, dynamic>;
        _pokemonData = d;
        _parseForms(d);
        _parseMoves(d);
        await _parseAbilities(d);
      }
      final r2 = await http.get(Uri.parse('$kApiBase/pokemon-species/${widget.pokemon.id}'));
      if (r2.statusCode == 200 && mounted) {
        final d = json.decode(r2.body) as Map<String, dynamic>;
        _speciesData = d;
        await _parseEvoChain(d);
        await _loadAlternateForms();
      }
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _parseAbilities(Map<String, dynamic> d) async {
    final raw = d['abilities'] as List<dynamic>;
    final result = <Map<String, dynamic>>[];
    for (final a in raw) {
      final nameEn = a['ability']['name'] as String;
      final isHidden = a['is_hidden'] as bool;
      String namePt = '', desc = '';
      try {
        final r = await http.get(Uri.parse(a['ability']['url'] as String));
        if (r.statusCode == 200) {
          final ad = json.decode(r.body) as Map<String, dynamic>;
          for (final n in (ad['names'] as List<dynamic>? ?? [])) {
            if ((n['language']['name'] as String) == 'pt-BR') {
              namePt = (n['name'] as String? ?? '').trim(); break;
            }
          }
          final flavors = ad['flavor_text_entries'] as List<dynamic>? ?? [];
          String ptDesc = '', enDesc = '';
          for (final e in flavors) {
            final lang = e['language']['name'] as String;
            if (lang == 'pt-BR' && ptDesc.isEmpty) ptDesc = (e['flavor_text'] as String? ?? '').replaceAll('\n', ' ').trim();
            else if (lang == 'en' && enDesc.isEmpty) enDesc = (e['flavor_text'] as String? ?? '').replaceAll('\n', ' ').trim();
          }
          desc = ptDesc.isNotEmpty ? ptDesc : enDesc.isNotEmpty ? enDesc : '';
          if (desc.isEmpty) {
            for (final e in (ad['effect_entries'] as List<dynamic>? ?? [])) {
              if ((e['language']['name'] as String) == 'en') { desc = (e['short_effect'] as String? ?? '').trim(); break; }
            }
          }
        }
      } catch (_) {}
      result.add({'nameEn': nameEn, 'namePt': namePt, 'description': desc, 'isHidden': isHidden});
    }
    if (mounted) setState(() => _abilities = result);
  }

  Future<void> _parseEvoChain(Map<String, dynamic> species) async {
    try {
      final url = species['evolution_chain']?['url'] as String?;
      if (url == null) return;
      final r = await http.get(Uri.parse(url));
      if (r.statusCode != 200) return;
      final d = json.decode(r.body) as Map<String, dynamic>;
      final chain = <Map<String, dynamic>>[];
      Map<String, dynamic>? cur = d['chain'] as Map<String, dynamic>?;
      while (cur != null) {
        final su = cur['species']['url'] as String;
        final parts = su.split('/');
        final id = int.tryParse(parts[parts.length - 2]) ?? 0;
        final name = cur['species']['name'] as String;
        final details = (cur['evolution_details'] as List<dynamic>?)?.firstOrNull;
        String cond = '';
        if (details != null) {
          final lvl = details['min_level'];
          final item = details['item']?['name'];
          final happiness = details['min_happiness'];
          if (lvl != null) cond = 'Nv. $lvl';
          else if (item != null) cond = item.toString().replaceAll('-', ' ');
          else if (happiness != null) cond = 'Amizade';
          else cond = 'Evoluir';
        }
        chain.add({'id': id, 'name': name, 'condition': cond});
        final next = cur['evolves_to'] as List<dynamic>;
        cur = next.isNotEmpty ? next[0] as Map<String, dynamic> : null;
      }
      if (mounted) setState(() => _evoChain = chain);
    } catch (_) {}
  }

  void _parseForms(Map<String, dynamic> d) {
    _forms = [{'name': widget.pokemon.name, 'id': widget.pokemon.id,
      'types': widget.pokemon.types, 'isDefault': true}];
    if (mounted) setState(() {});
  }

  Future<void> _loadAlternateForms() async {
    if (_speciesData == null) return;
    final varieties = _speciesData!['varieties'] as List<dynamic>? ?? [];
    if (varieties.length <= 1) return;
    const vgToGame = {
      'lets-go-pikachu-lets-go-eevee': "Let's Go P/E",
      'sword-shield': 'Sword / Shield',
      'brilliant-diamond-and-shining-pearl': 'BD / Shining Pearl',
      'legends-arceus': 'Legends: Arceus',
      'scarlet-violet': 'Scarlet / Violet',
    };
    final forms = <Map<String, dynamic>>[];
    for (final v in varieties) {
      final url = v['pokemon']['url'] as String;
      final name = v['pokemon']['name'] as String;
      try {
        final r = await http.get(Uri.parse(url));
        if (r.statusCode != 200) continue;
        final fd = json.decode(r.body) as Map<String, dynamic>;
        final fid = fd['id'] as int;
        final types = (fd['types'] as List<dynamic>).map((t) => t['type']['name'] as String).toList();
        String? gameLabel;
        final formsRaw = fd['forms'] as List<dynamic>? ?? [];
        if (formsRaw.isNotEmpty) {
          try {
            final rf = await http.get(Uri.parse(formsRaw[0]['url'] as String));
            if (rf.statusCode == 200) {
              final formData = json.decode(rf.body) as Map<String, dynamic>;
              final vgName = formData['version_group']?['name'] as String?;
              if (vgName != null) gameLabel = vgToGame[vgName];
            }
          } catch (_) {}
        }
        forms.add({'name': name, 'id': fid, 'types': types,
          'isDefault': v['is_default'] as bool, 'game': gameLabel});
      } catch (_) {}
    }
    forms.sort((a, b) {
      final aD = a['isDefault'] as bool, bD = b['isDefault'] as bool;
      if (aD && !bD) return -1; if (!aD && bD) return 1; return 0;
    });
    if (mounted) setState(() => _forms = forms);
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

  String get _height => _pokemonData == null ? '—'
      : '${((_pokemonData!['height'] as int) / 10).toStringAsFixed(1)} m';
  String get _weight => _pokemonData == null ? '—'
      : '${((_pokemonData!['weight'] as int) / 10).toStringAsFixed(1)} kg';
  String get _captureRate => _speciesData == null ? '—'
      : '${_speciesData!['capture_rate'] ?? '—'}';

  String get _category {
    if (_speciesData == null) return '—';
    final genera = _speciesData!['genera'] as List<dynamic>? ?? [];
    for (final g in genera) {
      if ((g['language']['name'] as String) == 'pt-BR') {
        return (g['genus'] as String).replaceAll(' Pokémon', '').replaceAll(' pokémon', '').trim();
      }
    }
    String en = '—';
    for (final g in genera) {
      if ((g['language']['name'] as String) == 'en') {
        en = (g['genus'] as String).replaceAll(' Pokémon', '').trim(); break;
      }
    }
    const tr = {
      'Seed': 'Semente', 'Lizard': 'Lagarto', 'Flame': 'Chama',
      'Tiny Turtle': 'Tartaruga Pequena', 'Turtle': 'Tartaruga',
      'Shellfish': 'Crustáceo', 'Worm': 'Verme', 'Cocoon': 'Casulo',
      'Butterfly': 'Borboleta', 'Mouse': 'Camundongo',
      'Fox': 'Raposa', 'Bird': 'Pássaro', 'Tiny Bird': 'Pássaro Pequeno',
      'Poison Bee': 'Abelha Venenosa', 'Drowsing': 'Sonolento',
      'Electric': 'Elétrico', 'Fire Horse': 'Cavalo de Fogo',
      'Amphibian': 'Anfíbio', 'Dragon': 'Dragão', 'Coral': 'Coral',
      'Genetic': 'Genético', 'New Species': 'Nova Espécie',
      'Fossil': 'Fóssil', 'Spiral': 'Espiral', 'Formidable': 'Formidável',
    };
    return tr[en] ?? en;
  }

  List<String> get _availableGames {
    if (_speciesData == null) return [];
    final gen = _speciesData!['generation']?['name'] as String? ?? '';
    const map = {
      'generation-i':    ["Let's Go P/E", 'FireRed / LeafGreen', 'Sword / Shield', 'BD / Shining Pearl', 'Scarlet / Violet', 'Legends: Arceus', 'Pokémon GO', 'Pokopia'],
      'generation-ii':   ['Sword / Shield', 'BD / Shining Pearl', 'Scarlet / Violet', 'Pokémon GO'],
      'generation-iii':  ['FireRed / LeafGreen', 'Sword / Shield', 'BD / Shining Pearl', 'Scarlet / Violet', 'Pokémon GO'],
      'generation-iv':   ['Sword / Shield', 'BD / Shining Pearl', 'Scarlet / Violet', 'Legends: Arceus', 'Pokémon GO'],
      'generation-v':    ['Sword / Shield', 'Scarlet / Violet', 'Pokémon GO'],
      'generation-vi':   ['Sword / Shield', 'Scarlet / Violet', 'Pokémon GO'],
      'generation-vii':  ['Sword / Shield', 'Scarlet / Violet', 'Pokémon GO'],
      'generation-viii': ['Sword / Shield', 'BD / Shining Pearl', 'Legends: Arceus', 'Pokémon GO'],
      'generation-ix':   ['Scarlet / Violet'],
    };
    return List<String>.from(map[gen] ?? []);
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
                height: _height,
                weight: _weight,
                captureRate: _captureRate,
                availableGames: _availableGames,
                loading: _loading,
              ),
              StatusTab(pokemon: widget.pokemon),
              FormsTab(forms: _forms, loading: _loading),
              MovesTab(level: _movesLevel, mt: _movesMT, tutor: _movesTutor, egg: _movesEgg),
            ],
          )),
        ]),
      ),
    );
  }
}

// ─── ABA INFO NACIONAL ───────────────────────────────────────────

class _NacionalInfoTab extends StatelessWidget {
  final Pokemon pokemon;
  final List<Map<String, dynamic>> abilities, evoChain;
  final String category, height, weight, captureRate;
  final List<String> availableGames;
  final bool loading;

  const _NacionalInfoTab({
    required this.pokemon, required this.abilities, required this.evoChain,
    required this.category, required this.height, required this.weight,
    required this.captureRate, required this.availableGames, required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final bg = neutralBg(context);
    final border = neutralBorder(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        secTitle(context, 'INFORMAÇÕES'),
        _infoTable(context, bg, border),
        const SizedBox(height: 16),
        secTitle(context, 'HABILIDADES'),
        if (loading)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
        else
          ...abilities.map((a) => AbilityCard(
            nameEn: a['nameEn'] as String, namePt: a['namePt'] as String? ?? '',
            description: a['description'] as String, isHidden: a['isHidden'] as bool,
          )),
        const SizedBox(height: 16),
        secTitle(context, 'EVOLUÇÕES'),
        if (evoChain.isEmpty)
          Text(loading ? 'Carregando...' : 'Sem dados',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant))
        else
          EvoChainWidget(chain: evoChain),
        const SizedBox(height: 16),
        secTitle(context, 'DISPONÍVEL EM'),
        if (availableGames.isEmpty)
          Text(loading ? 'Carregando...' : 'Dados não disponíveis.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))
        else
          Wrap(spacing: 8, runSpacing: 8, children: availableGames.map((g) =>
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
              child: Text(g, style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11, fontWeight: FontWeight.w500)),
            )).toList()),
      ]),
    );
  }

  Widget _infoTable(BuildContext ctx, Color bg, Color border) {
    final rows = [
      ['Categoria', category], ['Altura', height],
      ['Peso', weight], ['Taxa de captura', captureRate],
    ];
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(children: rows.asMap().entries.map((e) {
        final isLast = e.key == rows.length - 1;
        return Container(
          decoration: isLast ? null : BoxDecoration(
            border: Border(bottom: BorderSide(color: border, width: 0.5))),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(e.value[0], style: TextStyle(fontSize: 13,
              color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            Text(e.value[1], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        );
      }).toList()),
    );
  }
}