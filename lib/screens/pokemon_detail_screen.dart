import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/theme/type_colors.dart';

// ─── CONSTANTES ──────────────────────────────────────────────────

const String _base = 'https://pokeapi.co/api/v2';

String _ptType(String en) {
  const m = {
    'normal':'Normal','fire':'Fogo','water':'Água','electric':'Elétrico',
    'grass':'Planta','ice':'Gelo','fighting':'Lutador','poison':'Veneno',
    'ground':'Terreno','flying':'Voador','psychic':'Psíquico','bug':'Inseto',
    'rock':'Pedra','ghost':'Fantasma','dragon':'Dragão','dark':'Sombrio',
    'steel':'Aço','fairy':'Fada',
  };
  return m[en.toLowerCase()] ?? en;
}

Color _typeTextColor(Color bg) =>
    bg.computeLuminance() > 0.35 ? Colors.black87 : Colors.white;

Widget _secTitle(BuildContext context, String title) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(title, style: Theme.of(context).textTheme.labelSmall?.copyWith(
    letterSpacing: 0.8, color: Theme.of(context).colorScheme.onSurfaceVariant,
    fontWeight: FontWeight.w600, fontSize: 10,
  )),
);

// ─── MAIN SCREEN ─────────────────────────────────────────────────

class PokemonDetailScreen extends StatefulWidget {
  final Pokemon pokemon;
  final bool caught;
  final VoidCallback onToggleCaught;
  final String? pokedexContext; // 'go', 'pokopia', null=switch

  const PokemonDetailScreen({
    super.key, required this.pokemon, required this.caught,
    required this.onToggleCaught, this.pokedexContext,
  });

