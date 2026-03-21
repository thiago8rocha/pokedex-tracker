import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart';
import 'package:pokedex_tracker/services/pokedex_data_service.dart';
import 'package:pokedex_tracker/services/pokemon_cache_service.dart';
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

    // ── Dados locais (sem rede) ────────────────────────────────────
    if (svc.isLoaded && svc.get(id) != null) {
      _abilities = svc.getAbilities(id).map((a) => {
        'nameEn'     : a['nameEn'] as String,
        'namePt'     : translateAbility(a['nameEn'] as String),
        'description': a['description'] as String? ?? '',
        'isHidden'   : a['isHidden'] as bool,
      }).toList();

      _evoChain = svc.getEvoChain(id);

      final flavorEn = svc.getFlavorEn(id);
      String translated = await PokemonCacheService.instance.getTranslation(flavorEn) ?? '';
      if (translated.isEmpty && flavorEn.isNotEmpty) {
        translated = await translateFlavorText(flavorEn);
        if (translated.isNotEmpty) {
          await PokemonCacheService.instance.setTranslation(flavorEn, translated);
        }
      }
      _flavorTextPt = translated.isNotEmpty ? translated : flavorEn;

      if (mounted) setState(() => _loading = false);
      return;
    }

    // ── Fallback: chamada de rede ──────────────────────────────────
    final cache = PokemonCacheService.instance;
    try {
      var pokemonData = await cache.getPokemon(id);
      if (pokemonData == null) {
        final r = await http.get(Uri.parse('$kApiBase/pokemon/$id'));
        if (r.statusCode == 200) {
          pokemonData = json.decode(r.body) as Map<String, dynamic>;
          await cache.setPokemon(id, pokemonData);
        }
      }
      if (pokemonData != null && mounted) {
        _pokemonData = pokemonData;
        _parseForms(pokemonData);
        _parseMoves(pokemonData);
        await _parseAbilities(pokemonData);
      }

      var speciesData = await cache.getSpecies(id);
      if (speciesData == null) {
        final r = await http.get(Uri.parse('$kApiBase/pokemon-species/$id'));
        if (r.statusCode == 200) {
          speciesData = json.decode(r.body) as Map<String, dynamic>;
          await cache.setSpecies(id, speciesData);
        }
      }
      if (speciesData != null && mounted) {
        _speciesData = speciesData;
        await _parseEvoChain(speciesData);
        await _loadAlternateForms();
        final rawFlavor = extractFlavorText(
          speciesData['flavor_text_entries'] as List<dynamic>? ?? [],
          widget.pokedexId,
        );
        String translated = await cache.getTranslation(rawFlavor) ?? '';
        if (translated.isEmpty) {
          translated = await translateFlavorText(rawFlavor);
          if (translated.isNotEmpty) await cache.setTranslation(rawFlavor, translated);
        }
        if (mounted) setState(() => _flavorTextPt = translated);
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
      final namePt = translateAbility(nameEn);
      String desc = '';
      try {
        final abilityUrl = a['ability']['url'] as String;
        var ad = await PokemonCacheService.instance.getAbility(abilityUrl);
        if (ad == null) {
          final r = await http.get(Uri.parse(abilityUrl));
          if (r.statusCode == 200) {
            ad = json.decode(r.body) as Map<String, dynamic>;
            await PokemonCacheService.instance.setAbility(abilityUrl, ad);
          }
        }
        if (ad != null) {
          final flavors = ad['flavor_text_entries'] as List<dynamic>? ?? [];
          String ptDesc = '', enDesc = '';
          for (final e in flavors) {
            final lang = e['language']['name'] as String;
            if (lang == 'pt-BR' && ptDesc.isEmpty) ptDesc = (e['flavor_text'] as String? ?? '').replaceAll('\n', ' ').trim();
            else if (lang == 'en' && enDesc.isEmpty) enDesc = (e['flavor_text'] as String? ?? '').replaceAll('\n', ' ').trim();
          }
          desc = ptDesc.isNotEmpty ? ptDesc : enDesc;
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
      final cache = PokemonCacheService.instance;

      var d = await cache.getEvoChain(url);
      if (d == null) {
        final r = await http.get(Uri.parse(url));
        if (r.statusCode != 200) return;
        d = json.decode(r.body) as Map<String, dynamic>;
        await cache.setEvoChain(url, d);
      }

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
        List<String> types = [];
        try {
          var pd = await cache.getPokemon(id);
          if (pd == null) {
            final rp = await http.get(Uri.parse('$kApiBase/pokemon/$id'));
            if (rp.statusCode == 200) {
              pd = json.decode(rp.body) as Map<String, dynamic>;
              await cache.setPokemon(id, pd);
            }
          }
          if (pd != null) {
            types = (pd['types'] as List<dynamic>)
                .map((t) => t['type']['name'] as String)
                .toList();
          }
        } catch (_) {}
        chain.add({'id': id, 'name': name, 'condition': cond, 'types': types});
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
    final forms = <Map<String, dynamic>>[];
    for (final v in varieties) {
      final url  = v['pokemon']['url'] as String;
      final name = v['pokemon']['name'] as String;
      try {
        final r = await http.get(Uri.parse(url));
        if (r.statusCode != 200) continue;
        final fd    = json.decode(r.body) as Map<String, dynamic>;
        final fid   = fd['id'] as int;
        final types = (fd['types'] as List<dynamic>)
            .map((t) => t['type']['name'] as String).toList();
        final gameLabel = gameForForm(name);
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

  String get _height => _pokemonData == null ? '—'
      : '${((_pokemonData!['height'] as int) / 10).toStringAsFixed(1)} m';
  String get _weight => _pokemonData == null ? '—'
      : '${((_pokemonData!['weight'] as int) / 10).toStringAsFixed(1)} kg';
  String get _captureRate => _speciesData == null ? '—'
      : '${_speciesData!['capture_rate'] ?? '—'}';

  String get _flavorText => _flavorTextPt;
  String get _category {
    if (_speciesData == null) return '—';
    final genera = _speciesData!['genera'] as List<dynamic>? ?? [];
    for (final g in genera) {
      if ((g['language']['name'] as String) == 'pt-BR') {
        return (g['genus'] as String).replaceAll(' Pokémon', '').trim();
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
      'Shellfish': 'Crustáceo', 'Mouse': 'Camundongo', 'Bird': 'Pássaro',
      'Amphibian': 'Anfíbio', 'Dragon': 'Dragão', 'Fossil': 'Fóssil',
    };
    return tr[en] ?? en;
  }

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