  @override
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen>
    with SingleTickerProviderStateMixin {

  late bool _caught;
  late TabController _tabController;

  // Data loaded from API
  Map<String, dynamic>? _speciesData;
  Map<String, dynamic>? _pokemonData;
  List<Map<String, dynamic>> _abilities = [];
  List<Map<String, dynamic>> _evoChain = [];
  List<Map<String, dynamic>> _forms = [];
  List<Map<String, dynamic>> _movesLevel = [];
  List<Map<String, dynamic>> _movesMT = [];
  List<Map<String, dynamic>> _movesTutor = [];
  List<Map<String, dynamic>> _movesEgg = [];
  bool _loadingExtra = true;

  List<String> get _tabLabels {
    if (widget.pokedexContext == 'pokopia') return ['Amigos', 'Habitats'];
    if (widget.pokedexContext == 'go') return ['Info', 'Status', 'Formas', 'Calc. CP'];
    return ['Info', 'Status', 'Formas', 'Moves'];
  }

  @override
  void initState() {
    super.initState();
    _caught = widget.caught;
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _loadAll();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  // ─── LOAD DATA ────────────────────────────────────────────────

  Future<void> _loadAll() async {
    try {
      // Pokémon data (height, weight, abilities, moves, forms)
      final r1 = await http.get(Uri.parse('$_base/pokemon/${widget.pokemon.id}'));
      if (r1.statusCode == 200 && mounted) {
        final d = json.decode(r1.body) as Map<String, dynamic>;
        _pokemonData = d;
        _parseForms(d);
        if (widget.pokedexContext != 'pokopia') _parseMoves(d);
        await _parseAbilities(d);
      }

      // Species data (category, capture rate, evolution chain)
      final r2 = await http.get(Uri.parse('$_base/pokemon-species/${widget.pokemon.id}'));
      if (r2.statusCode == 200 && mounted) {
        final d = json.decode(r2.body) as Map<String, dynamic>;
        _speciesData = d;
        await _parseEvoChain(d);
        await _loadAlternateForms();
      }

      if (mounted) setState(() => _loadingExtra = false);
    } catch (_) {
      if (mounted) setState(() => _loadingExtra = false);
    }
  }

  Future<void> _parseAbilities(Map<String, dynamic> d) async {
    final raw = d['abilities'] as List<dynamic>;
    final result = <Map<String, dynamic>>[];
    for (final a in raw) {
      final nameEn = a['ability']['name'] as String; // nome original EN (slug)
      final isHidden = a['is_hidden'] as bool;
      String namePt = '';
      String desc = '';
      try {
        final r = await http.get(Uri.parse(a['ability']['url'] as String));
        if (r.statusCode == 200) {
          final ad = json.decode(r.body) as Map<String, dynamic>;

          // Nome PT-BR via names[]
          final names = ad['names'] as List<dynamic>? ?? [];
          for (final n in names) {
            if ((n['language']['name'] as String) == 'pt-BR') {
              namePt = (n['name'] as String? ?? '').trim();
              break;
            }
          }

          // Descrição: flavor_text_entries PT-BR > EN > effect_entries EN
          final flavorEntries = ad['flavor_text_entries'] as List<dynamic>? ?? [];
          String ptDesc = '', enDesc = '';
          for (final e in flavorEntries) {
            final lang = e['language']['name'] as String;
            if (lang == 'pt-BR' && ptDesc.isEmpty) {
              ptDesc = (e['flavor_text'] as String? ?? '').replaceAll('\n', ' ').trim();
            } else if (lang == 'en' && enDesc.isEmpty) {
              enDesc = (e['flavor_text'] as String? ?? '').replaceAll('\n', ' ').trim();
            }
          }
          if (ptDesc.isNotEmpty) {
            desc = ptDesc;
          } else if (enDesc.isNotEmpty) {
            desc = enDesc;
          } else {
            final effectEntries = ad['effect_entries'] as List<dynamic>? ?? [];
            for (final e in effectEntries) {
              if ((e['language']['name'] as String) == 'en') {
                desc = (e['short_effect'] as String? ?? '').trim();
                break;
              }
            }
          }
        }
      } catch (_) {}
      result.add({
        'nameEn': nameEn,
        'namePt': namePt,
        'description': desc,
        'isHidden': isHidden,
      });
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
    // parseForms agora só guarda a forma base — as variantes são carregadas
    // em _loadForms depois que temos o speciesData
    final types = widget.pokemon.types;
    _forms = [{'name': widget.pokemon.name, 'id': widget.pokemon.id, 'types': types, 'isDefault': true}];
    if (mounted) setState(() {});
  }

  Future<void> _loadAlternateForms() async {
    if (_speciesData == null) return;
    final varieties = _speciesData!['varieties'] as List<dynamic>? ?? [];
    if (varieties.length <= 1) {
      // Sem formas alternativas
      if (mounted) setState(() {});
      return;
    }

    final forms = <Map<String, dynamic>>[];
    for (final v in varieties) {
      final url = v['pokemon']['url'] as String;
      final name = v['pokemon']['name'] as String;
      try {
        final r = await http.get(Uri.parse(url));
        if (r.statusCode == 200) {
          final fd = json.decode(r.body) as Map<String, dynamic>;
          final fid = fd['id'] as int;
          final typesRaw = fd['types'] as List<dynamic>;
          final types = typesRaw
              .map((t) => t['type']['name'] as String)
              .toList();
          forms.add({'name': name, 'id': fid, 'types': types, 'isDefault': v['is_default'] as bool});
        }
      } catch (_) {}
    }

    // Ordena: default primeiro
    forms.sort((a, b) {
      final aD = a['isDefault'] as bool;
      final bD = b['isDefault'] as bool;
      if (aD && !bD) return -1;
      if (!aD && bD) return 1;
      return 0;
    });

    if (mounted) setState(() => _forms = forms);
  }

  void _parseMoves(Map<String, dynamic> d) {
    final movesRaw = d['moves'] as List<dynamic>;
    final level = <Map<String, dynamic>>[];
    final mt = <Map<String, dynamic>>[];
    final tutor = <Map<String, dynamic>>[];
    final egg = <Map<String, dynamic>>[];

    for (final m in movesRaw) {
      final name = m['move']['name'] as String;
      final moveUrl = m['move']['url'] as String;
      final vgDetails = m['version_group_details'] as List<dynamic>;

      // Pega o método da versão mais recente disponível
      for (final vg in vgDetails.reversed) {
        final method = vg['move_learn_method']['name'] as String;
        final lvl = vg['level_learned_at'] as int;

        final entry = {
          'name': name,      // slug EN (ex: "vine-whip")
          'nameEn': name,    // guardado explicitamente
          'namePt': '',      // será preenchido ao abrir o modal (lazy)
          'url': moveUrl,
          'level': lvl,
          'method': method,
        };

        if (method == 'level-up') {
          level.add(entry);
          break;
        } else if (method == 'machine') {
          mt.add(entry);
          break;
        } else if (method == 'tutor') {
          tutor.add(entry);
          break;
        } else if (method == 'egg') {
          egg.add(entry);
          break;
        }
      }
    }

    level.sort((a, b) => (a['level'] as int).compareTo(b['level'] as int));

    if (mounted) setState(() {
      _movesLevel = level;
      _movesMT = mt;
      _movesTutor = tutor;
      _movesEgg = egg;
    });
  }

  // ─── ACCESSORS ────────────────────────────────────────────────

  String get _heightStr {
    if (_pokemonData == null) return '—';
    final h = _pokemonData!['height'] as int? ?? 0;
    return '${(h / 10).toStringAsFixed(1)} m';
  }

  String get _weightStr {
    if (_pokemonData == null) return '—';
    final w = _pokemonData!['weight'] as int? ?? 0;
    return '${(w / 10).toStringAsFixed(1)} kg';
  }

  String get _captureRate {
    if (_speciesData == null) return '—';
    return '${_speciesData!['capture_rate'] ?? '—'}';
  }

  String get _category {
    if (_speciesData == null) return '—';
    final genera = _speciesData!['genera'] as List<dynamic>? ?? [];

    // Tenta pt-BR nativo da API
    for (final g in genera) {
      if ((g['language']['name'] as String) == 'pt-BR') {
        final raw = g['genus'] as String;
        return raw.replaceAll(' Pokémon', '').replaceAll(' pokémon', '').trim();
      }
    }

    // Fallback EN → traduz manualmente as categorias mais comuns
    String enGenus = '—';
    for (final g in genera) {
      if ((g['language']['name'] as String) == 'en') {
        enGenus = (g['genus'] as String).replaceAll(' Pokémon', '').trim();
        break;
      }
    }

    // Dicionário de tradução das categorias mais comuns
    const translations = {
      'Seed': 'Semente', 'Lizard': 'Lagarto', 'Flame': 'Chama',
      'Tiny Turtle': 'Tartaruga Pequena', 'Turtle': 'Tartaruga',
      'Shellfish': 'Crustáceo', 'Worm': 'Verme', 'Cocoon': 'Casulo',
      'Butterfly': 'Borboleta', 'Hairy Bug': 'Inseto Peludo',
      'Poison Bee': 'Abelha Venenosa', 'Tiny Bird': 'Pássaro Pequeno',
      'Bird': 'Pássaro', 'Mouse': 'Camundongo', 'Pika': 'Pika',
      'Fox': 'Raposa', 'Rabbit': 'Coelho', 'Poison Pin': 'Espinho Venenoso',
      'Drill': 'Broca', 'Fairy': 'Fada', 'Pincer': 'Pinça',
      'Rock Snake': 'Cobra de Pedra', 'Drowsing': 'Sonolento',
      'Hypnosis': 'Hipnose', 'Punch': 'Soco', 'Licking': 'Lambedura',
      'Poison Gas': 'Gás Venenoso', 'Spikes': 'Espinhos',
      'Ball': 'Bola', 'Egg': 'Ovo', 'Coconut': 'Coco',
      'Lonely': 'Solitário', 'Bone Keeper': 'Guardador de Ossos',
      'Kicking': 'Chute', 'Punching': 'Soco', 'Lure': 'Isca',
      'Bone': 'Osso', 'Starmie': 'Starmie', 'Mysterious': 'Misterioso',
      'Barrier': 'Barreira', 'Jellyfish': 'Medusa', 'Star Shape': 'Estrela',
      'Starshape': 'Estrela', 'Scallop': 'Vieira', 'Clamp': 'Garra',
      'Water': 'Aquático', 'Sea Lion': 'Leão-Marinho', 'Dopey': 'Bobalhão',
      'Hermit Crab': 'Caranguejo Eremita', 'Dragon': 'Dragão',
      'Dragon Snake': 'Cobra-Dragão', 'Transport': 'Transporte',
      'Fossil': 'Fóssil', 'Wild Bull': 'Touro Selvagem',
      'Electric': 'Elétrico', 'Fire Horse': 'Cavalo de Fogo',
      'Fateful': 'Fatídico', 'Fog': 'Névoa', 'Genetic': 'Genético',
      'New Species': 'Nova Espécie', 'Spiral': 'Espiral',
      'Bubble Jet': 'Jato de Bolhas', 'Lightning': 'Relâmpago',
      'Virtual': 'Virtual', 'Telekinesis': 'Telecinese',
      'Amphibian': 'Anfíbio', 'Spiny Nut': 'Noz Espinhosa',
      'Verdant': 'Verdejante', 'Continent': 'Continente',
      'Season': 'Estação', 'Formidable': 'Formidável',
      'Iron Will': 'Força de Vontade', 'Colt': 'Potro',
      'Grassland': 'Pradaria', 'Herb': 'Erva', 'Coral': 'Coral',
      'Flowering': 'Florescendo', 'Synthesis': 'Síntese',
    };

    if (translations.containsKey(enGenus)) return translations[enGenus]!;
    // Retorna EN se não tem tradução
    return enGenus;
  }

  void _toggleCaught() { setState(() => _caught = !_caught); widget.onToggleCaught(); }

  // ─── BUILD ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pt = widget.pokemon.types.isNotEmpty ? widget.pokemon.types[0] : 'normal';
    final c1 = TypeColors.fromType(_ptType(pt));
    final c2 = widget.pokemon.types.length > 1
        ? TypeColors.fromType(_ptType(widget.pokemon.types[1])) : c1;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [_buildHeader(ctx, c1, c2)],
        body: Column(
          children: [
            Material(
              elevation: 0,
              child: TabBar(
                controller: _tabController,
                tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
                isScrollable: _tabLabels.length > 3,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabAlignment: _tabLabels.length > 3 ? TabAlignment.start : TabAlignment.fill,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: widget.pokedexContext == 'pokopia'
                    ? [_PokopiaBuddyTab(pokemon: widget.pokemon), _PokopiaHabitatsTab()]
                    : widget.pokedexContext == 'go'
                        ? [
                            _GoInfoTab(pokemon: widget.pokemon, pokemonData: _pokemonData, loading: _loadingExtra),
                            _StatusTab(pokemon: widget.pokemon),
                            _FormsTab(forms: _forms, loading: _loadingExtra),
                            _CpCalcTab(pokemon: widget.pokemon),
                          ]
                        : [
                            _InfoTab(
                              pokemon: widget.pokemon, abilities: _abilities, evoChain: _evoChain,
                              category: _category, height: _heightStr, weight: _weightStr,
                              captureRate: _captureRate, loading: _loadingExtra,
                              isNacional: widget.pokedexContext == 'nacional',
                            ),
                            _StatusTab(pokemon: widget.pokemon),
                            _FormsTab(forms: _forms, loading: _loadingExtra),
                            _MovesTab(
                              level: _movesLevel, mt: _movesMT,
                              tutor: _movesTutor, egg: _movesEgg,
                            ),
                          ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext ctx, Color c1, Color c2) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: c1,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          onPressed: _toggleCaught,
          icon: Icon(_caught ? Icons.catching_pokemon : Icons.catching_pokemon_outlined,
              color: Colors.white, size: 28),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [c1, c2.withOpacity(0.75)],
            ),
          ),
          child: SafeArea(
            child: Stack(children: [
              // Sprite fantasma grande no canto direito
              if (widget.pokemon.spriteUrl.isNotEmpty)
                Positioned(
                  right: -15, bottom: -5,
                  child: Opacity(
                    opacity: 0.2,
                    child: Image.network(widget.pokemon.spriteUrl,
                        width: 170, height: 170,
                        errorBuilder: (_, __, ___) => const SizedBox()),
                  ),
                ),
              // Layout principal: sprite + texto, alinhados na base
              Positioned(
                left: 16, right: 16, bottom: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Sprite principal
                    widget.pokemon.spriteUrl.isNotEmpty
                        ? Image.network(widget.pokemon.spriteUrl, width: 120, height: 120,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.catching_pokemon, size: 100, color: Colors.white))
                        : const Icon(Icons.catching_pokemon, size: 100, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('#${widget.pokemon.id.toString().padLeft(3, '0')}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12,
                              fontWeight: FontWeight.w500)),
                          Text(widget.pokemon.name,
                            style: const TextStyle(color: Colors.white, fontSize: 24,
                              fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 4,
                            children: widget.pokemon.types.map((t) {
                              final tc = TypeColors.fromType(_ptType(t));
                              final isSingle = widget.pokemon.types.length == 1;
                              return Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSingle ? 14 : 10,
                                  vertical: isSingle ? 5 : 3,
                                ),
                                decoration: BoxDecoration(
                                  color: tc,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(isSingle ? 0.6 : 0.25),
                                    width: isSingle ? 1.5 : 0.5,
                                  ),
                                  boxShadow: isSingle ? [BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4, offset: const Offset(0, 2),
                                  )] : null,
                                ),
                                child: Text(_ptType(t), style: TextStyle(
                                  color: _typeTextColor(tc),
                                  fontSize: isSingle ? 12 : 11,
                                  fontWeight: FontWeight.w700,
                                )),
                              );
                            }).toList()),
                          if (_caught) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.check, size: 10, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  widget.pokedexContext == 'pokopia' ? 'Amigo' : 'Capturado',
                                  style: const TextStyle(color: Colors.white, fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ],
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── ABA INFO (SWITCH) ───────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  final Pokemon pokemon;
  final List<Map<String, dynamic>> abilities;
  final List<Map<String, dynamic>> evoChain;
  final String category, height, weight, captureRate;
  final bool loading;
  final bool isNacional;

  const _InfoTab({
    required this.pokemon, required this.abilities, required this.evoChain,
    required this.category, required this.height, required this.weight,
    required this.captureRate, required this.loading, this.isNacional = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _secTitle(context, 'INFORMAÇÕES'),
        _infoTable(context, [
          ['Categoria', category],
          ['Altura', height],
          ['Peso', weight],
          ['Taxa de captura', captureRate],
        ]),
        const SizedBox(height: 16),
        // "ONDE ENCONTRAR" — só para jogos switch (não Nacional)
        if (!isNacional) ...[
          _secTitle(context, 'ONDE ENCONTRAR'),
          _WhereToFind(pokemonId: pokemon.id),
          const SizedBox(height: 16),
        ],
        _secTitle(context, 'HABILIDADES'),
        if (loading)
          const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (abilities.isEmpty)
          _empty(context, 'Carregando...')
        else
          ...abilities.map((a) => _AbilityCard(
            nameEn: a['nameEn'] as String,
            namePt: a['namePt'] as String? ?? '',
            description: a['description'] as String,
            isHidden: a['isHidden'] as bool,
          )),
        const SizedBox(height: 16),
        _secTitle(context, 'EVOLUÇÕES'),
        if (evoChain.isEmpty)
          _empty(context, 'Carregando...')
        else
          _EvoChainWidget(chain: evoChain),
        if (isNacional) ...[
          const SizedBox(height: 16),
          _secTitle(context, 'DISPONÍVEL EM'),
          _AvailableIn(pokemonId: pokemon.id),
        ],
      ]),
    );
  }

  Widget _infoTable(BuildContext ctx, List<List<String>> rows) {
    // Usa cor neutra explícita para evitar o rosa do colorSchemeSeed vermelho
    final bgColor = Theme.of(ctx).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFF5F5F5);
    final borderColor = Theme.of(ctx).brightness == Brightness.dark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFE0E0E0);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: rows.asMap().entries.map((entry) {
        final isLast = entry.key == rows.length - 1;
        return Container(
          decoration: isLast ? null : BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(entry.value[0], style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              )),
              Text(entry.value[1], style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              )),
            ],
          ),
        );
      }).toList()),
    );
  }

  Widget _empty(BuildContext ctx, String text) => Text(text,
    style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant));
}

// ─── ABA INFO (GO) ───────────────────────────────────────────────

class _GoInfoTab extends StatelessWidget {
  final Pokemon pokemon;
  final Map<String, dynamic>? pokemonData;
  final bool loading;

  const _GoInfoTab({required this.pokemon, required this.pokemonData, required this.loading});

  // CP máximo = floor((Atk+15) * sqrt(Def+15) * sqrt(HP+15) * CPM40^2 / 10)
  // CPM nível 40 = 0.7903
  int get _maxCp {
    final cpm40 = 0.7903;
    final cp = ((pokemon.baseAttack + 15) * _sqrt(pokemon.baseDefense + 15) *
        _sqrt(pokemon.baseHp + 15) * cpm40 * cpm40 / 10).floor();
    return cp < 10 ? 10 : cp;
  }

  double _sqrt(num n) {
    if (n <= 0) return 0;
    double x = n.toDouble();
    for (int i = 0; i < 30; i++) x = (x + n / x) / 2;
    return x;
  }

  @override
  Widget build(BuildContext context) {
    final neutralBg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    final borderColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Stats GO + CP máx
        _secTitle(context, 'STATS POKÉMON GO'),
        Container(
          decoration: BoxDecoration(color: neutralBg, borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Row(children: [
              _statBox(context, '${pokemon.baseAttack}', 'Ataque'),
              Container(width: 0.5, height: 40, color: borderColor),
              _statBox(context, '${pokemon.baseDefense}', 'Defesa'),
              Container(width: 0.5, height: 40, color: borderColor),
              _statBox(context, '${pokemon.baseHp}', 'HP'),
            ]),
            Divider(height: 0.5, color: borderColor),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('CP Máximo (Nível 40)', style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
                Text('$_maxCp', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Evoluções com custo em doces
        _secTitle(context, 'EVOLUÇÕES'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: neutralBg, borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            _evoGoRow(context, pokemon.id, pokemon.name, null),
            Divider(height: 12, color: borderColor),
            _evoGoRow(context, pokemon.id + 1, 'Evolução 1', 25),
            Divider(height: 12, color: borderColor),
            _evoGoRow(context, pokemon.id + 2, 'Evolução 2', 100),
          ]),
        ),
        const SizedBox(height: 16),

        // Disponibilidade em grid 2x2
        _secTitle(context, 'DISPONIBILIDADE'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.8,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _availCell(context, 'Shiny', '✓ Disponível', const Color(0xFF34C759)),
            _availCell(context, 'Shadow', '✓ GO Rocket', const Color(0xFFFF9500)),
            _availCell(context, 'Regional', '✗ Global', Colors.red),
            _availCell(context, 'Lucky', 'Via troca', const Color(0xFFFFCC00)),
          ],
        ),
        const SizedBox(height: 16),

        // Como obter
        _secTitle(context, 'COMO OBTER'),
        _obtainCard(context, Icons.catching_pokemon_outlined, const Color(0xFF4a9020),
            'Encontro selvagem', 'Ambientes urbanos e parques'),
        const SizedBox(height: 8),
        _obtainCard(context, Icons.star_border_outlined, const Color(0xFFc8a020),
            'Raid de 3 estrelas', 'Disponível como chefe de raid'),
        const SizedBox(height: 16),

        // Variantes
        _secTitle(context, 'VARIANTES'),
        Row(children: [
          _variantCard(context, pokemon.id, 'Normal', true),
          const SizedBox(width: 8),
          _variantCard(context, pokemon.id, 'Shiny', true),
          const SizedBox(width: 8),
          _variantCard(context, pokemon.id, 'Shadow', false),
        ]),
      ]),
    );
  }

  Widget _evoGoRow(BuildContext ctx, int id, String name, int? candyCost) {
    final sprite = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png';
    return Row(children: [
      Image.network(sprite, width: 40, height: 40,
          errorBuilder: (_, __, ___) => const Icon(Icons.catching_pokemon, size: 32)),
      const SizedBox(width: 10),
      Expanded(child: Text(name[0].toUpperCase() + name.substring(1),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      if (candyCost != null) Row(children: [
        const Text('🍬', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 3),
        Text('$candyCost', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]) else
        Text('Base', style: TextStyle(fontSize: 11,
          color: ctx.isDark ? Colors.grey : Colors.grey.shade600)),
    ]);
  }

  Widget _availCell(BuildContext ctx, String label, String value, Color color) {
    final neutralBg = ctx.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: neutralBg, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(fontSize: 10,
          color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  Widget _statBox(BuildContext ctx, String val, String lbl) {
    return Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(lbl, style: TextStyle(fontSize: 10,
          color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
      ]),
    ));
  }

  Widget _obtainCard(BuildContext ctx, IconData icon, Color iconColor, String title, String sub) {
    final neutralBg = ctx.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: neutralBg, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(sub, style: TextStyle(fontSize: 11,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
        ]),
      ]),
    );
  }

  Widget _variantCard(BuildContext ctx, int id, String label, bool available) {
    final sprite = label == 'Shiny'
        ? 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/shiny/$id.png'
        : 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png';
    final neutralBg = ctx.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    return Expanded(child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: neutralBg, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Image.network(sprite, width: 52, height: 52,
            errorBuilder: (_, __, ___) => const Icon(Icons.catching_pokemon, size: 40)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(ctx).textTheme.labelSmall?.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          available ? '✓' : '—',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: available ? Colors.green : Theme.of(ctx).colorScheme.onSurfaceVariant),
        ),
      ]),
    ));
  }
}

extension _BuildContextX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ─── ABA STATUS ──────────────────────────────────────────────────

class _StatusTab extends StatelessWidget {
  final Pokemon pokemon;
  const _StatusTab({required this.pokemon});

  @override
  Widget build(BuildContext context) {
    final wk = _calculateWeaknesses(pokemon.types);
    final fraq = wk.entries.where((e) => e.value > 1.0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final resist = wk.entries.where((e) => e.value > 0 && e.value < 1.0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final imun = wk.entries.where((e) => e.value == 0.0).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _secTitle(context, 'STATUS BASE'),
        _StatBar(label: 'HP', value: pokemon.baseHp, color: const Color(0xFF5a9e5a)),
        _StatBar(label: 'Ataque', value: pokemon.baseAttack, color: const Color(0xFFE24B4A)),
        _StatBar(label: 'Defesa', value: pokemon.baseDefense, color: const Color(0xFF378ADD)),
        _StatBar(label: 'At. Especial', value: pokemon.baseSpAttack, color: const Color(0xFF9C27B0)),
        _StatBar(label: 'Def. Especial', value: pokemon.baseSpDefense, color: const Color(0xFF378ADD)),
        _StatBar(label: 'Velocidade', value: pokemon.baseSpeed, color: const Color(0xFFEF9F27)),
        Align(alignment: Alignment.centerRight, child: Text(
          'Total: ${pokemon.totalStats}',
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
        )),
        const SizedBox(height: 16),
        _secTitle(context, 'FRAQUEZAS E RESISTÊNCIAS'),
        if (fraq.isNotEmpty) ...[
          _wkLabel(context, 'Fraquezas'),
          const SizedBox(height: 6),
          _TypeChipRow(entries: fraq, style: 'weakness'),
          const SizedBox(height: 10),
        ],
        if (resist.isNotEmpty) ...[
          _wkLabel(context, 'Resistências'),
          const SizedBox(height: 6),
          _TypeChipRow(entries: resist, style: 'resist'),
          const SizedBox(height: 10),
        ],
        if (imun.isNotEmpty) ...[
          _wkLabel(context, 'Imunidades'),
          const SizedBox(height: 6),
          _TypeChipRow(entries: imun, style: 'immune'),
        ],
      ]),
    );
  }

  Widget _wkLabel(BuildContext ctx, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 0),
    child: Text(label, style: TextStyle(
      fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    )),
  );
}

class _TypeChipRow extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final String style; // 'weakness', 'resist', 'immune'
  const _TypeChipRow({required this.entries, required this.style});

  String _mult(double v) {
    if (v == 0) return '×0';
    if (v == 4) return '×4';
    if (v == 2) return '×2';
    if (v == 0.5) return '×½';
    if (v == 0.25) return '×¼';
    return '×${v.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 6, children: entries.map((e) {
      final typeColor = TypeColors.fromType(e.key);
      // Fraqueza: cor plena; resistência/imunidade: mais suave
      final opacity = style == 'weakness' ? 1.0 : style == 'resist' ? 0.7 : 0.55;
      final bg = typeColor.withOpacity(opacity);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${e.key} ${_mult(e.value)}',
          style: TextStyle(
            color: _typeTextColor(bg),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }).toList());
  }
}

// ─── ABA FORMAS ──────────────────────────────────────────────────

class _FormsTab extends StatelessWidget {
  final List<Map<String, dynamic>> forms;
  final bool loading;
  const _FormsTab({required this.forms, required this.loading});

  @override
  Widget build(BuildContext context) {
    // Carregando
    if (loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    // Sem formas alternativas (apenas a forma base)
    final altForms = forms.where((f) => !(f['isDefault'] as bool? ?? false)).toList();
    if (altForms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.catching_pokemon_outlined, size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Este Pokémon não possui formas alternativas',
              style: TextStyle(fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
          ]),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.05,
      ),
      itemCount: forms.length,
      itemBuilder: (ctx, i) {
        final f = forms[i];
        final id = f['id'] as int;
        final name = f['name'] as String;
        final types = f['types'] as List<dynamic>? ?? [];
        final typeStrs = types.map((t) => t as String).toList();
        final sprite = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';
        final c1 = typeStrs.isNotEmpty ? TypeColors.fromType(_ptType(typeStrs[0])) : Colors.grey;
        final c2 = typeStrs.length > 1 ? TypeColors.fromType(_ptType(typeStrs[1])) : c1;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [c1.withOpacity(0.2), c2.withOpacity(0.1)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c1.withOpacity(0.3), width: 0.8),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Image.network(sprite, width: 72, height: 72,
                errorBuilder: (_, __, ___) => const Icon(Icons.catching_pokemon, size: 50)),
            const SizedBox(height: 6),
            Text(
              _formatFormName(name),
              style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600, fontSize: 11,
              ),
              maxLines: 2, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Wrap(spacing: 4, children: typeStrs.map((t) {
              final tc = TypeColors.fromType(_ptType(t));
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: tc, borderRadius: BorderRadius.circular(8)),
                child: Text(_ptType(t), style: TextStyle(
                  fontSize: 8, color: _typeTextColor(tc), fontWeight: FontWeight.w700,
                )),
              );
            }).toList()),
          ]),
        );
      },
    );
  }

  // Formata nome de forma: "charizard-mega-x" → "Mega Charizard X"
  String _formatFormName(String raw) {
    final parts = raw.split('-');
    if (parts.contains('mega')) {
      final idx = parts.indexOf('mega');
      final rest = parts.sublist(idx + 1).map((p) => p[0].toUpperCase() + p.substring(1)).join(' ');
      final base = parts.sublist(0, idx).map((p) => p[0].toUpperCase() + p.substring(1)).join(' ');
      return 'Mega $base${rest.isNotEmpty ? ' $rest' : ''}';
    }
    if (parts.contains('gmax')) {
      final base = parts.where((p) => p != 'gmax').map((p) => p[0].toUpperCase() + p.substring(1)).join(' ');
      return 'Gigamax $base';
    }
    return parts.map((p) => p[0].toUpperCase() + p.substring(1)).join(' ');
  }
}

// ─── ABA MOVES ───────────────────────────────────────────────────

class _MovesTab extends StatefulWidget {
  final List<Map<String, dynamic>> level, mt, tutor, egg;
  const _MovesTab({required this.level, required this.mt, required this.tutor, required this.egg});

  @override
  State<_MovesTab> createState() => _MovesTabState();
}

class _MovesTabState extends State<_MovesTab> {
  String _method = 'level';
  Map<String, dynamic>? _selectedMove;
  Map<String, dynamic>? _moveDetail;
  bool _loadingMove = false;

  List<Map<String, dynamic>> get _currentMoves {
    switch (_method) {
      case 'mt': return widget.mt;
      case 'tutor': return widget.tutor;
      case 'egg': return widget.egg;
      default: return widget.level;
    }
  }

  Future<void> _openMove(Map<String, dynamic> move) async {
    setState(() { _selectedMove = move; _loadingMove = true; _moveDetail = null; });
    try {
      final r = await http.get(Uri.parse(move['url'] as String));
      if (r.statusCode == 200 && mounted) {
        setState(() {
          _moveDetail = json.decode(r.body) as Map<String, dynamic>;
          _loadingMove = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMove = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Column(children: [
        // Sub-abas de método
        SizedBox(height: 44, child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          children: [
            for (final entry in [('level', 'Nível'), ('mt', 'MT'), ('tutor', 'Tutor'), ('egg', 'Ovo')])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _method = entry.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: _method == entry.$1
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Text(entry.$2, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: _method == entry.$1
                          ? Theme.of(context).colorScheme.surface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
                  ),
                ),
              ),
          ],
        )),
        // Cabeçalho de colunas — alinhado exatamente com as linhas
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
          child: Row(children: [
            SizedBox(
              width: _method == 'level' ? 32 : 40,
              child: Text(
                _method == 'level' ? 'NV' : _method == 'mt' ? 'MT' : '',
                style: const TextStyle(fontSize: 9, color: Color(0xFF888888),
                  letterSpacing: 0.06, fontWeight: FontWeight.w500),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            const SizedBox(width: 42,
              child: Text('TIPO', style: TextStyle(fontSize: 9, color: Color(0xFF888888),
                letterSpacing: 0.06, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
            const SizedBox(width: 8),
            const SizedBox(width: 16), // ícone categoria
            const SizedBox(width: 8),
            const Expanded(child: Text('MOVE', style: TextStyle(fontSize: 9,
              color: Color(0xFF888888), letterSpacing: 0.06, fontWeight: FontWeight.w500))),
            const SizedBox(width: 36,
              child: Text('PODER', style: TextStyle(fontSize: 9, color: Color(0xFF888888),
                letterSpacing: 0.06, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
            const SizedBox(width: 18), // seta
          ]),
        ),
        Divider(height: 0.5, color: Theme.of(context).colorScheme.outlineVariant),
        // Legenda dos ícones de categoria
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            _CatLegendItem(category: 'physical', label: 'Físico'),
            const SizedBox(width: 12),
            _CatLegendItem(category: 'special', label: 'Especial'),
            const SizedBox(width: 12),
            _CatLegendItem(category: 'status', label: 'Status'),
          ]),
        ),
        Divider(height: 0.5, color: Theme.of(context).colorScheme.outlineVariant),
        if (_currentMoves.isEmpty)
          Expanded(child: Center(child: Text(
            widget.level.isEmpty ? 'Carregando...' : 'Nenhum move',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          )))
        else
          Expanded(child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _currentMoves.length,
            separatorBuilder: (_, __) => Divider(
              height: 0.5, color: Theme.of(context).colorScheme.outlineVariant),
            itemBuilder: (ctx, i) => _MoveRow(
              move: _currentMoves[i], method: _method,
              onTap: () => _openMove(_currentMoves[i]),
            ),
          )),
      ]),
      if (_selectedMove != null)
        _MoveModal(
          move: _selectedMove!,
          detail: _moveDetail,
          loading: _loadingMove,
          onClose: () => setState(() { _selectedMove = null; _moveDetail = null; }),
        ),
    ]);
  }
}

class _MoveRow extends StatefulWidget {
  final Map<String, dynamic> move;
  final String method;
  final VoidCallback onTap;
  const _MoveRow({required this.move, required this.method, required this.onTap});

  @override
  State<_MoveRow> createState() => _MoveRowState();
}

class _MoveRowState extends State<_MoveRow> {
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final r = await http.get(Uri.parse(widget.move['url'] as String));
      if (r.statusCode == 200 && mounted) {
        final data = json.decode(r.body) as Map<String, dynamic>;
        // Busca nome PT-BR no array names
        String namePt = '';
        final names = data['names'] as List<dynamic>? ?? [];
        for (final n in names) {
          if ((n['language']['name'] as String) == 'pt-BR') {
            namePt = (n['name'] as String? ?? '').trim();
            break;
          }
        }
        // Atualiza namePt no mapa do move (mutação local apenas para exibição)
        if (namePt.isNotEmpty) {
          widget.move['namePt'] = namePt;
        }
        setState(() => _detail = data);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final nameEn = widget.move['name'] as String;
    final namePt = widget.move['namePt'] as String? ?? '';
    final displayName = namePt.isNotEmpty
        ? namePt
        : nameEn[0].toUpperCase() + nameEn.substring(1).replaceAll('-', ' ');
    final enLabel = nameEn[0].toUpperCase() + nameEn.substring(1).replaceAll('-', ' ');
    final showEn = namePt.isNotEmpty && namePt != enLabel;

    final level = widget.move['level'] as int;
    final typeEn = _detail?['type']?['name'] as String? ?? '';
    final typePt = _ptType(typeEn);
    final typeColor = TypeColors.fromType(typePt);
    final catName = _detail?['damage_class']?['name'] as String? ?? '';
    final power = _detail?['power'] as int?;
    final powerStr = power != null ? '$power' : '—';

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          SizedBox(
            width: widget.method == 'level' ? 32 : 40,
            child: Text(
              widget.method == 'level'
                  ? (level > 0 ? '$level' : '1')
                  : widget.method == 'mt'
                      ? level.toString().padLeft(3, '0')
                      : '',
              style: TextStyle(
                fontSize: widget.method == 'level' ? 11 : 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          // Badge de tipo
          Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: typeEn.isEmpty ? Colors.grey.withOpacity(0.2) : typeColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              typeEn.isEmpty ? '···' : typePt,
              style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w600,
                color: typeEn.isEmpty ? Colors.grey : _typeTextColor(typeColor),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          // Ícone de categoria
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              color: catName == 'physical' ? const Color(0xFFE24B4A).withOpacity(0.15)
                  : catName == 'special' ? const Color(0xFF9C27B0).withOpacity(0.15)
                  : const Color(0xFF888888).withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: CustomPaint(painter: _CatIconPainter(catName)),
          ),
          const SizedBox(width: 8),
          // Nome: PT em destaque, EN em subtexto discreto
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(displayName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis, maxLines: 1),
              if (showEn)
                Text(enLabel,
                  style: TextStyle(fontSize: 9,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
            ],
          )),
          // Poder — largura fixa 36 para evitar quebra de linha
          SizedBox(
            width: 36,
            child: Text(
              powerStr,
              style: TextStyle(
                fontSize: 11,
                color: powerStr == '—'
                    ? Theme.of(context).colorScheme.onSurfaceVariant : null,
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.chevron_right, size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ]),
      ),
    );
  }
}

// Ícones de categoria: punho laranja (físico), bola azul (especial), losango cinza (status)
class _CatIconPainter extends CustomPainter {
  final String category;
  const _CatIconPainter(this.category);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    if (category == 'physical') {
      final paint = Paint()..color = const Color(0xFFE24B4A);
      final path = Path()
        ..moveTo(cx - 4, cy + 3)
        ..lineTo(cx - 4, cy - 2)
        ..lineTo(cx - 2, cy - 4)
        ..lineTo(cx + 2, cy - 4)
        ..lineTo(cx + 4, cy - 2)
        ..lineTo(cx + 4, cy + 3)
        ..close();
      canvas.drawPath(path, paint);
    } else if (category == 'special') {
      canvas.drawCircle(Offset(cx, cy), 4.5, Paint()..color = const Color(0xFF378ADD));
    } else {
      final paint = Paint()..color = const Color(0xFFB8B8D0);
      final path = Path()
        ..moveTo(cx, cy - 5)
        ..lineTo(cx + 4, cy)
        ..lineTo(cx, cy + 5)
        ..lineTo(cx - 4, cy)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// Modal de detalhes do move
class _MoveModal extends StatelessWidget {
  final Map<String, dynamic> move;
  final Map<String, dynamic>? detail;
  final bool loading;
  final VoidCallback onClose;

  const _MoveModal({required this.move, required this.detail,
    required this.loading, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final nameEn = move['name'] as String;
    final namePt = move['namePt'] as String? ?? '';
    final displayName = namePt.isNotEmpty
        ? namePt
        : nameEn[0].toUpperCase() + nameEn.substring(1).replaceAll('-', ' ');
    final enLabel = nameEn[0].toUpperCase() + nameEn.substring(1).replaceAll('-', ' ');
    final showEnSub = namePt.isNotEmpty && namePt != enLabel;
    final typeEn = detail?['type']?['name'] as String? ?? '';
    final typePt = _ptType(typeEn);
    final typeColor = TypeColors.fromType(typePt);
    final catName = detail?['damage_class']?['name'] as String? ?? '';
    final power = detail?['power'];
    final acc = detail?['accuracy'];
    final pp = detail?['pp'];
    final level = move['level'] as int;
    final method = move['method'] as String;

    // Descrição em PT-BR > EN (flavor_text_entries) > effect_entries EN
    String desc = '';
    if (detail != null) {
      final flavorEntries = detail!['flavor_text_entries'] as List<dynamic>? ?? [];
      String ptDesc = '', enDesc = '';
      for (final e in flavorEntries) {
        final lang = e['language']['name'] as String;
        if (lang == 'pt-BR' && ptDesc.isEmpty) {
          ptDesc = (e['flavor_text'] as String? ?? '').replaceAll('\n', ' ').trim();
        } else if (lang == 'en' && enDesc.isEmpty) {
          enDesc = (e['flavor_text'] as String? ?? '').replaceAll('\n', ' ').trim();
        }
      }
      if (ptDesc.isNotEmpty) {
        desc = ptDesc;
      } else if (enDesc.isNotEmpty) {
        desc = enDesc;
      } else {
        for (final e in (detail!['effect_entries'] as List<dynamic>? ?? [])) {
          if ((e['language']['name'] as String) == 'en') {
            desc = (e['short_effect'] as String? ?? '').trim();
            break;
          }
        }
      }
    }

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black54,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    if (showEnSub)
                      Text(enLabel, style: TextStyle(
                        fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                )),
                GestureDetector(onTap: onClose,
                  child: Icon(Icons.close,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                if (typeEn.isNotEmpty) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: typeColor,
                    borderRadius: BorderRadius.circular(12)),
                  child: Text(typePt, style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: _typeTextColor(typeColor),
                  )),
                ),
                const SizedBox(width: 8),
                if (catName.isNotEmpty) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: catName == 'physical'
                        ? const Color(0xFFE24B4A).withOpacity(0.15)
                        : catName == 'special'
                            ? const Color(0xFF9C27B0).withOpacity(0.15)
                            : const Color(0xFF888888).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: catName == 'physical'
                          ? const Color(0xFFE24B4A).withOpacity(0.4)
                          : catName == 'special'
                              ? const Color(0xFF9C27B0).withOpacity(0.4)
                              : const Color(0xFF888888).withOpacity(0.4),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    catName == 'physical' ? 'Ataque Físico'
                        : catName == 'special' ? 'Ataque Especial'
                        : 'Ataque de Status',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: catName == 'physical' ? const Color(0xFFE24B4A)
                          : catName == 'special' ? const Color(0xFF9C27B0)
                          : const Color(0xFF666666),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (loading)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else
                Row(children: [
                  _statBox(context, power != null ? '$power' : '—', 'Poder'),
                  const SizedBox(width: 8),
                  _statBox(context, acc != null ? '$acc%' : '—', 'Precisão'),
                  const SizedBox(width: 8),
                  _statBox(context, pp != null ? '$pp' : '—', 'PP'),
                ]),
              const SizedBox(height: 12),
              if (desc.isNotEmpty) Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(desc, style: TextStyle(fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5)),
              ),
              const SizedBox(height: 8),
              Text(
                method == 'level-up' && level > 0 ? 'Aprendido no nível $level'
                    : method == 'machine' ? 'Aprendido via MT'
                    : method == 'tutor' ? 'Aprendido via Tutor'
                    : method == 'egg' ? 'Move de Ovo'
                    : '',
                style: TextStyle(fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _statBox(BuildContext ctx, String val, String lbl) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(lbl, style: TextStyle(fontSize: 10,
          color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
      ]),
    ),
  );
}

// ─── CP CALC (GO) ────────────────────────────────────────────────

class _CpCalcTab extends StatefulWidget {
  final Pokemon pokemon;
  const _CpCalcTab({required this.pokemon});

  @override
  State<_CpCalcTab> createState() => _CpCalcTabState();
}

class _CpCalcTabState extends State<_CpCalcTab> {
  String _mode = 'evo';
  double _currentCp = 500;
  double _level = 25;
  int _ivAtk = 15, _ivDef = 15, _ivHp = 15;

  static const List<double> _cpm = [
    0.094,0.1351,0.1663,0.192,0.2126,0.2295,0.2436,0.2557,0.2663,0.2756,
    0.2839,0.2913,0.298,0.3041,0.3096,0.3145,0.319,0.323,0.3267,0.33,
    0.3331,0.3359,0.3385,0.3408,0.343,0.345,0.3469,0.3486,0.3502,0.3517,
    0.3531,0.3544,0.3556,0.3567,0.3578,0.3587,0.3596,0.3604,0.3612,0.3619,
    0.3625,0.3631,0.3637,0.3642,0.3647,0.3652,0.3657,0.3661,0.3665,0.3669,
    0.37,
  ];

  double _sqrtApprox(num n) {
    if (n <= 0) return 0;
    double x = n.toDouble();
    for (int i = 0; i < 30; i++) x = (x + n / x) / 2;
    return x;
  }

  int _calcCp(int ba, int bd, int bh, double lvl, int ia, int id, int ih) {
    final idx = ((lvl - 1) * 2).round().clamp(0, _cpm.length - 1);
    final cpm = _cpm[idx];
    final cp = ((ba + ia) * _sqrtApprox(bd + id) * _sqrtApprox(bh + ih) * cpm * cpm / 10).floor();
    return cp < 10 ? 10 : cp;
  }

  @override
  Widget build(BuildContext context) {
    final ba = widget.pokemon.baseAttack;
    final bd = widget.pokemon.baseDefense;
    final bh = widget.pokemon.baseHp;
    final cpCalc = _calcCp(ba, bd, bh, _level, _ivAtk, _ivDef, _ivHp);
    final maxCp = _calcCp(ba, bd, bh, 40, 15, 15, 15);
    final evo1Cp = (_currentCp * 1.815).round();
    final evo2Cp = (_currentCp * 3.293).round();

    final neutralBg = context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Seletor de modo
        Container(
          decoration: BoxDecoration(
            color: neutralBg, borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            for (final entry in [('evo', 'Evolução'), ('iv', 'IVs exatos')])
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _mode = entry.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _mode == entry.$1
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(entry.$2,
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500,
                      color: _mode == entry.$1
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center),
                ),
              )),
          ]),
        ),
        const SizedBox(height: 16),
        if (_mode == 'evo') ...[
          Text('Informe o CP atual para estimar o CP após evoluir',
            style: TextStyle(fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('CP atual (${widget.pokemon.name})',
              style: const TextStyle(fontSize: 12)),
            Text(_currentCp.toInt().toString(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          Slider(
            value: _currentCp,
            min: 10, max: (maxCp * 0.85).toDouble(),
            onChanged: (v) => setState(() => _currentCp = v),
          ),
          const SizedBox(height: 8),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 8),
          Text('CP estimado após evolução:',
            style: TextStyle(fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Row(children: [
            _evoBox(context, evo1Cp.toString(), 'Evolução 1'),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward, size: 18, color: Colors.grey)),
            _evoBox(context, evo2Cp.toString(), 'Evolução 2'),
          ]),
          const SizedBox(height: 10),
          Text(
            '* Estimativa baseada nos multiplicadores de evolução. O CP real pode variar ±5%.',
            style: TextStyle(fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ] else ...[
          _sliderRow('Nível',
            _level.toStringAsFixed(_level % 1 == 0 ? 0 : 1),
            1, 50, _level,
            (v) => setState(() => _level = (v * 2).round() / 2)),
          _sliderRow('IV Ataque', '$_ivAtk', 0, 15, _ivAtk.toDouble(),
            (v) => setState(() => _ivAtk = v.round())),
          _sliderRow('IV Defesa', '$_ivDef', 0, 15, _ivDef.toDouble(),
            (v) => setState(() => _ivDef = v.round())),
          _sliderRow('IV HP', '$_ivHp', 0, 15, _ivHp.toDouble(),
            (v) => setState(() => _ivHp = v.round())),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 8),
          Center(child: Column(children: [
            Text('$cpCalc',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600)),
            Text('Combat Power (${widget.pokemon.name})',
              style: TextStyle(fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
        ],
      ]),
    );
  }

  Widget _evoBox(BuildContext ctx, String val, String lbl) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(ctx).colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(children: [
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        Text(lbl, style: TextStyle(fontSize: 10,
          color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
      ]),
    ),
  );

  Widget _sliderRow(String label, String valStr, num min, num max,
      double val, ValueChanged<double> onChanged) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(valStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
      Slider(
        value: val, min: min.toDouble(), max: max.toDouble(),
        divisions: (max - min).round(), onChanged: onChanged,
      ),
    ]);
  }
}

// ─── POKOPIA TABS ────────────────────────────────────────────────

class _PokopiaBuddyTab extends StatelessWidget {
  final Pokemon pokemon;
  const _PokopiaBuddyTab({required this.pokemon});

  @override
  Widget build(BuildContext context) {
    final neutralBg = context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    final borderColor = context.isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _secTitle(context, 'APARIÇÃO'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            _aparRow(context, 'Raridade', borderColor,
              widget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3DE), borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Comum', style: TextStyle(
                  color: Color(0xFF3B6D11), fontSize: 10, fontWeight: FontWeight.w500,
                )),
              )),
            _aparRow(context, 'Horário', borderColor, value: 'Manhã / Dia'),
            _aparRow(context, 'Clima', borderColor,
              value: 'Ensolarado / Nublado', isLast: true),
          ]),
        ),
        const SizedBox(height: 16),
        _secTitle(context, 'HABITAT IDEAL'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: neutralBg, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFAEEDA), borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.wb_sunny_outlined, color: Color(0xFFc8a020), size: 20),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Iluminado',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(width: 5),
                Text('(Bright)', style: TextStyle(fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
              Text('Prefere habitats ao ar livre ou bem iluminados',
                style: TextStyle(fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        _secTitle(context, 'SABOR FAVORITO'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: neutralBg, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Doce', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6,
              children: ['Salada de frutas', 'Bolo de mel', 'Suco de Pecha Berry']
                .map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 0.5),
                  ),
                  child: Text(s, style: TextStyle(fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                )).toList()),
          ]),
        ),
        const SizedBox(height: 16),
        _secTitle(context, 'COISAS FAVORITAS'),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            ['Muita natureza', 'Lots of nature'],
            ['Coisas macias', 'Soft stuff'],
            ['Coisas fofas', 'Cute stuff'],
            ['Muita água', 'Lots of water'],
            ['Atividades em grupo', 'Group activities'],
          ].asMap().entries.map((e) {
            final isLast = e.key == 4;
            return Container(
              decoration: isLast ? null : BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(e.value[0], style: const TextStyle(fontSize: 13)),
                Text(e.value[1], style: TextStyle(fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            );
          }).toList()),
        ),
        const SizedBox(height: 16),
        _secTitle(context, 'ESPECIALIDADES'),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: neutralBg, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: const Icon(Icons.eco_outlined, color: Color(0xFF4a9020), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Grow', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(
              'Acelera o crescimento de flores, árvores, plantas e colheitas nas proximidades.',
              style: TextStyle(fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
            ),
          ])),
        ]),
      ]),
    );
  }

  Widget _aparRow(BuildContext ctx, String label, Color borderColor,
      {String? value, Widget? widget, bool isLast = false}) {
    return Container(
      decoration: isLast ? null : BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13,
          color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
        widget ?? Text(value ?? '',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _PokopiaHabitatsTab extends StatelessWidget {
  const _PokopiaHabitatsTab();

  static const List<Map<String, dynamic>> _habitats = [
    {'name': 'Parques e jardins', 'nameEn': 'Parks & gardens', 'iconColor': Color(0xFF4a9020)},
    {'name': 'Áreas urbanas', 'nameEn': 'Urban areas', 'iconColor': Color(0xFF607D8B)},
    {'name': 'Campos abertos', 'nameEn': 'Open fields', 'iconColor': Color(0xFF8BC34A)},
    {'name': 'Florestas', 'nameEn': 'Forests', 'iconColor': Color(0xFF388E3C)},
  ];

  @override
  Widget build(BuildContext context) {
    final neutralBg = context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    final borderColor = context.isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _secTitle(context, 'HABITATS'),
        Text('Locais onde este Pokémon pode ser encontrado em Pokopia.',
          style: TextStyle(fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        ..._habitats.map((h) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: neutralBg, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: (h['iconColor'] as Color).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.place_outlined, color: h['iconColor'] as Color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h['name'] as String,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(h['nameEn'] as String, style: TextStyle(fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ]),
        )),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Dados completos de habitat serão carregados do arquivo JSON local de curadoria.',
              style: TextStyle(fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ─── HELPERS COMPARTILHADOS ──────────────────────────────────────

class _AbilityCard extends StatelessWidget {
  final String nameEn, namePt, description;
  final bool isHidden;
  const _AbilityCard({
    required this.nameEn, required this.namePt,
    required this.description, required this.isHidden,
  });

  // Formata o nome PT: "Crescimento Solar" ou "Solar Power" (se sem tradução)
  String get _displayName {
    if (namePt.isNotEmpty) return namePt;
    return nameEn[0].toUpperCase() + nameEn.substring(1).replaceAll('-', ' ');
  }

  // Nome EN formatado para o subtexto
  String get _enName =>
      nameEn[0].toUpperCase() + nameEn.substring(1).replaceAll('-', ' ');

  @override
  Widget build(BuildContext context) {
    final neutralBg = context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    // Tag "Oculta": cinza neutro, sem depender do colorScheme
    const hiddenBg = Color(0xFFE8E8E8);
    const hiddenText = Color(0xFF555555);
    const hiddenBgDark = Color(0xFF3A3A3A);
    const hiddenTextDark = Color(0xFFAAAAAA);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: neutralBg, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Nome PT em destaque
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_displayName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              // Nome EN em subtexto discreto (só mostra se tem PT diferente do EN)
              if (namePt.isNotEmpty && namePt != _enName)
                Text(_enName, style: TextStyle(
                  fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
            ],
          )),
          if (isHidden) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: context.isDark ? hiddenBgDark : hiddenBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Oculta', style: TextStyle(
                color: context.isDark ? hiddenTextDark : hiddenText,
                fontSize: 10, fontWeight: FontWeight.w500,
              )),
            ),
          ],
        ]),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(description, style: TextStyle(fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4)),
        ],
      ]),
    );
  }
}

class _EvoChainWidget extends StatelessWidget {
  final List<Map<String, dynamic>> chain;
  // currentId removido — sem destacar o Pokémon atual
  const _EvoChainWidget({required this.chain});

  @override
  Widget build(BuildContext context) {
    final neutralBg = context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: neutralBg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _buildWidgets(context),
      ),
    );
  }

  List<Widget> _buildWidgets(BuildContext ctx) {
    final List<Widget> ws = [];
    for (int i = 0; i < chain.length; i++) {
      final e = chain[i];
      final id = e['id'] as int;
      final name = e['name'] as String;
      final sprite = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/'
          'sprites/pokemon/other/official-artwork/$id.png';

      ws.add(Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Image.network(sprite, width: 52, height: 52,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.catching_pokemon, size: 40)),
        ),
        const SizedBox(height: 4),
        Text(
          name[0].toUpperCase() + name.substring(1),
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w400),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
      ]));

      if (i < chain.length - 1) {
        final cond = chain[i + 1]['condition'] as String;
        ws.add(Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.arrow_forward_ios, size: 10,
              color: Theme.of(ctx).colorScheme.onSurfaceVariant),
          if (cond.isNotEmpty) Text(cond, style: TextStyle(fontSize: 9,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center),
        ])));
      }
    }
    return ws;
  }
}

class _AvailableIn extends StatelessWidget {
  final int pokemonId;
  const _AvailableIn({required this.pokemonId});

  @override
  Widget build(BuildContext context) {
    final games = <String>[];
    if (pokemonId <= 151) games.addAll(["Let's Go P/E", 'FireRed / LG']);
    if (pokemonId <= 386) games.add('BD / SP');
    games.addAll(['Sword / Shield', 'Scarlet / Violet', 'Pokémon GO', 'Nacional']);
    if (pokemonId <= 242) games.add('Legends: Arceus');

    final neutralBg = context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    return Wrap(spacing: 8, runSpacing: 8, children: games.map((g) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: neutralBg, borderRadius: BorderRadius.circular(8)),
      child: Text(g, style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize: 11, fontWeight: FontWeight.w500,
      )),
    )).toList());
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 88, child: Text(label, style: TextStyle(fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant))),
        SizedBox(width: 34, child: Text('$value',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          textAlign: TextAlign.right)),
        const SizedBox(width: 8),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value / 255,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        )),
      ]),
    );
  }
}

// ─── FRAQUEZAS ───────────────────────────────────────────────────

Map<String, double> _calculateWeaknesses(List<String> types) {
  const tc = {
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
  final mults = <String, double>{};
  for (final type in types) {
    for (final entry in (tc[type.toLowerCase()] ?? {}).entries) {
      final k = _ptType(entry.key);
      mults[k] = (mults[k] ?? 1.0) * entry.value;
    }
  }
  return mults;
}

// ─── LEGENDA ÍCONES DE CATEGORIA ─────────────────────────────────

class _CatLegendItem extends StatelessWidget {
  final String category;
  final String label;
  const _CatLegendItem({required this.category, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 14, height: 14,
        decoration: BoxDecoration(
          color: category == 'physical' ? const Color(0xFFE24B4A).withOpacity(0.15)
              : category == 'special' ? const Color(0xFF9C27B0).withOpacity(0.15)
              : const Color(0xFF888888).withOpacity(0.15),
          borderRadius: BorderRadius.circular(3),
        ),
        child: CustomPaint(painter: _CatIconPainter(category)),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
        fontSize: 9, color: Theme.of(context).colorScheme.onSurfaceVariant,
      )),
    ]);
  }
}

// ─── ONDE ENCONTRAR (jogos switch) ───────────────────────────────

class _WhereToFind extends StatefulWidget {
  final int pokemonId;
  const _WhereToFind({required this.pokemonId});

  @override
  State<_WhereToFind> createState() => _WhereToFindState();
}

class _WhereToFindState extends State<_WhereToFind> {
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;

  // Traduz método de encontro para PT
  String _ptMethod(String method) {
    const map = {
      'walk': 'Caminhada',
      'grass-tiles': 'Grama alta',
      'surf': 'Surf',
      'old-rod': 'Vara velha',
      'good-rod': 'Boa vara',
      'super-rod': 'Super vara',
      'gift': 'Presente',
      'gift-egg': 'Ovo presente',
      'only-one': 'Único',
      'pokeradar': 'PokéRadar',
      'cave': 'Caverna',
      'headbutt': 'Headbutt',
      'rock-smash': 'Smash Pedra',
      'trade': 'Troca',
    };
    return map[method] ?? method.replaceAll('-', ' ');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse(
          'https://pokeapi.co/api/v2/pokemon/${widget.pokemonId}/encounters'));
      if (r.statusCode == 200 && mounted) {
        final data = json.decode(r.body) as List<dynamic>;
        final locs = <Map<String, dynamic>>[];
        for (final e in data.take(6)) { // limita a 6 locais
          final locName = (e['location_area']['name'] as String)
              .replaceAll('-', ' ')
              .split(' ')
              .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
              .join(' ');
          final versionDetails = e['version_details'] as List<dynamic>;
          if (versionDetails.isEmpty) continue;
          final detail = versionDetails.last;
          final chance = detail['max_chance'] as int? ?? 0;
          final methodRaw = (detail['encounter_details'] as List<dynamic>?)
              ?.firstOrNull?['method']?['name'] as String? ?? 'walk';
          locs.add({
            'name': locName,
            'method': _ptMethod(methodRaw),
            'chance': '$chance%',
          });
        }
        if (mounted) setState(() { _locations = locs; _loading = false; });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neutralBg = context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    final borderColor = context.isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0);

    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: neutralBg, borderRadius: BorderRadius.circular(10)),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_locations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: neutralBg, borderRadius: BorderRadius.circular(10)),
        child: Text(
          'Localização não disponível neste jogo.',
          style: TextStyle(fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: _locations.asMap().entries.map((entry) {
        final isLast = entry.key == _locations.length - 1;
        final loc = entry.value;
        return Container(
          decoration: isLast ? null : BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc['name'] as String,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(loc['method'] as String,
                  style: TextStyle(fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3DE), borderRadius: BorderRadius.circular(8),
              ),
              child: Text(loc['chance'] as String,
                style: const TextStyle(fontSize: 10, color: Color(0xFF3B6D11),
                  fontWeight: FontWeight.w500)),
            ),
          ]),
        );
      }).toList()),
    );
  }
}