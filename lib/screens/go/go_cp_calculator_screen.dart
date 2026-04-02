import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:dexcurator/core/app_constants.dart';
import 'package:dexcurator/services/pokedex_data_service.dart';

// ─── MODELOS ─────────────────────────────────────────────────────

class _PokemonGoData {
  final int id;
  final String name;
  final int goAtk, goDef, goSta;
  final List<_EvoTarget> evolutions;

  const _PokemonGoData({
    required this.id, required this.name,
    required this.goAtk, required this.goDef, required this.goSta,
    this.evolutions = const [],
  });

  double _sqrt(num n) {
    if (n <= 0) return 0;
    double x = n.toDouble();
    for (int i = 0; i < 30; i++) x = (x + n / x) / 2;
    return x;
  }

  int get maxCp {
    const cpm40 = 0.7903;
    final cp = ((goAtk + 15) * _sqrt(goDef + 15) * _sqrt(goSta + 15) * cpm40 * cpm40 / 10).floor();
    return cp < 10 ? 10 : cp;
  }
}

class _EvoTarget {
  final String name;
  final _PokemonGoData? data;
  const _EvoTarget({required this.name, this.data});
}

// ─── TELA ────────────────────────────────────────────────────────

class GoCpCalculatorScreen extends StatefulWidget {
  const GoCpCalculatorScreen({super.key});
  @override
  State<GoCpCalculatorScreen> createState() => _GoCpCalculatorScreenState();
}

class _GoCpCalculatorScreenState extends State<GoCpCalculatorScreen>
    with SingleTickerProviderStateMixin {

  // ── Controllers ──────────────────────────────────────────────
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  final _cpController = TextEditingController(text: '500');

  // ── Estado compartilhado ──────────────────────────────────────
  _PokemonGoData? _pokemon;
  bool _loadingPokemon = false;
  String? _pokemonError;

  // ── Busca / dropdown ─────────────────────────────────────────
  List<Map<String, dynamic>> _searchResults = [];
  bool _showDropdown = false;
  List<Map<String, dynamic>> _allPokemon = [];   // lista de {name, id}

  // ── Estado aba IVs ────────────────────────────────────────────
  double _level = 25;
  int _ivAtk = 15, _ivDef = 15, _ivHp = 15;

  // ── Cache de stats GO ─────────────────────────────────────────
  final Map<int, _PokemonGoData> _cache = {};

  // ── Tabela CPM ───────────────────────────────────────────────
  static const List<double> _cpm = [
    0.094,0.1351,0.1663,0.192,0.2126,0.2295,0.2436,0.2557,0.2663,0.2756,
    0.2839,0.2913,0.298,0.3041,0.3096,0.3145,0.319,0.323,0.3267,0.33,
    0.3331,0.3359,0.3385,0.3408,0.343,0.345,0.3469,0.3486,0.3502,0.3517,
    0.3531,0.3544,0.3556,0.3567,0.3578,0.3587,0.3596,0.3604,0.3612,0.3619,
    0.3625,0.3631,0.3637,0.3642,0.3647,0.3652,0.3657,0.3661,0.3665,0.3669,
    0.37,
  ];

  // ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPokemonList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cpController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Carrega lista do pokedex_data local ──────────────────────
  Future<void> _loadPokemonList() async {
    try {
      final raw  = await rootBundle.loadString('assets/data/pokemon_names.json');
      final map  = json.decode(raw) as Map<String, dynamic>;
      final list = map.entries.map((e) {
        final id   = int.tryParse(e.key) ?? 0;
        final name = (e.value as String).toLowerCase().replaceAll(' ', '-');
        return {'name': name, 'id': id};
      }).toList();
      list.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
      if (mounted) setState(() => _allPokemon = list);
    } catch (_) {}
  }

  // ── Busca por nome parcial ────────────────────────────────────
  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() { _searchResults = []; _showDropdown = false; });
      return;
    }
    if (_allPokemon.isNotEmpty) {
      final results = _allPokemon
          .where((p) => (p['name'] as String).contains(q))
          .take(8)
          .toList();
      setState(() { _searchResults = results; _showDropdown = results.isNotEmpty; });
    }
  }

  // ── Helpers de cálculo ────────────────────────────────────────
  double _sqrt(num n) {
    if (n <= 0) return 0;
    double x = n.toDouble();
    for (int i = 0; i < 30; i++) x = (x + n / x) / 2;
    return x;
  }

  int _calcCp(int ba, int bd, int bs, double lvl, int ia, int id_, int is_) {
    final idx = ((lvl - 1) * 2).round().clamp(0, _cpm.length - 1);
    final cp = ((ba + ia) * _sqrt(bd + id_) * _sqrt(bs + is_) * _cpm[idx] * _cpm[idx] / 10).floor();
    return cp < 10 ? 10 : cp;
  }

  // Fórmula correta de evolução — cancela CPM e IVs
  int _calcEvoCp(int cpAtual, _PokemonGoData base, _PokemonGoData evo) {
    final num = (evo.goAtk + 15) * _sqrt(evo.goDef + 15) * _sqrt(evo.goSta + 15);
    final den = (base.goAtk + 15) * _sqrt(base.goDef + 15) * _sqrt(base.goSta + 15);
    return (cpAtual * num / den).floor();
  }

  int get _cpResult {
    if (_pokemon == null) return 0;
    return _calcCp(_pokemon!.goAtk, _pokemon!.goDef, _pokemon!.goSta,
        _level, _ivAtk, _ivDef, _ivHp);
  }

  // ── Busca stats GO do pokemon_stats.json local ───────────────
  static Map<String, dynamic>? _statsMapData;
  Future<_PokemonGoData?> _fetchGoData(int id, String name) async {
    if (_cache.containsKey(id)) return _cache[id];
    try {
      // Carregar pokemon_stats.json uma vez
      _statsMapData ??= json.decode(
          await rootBundle.loadString('assets/data/pokemon_stats.json'))
          as Map<String, dynamic>;
      final s = _statsMapData![id.toString()] as Map<String, dynamic>?;
      if (s != null) {
        final data = _PokemonGoData(
          id: id, name: name,
          goAtk: (s['go_atk'] as num).toInt(),
          goDef: (s['go_def'] as num).toInt(),
          goSta: (s['go_sta'] as num).toInt(),
        );
        _cache[id] = data;
        return data;
      }
    } catch (_) {}
    // Fallback: API
    try {
      final r = await http.get(Uri.parse('${kPokeApiBase}/pokemon/$id'));
      if (r.statusCode == 200) {
        final d = json.decode(r.body) as Map<String, dynamic>;
        final stats = d['stats'] as List<dynamic>;
        int atk = 0, spatk = 0, def = 0, spdef = 0, hp = 0, spd = 0;
        for (final s in stats) {
          final base = (s['base_stat'] as num).toInt();
          switch (s['stat']['name'] as String) {
            case 'attack':          atk   = base; break;
            case 'special-attack':  spatk = base; break;
            case 'defense':         def   = base; break;
            case 'special-defense': spdef = base; break;
            case 'hp':              hp    = base; break;
            case 'speed':           spd   = base; break;
          }
        }
        final speedMod = 1 + (spd - 75) / 500;
        final goAtk = ((7 * (atk >= spatk ? atk : spatk) + (atk < spatk ? atk : spatk)) / 8 * speedMod * 2).round().clamp(1, 999);
        final goDef = ((5 * (def >= spdef ? def : spdef) + 3 * (def < spdef ? def : spdef)) / 8 * speedMod * 2).round().clamp(1, 999);
        final goSta = (hp * 1.75 + 50).floor().clamp(20, 9999);
        final data = _PokemonGoData(id: id, name: name, goAtk: goAtk, goDef: goDef, goSta: goSta);
        _cache[id] = data;
        return data;
      }
    } catch (_) {}
    return null;
  }

  // ── Seleciona Pokémon do dropdown ─────────────────────────────
  Future<void> _selectPokemon(Map<String, dynamic> p) async {
    setState(() { _showDropdown = false; _loadingPokemon = true; _pokemonError = null; });
    final pid  = (p['id'] as num).toInt();
    final name = p['name'] as String;

    final baseData = await _fetchGoData(pid, name);
    if (baseData == null || !mounted) {
      if (mounted) setState(() { _loadingPokemon = false; _pokemonError = 'Erro ao buscar stats'; });
      return;
    }

    // Evoluções via pokedex_data.json local (sem rede)
    final evoChain = PokedexDataService.instance.getEvoChain(pid);
    final evos = <_EvoTarget>[];
    bool foundCurrent = false;
    for (final step in evoChain) {
      final stepName = (step['name'] as String).toLowerCase();
      if (foundCurrent) evos.add(_EvoTarget(name: stepName));
      if (stepName == name.toLowerCase()) foundCurrent = true;
    }

    final evosWithData = <_EvoTarget>[];
    for (final evo in evos) {
      // Encontrar ID pelo nome no evoChain
      final chain = evoChain.firstWhere(
        (e) => (e['name'] as String).toLowerCase() == evo.name,
        orElse: () => <String, dynamic>{},
      );
      final eid   = (chain['id'] as int?) ?? 0;
      if (eid > 0) {
        final eData = await _fetchGoData(eid, evo.name);
        evosWithData.add(_EvoTarget(name: evo.name, data: eData));
      } else {
        evosWithData.add(_EvoTarget(name: evo.name));
      }
    }

    if (mounted) setState(() {
      _pokemon = _PokemonGoData(
        id: baseData.id, name: baseData.name,
        goAtk: baseData.goAtk, goDef: baseData.goDef, goSta: baseData.goSta,
        evolutions: evosWithData,
      );
      _loadingPokemon = false;
      _searchCtrl.clear();
    });
  }

  void _collectDirectEvos(Map<String, dynamic> node, String current, List<_EvoTarget> out) {
    final name = (node['species']['name'] as String).toLowerCase();
    final nexts = node['evolves_to'] as List<dynamic>;
    if (name == current.toLowerCase()) {
      for (final n in nexts) out.add(_EvoTarget(name: (n as Map)['species']['name'] as String));
      return;
    }
    for (final n in nexts) _collectDirectEvos(n as Map<String, dynamic>, current, out);
  }

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora de CP'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Evolução'), Tab(text: 'IVs / Nível')],
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
        ),
      ),
      body: Column(children: [
        _buildSelector(context),
        Expanded(child: TabBarView(
          controller: _tabController,
          children: [_buildEvoTab(context), _buildIvTab(context)],
        )),
      ]),
    );
  }

  // ── Seletor de Pokémon ────────────────────────────────────────
  Widget _buildSelector(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant, width: 0.5)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar Pokémon... (ex: Pikachu)',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() { _showDropdown = false; _searchResults = []; });
                      })
                  : null,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        if (_showDropdown)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant, width: 0.5),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 0.5, color: scheme.outlineVariant),
              itemBuilder: (_, i) {
                final p = _searchResults[i];
                final name = p['name'] as String;
                final pid  = (p['id'] as num).toInt();
                return InkWell(
                  onTap: () => _selectPokemon(p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(children: [
                      Image.network(
                        '${kSpriteBase}/$pid.png',
                        width: 36, height: 36,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 36, height: 36),
                      ),
                      const SizedBox(width: 10),
                      Text(name[0].toUpperCase() + name.substring(1),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text('#${pid.toString().padLeft(3, '0')}',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ]),
                  ),
                );
              },
            ),
          ),
        if (_loadingPokemon)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          )
        else if (_pokemon != null && !_showDropdown)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(children: [
              Image.network(
                '${kSpriteBase}/${_pokemon!.id}.png',
                width: 48, height: 48,
                errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 48),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_pokemon!.name[0].toUpperCase() + _pokemon!.name.substring(1),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('ATK ${_pokemon!.goAtk} · DEF ${_pokemon!.goDef} · STA ${_pokemon!.goSta}',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ])),
            ]),
          )
        else if (!_loadingPokemon && !_showDropdown)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Text('Busque um Pokémon para calcular o CP',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
        if (_pokemonError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(_pokemonError!, style: TextStyle(fontSize: 12, color: scheme.error)),
          ),
      ]),
    );
  }

  // ── Aba Evolução ──────────────────────────────────────────────
  Widget _buildEvoTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    final cpAtual = int.tryParse(_cpController.text) ?? 500;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Insira o CP atual para estimar o CP após evolução.',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        TextField(
          controller: _cpController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'CP atual',
            hintText: 'Ex: 500',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        if (_pokemon == null)
          _infoBox(context, 'Selecione um Pokémon acima para calcular.')
        else if (_pokemon!.evolutions.isEmpty)
          _infoBox(context, 'Este Pokémon não possui evoluções no Pokémon GO.')
        else
          Container(
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Column(children: _pokemon!.evolutions.asMap().entries.map((e) {
              final idx  = e.key;
              final evo  = e.value;
              final isLast = idx == _pokemon!.evolutions.length - 1;
              final cpEvo = evo.data != null ? _calcEvoCp(cpAtual, _pokemon!, evo.data!) : null;
              final evoName = evo.name[0].toUpperCase() + evo.name.substring(1);
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    if (evo.data != null)
                      Image.network(
                        '${kSpriteBase}/${evo.data!.id}.png',
                        width: 44, height: 44,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 44, height: 44),
                      ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(evoName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('Evolução ${idx + 1}',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ])),
                    Text(cpEvo != null ? '$cpEvo CP' : '...',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                        color: cpEvo != null ? scheme.primary : scheme.onSurfaceVariant)),
                  ]),
                ),
                if (!isLast) Divider(height: 0.5, color: scheme.outlineVariant),
              ]);
            }).toList()),
          ),
        const SizedBox(height: 12),
        _infoBox(context,
          'Resultado baseado nos stats GO. Variação de ±5% por causa dos IVs.'),
      ]),
    );
  }

  // ── Aba IVs / Nível ───────────────────────────────────────────
  Widget _buildIvTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_pokemon == null)
          _infoBox(context, 'Selecione um Pokémon acima para calcular.')
        else ...[
          Text('Nível e IVs',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              letterSpacing: 0.8, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              _sliderRow(context, 'Nível',
                _level.toStringAsFixed(_level % 1 == 0 ? 0 : 1),
                1, 50, _level, (v) => setState(() => _level = (v * 2).round() / 2)),
              Divider(height: 1, color: scheme.outlineVariant),
              _sliderRow(context, 'IV Ataque', '$_ivAtk', 0, 15, _ivAtk.toDouble(),
                (v) => setState(() => _ivAtk = v.round())),
              Divider(height: 1, color: scheme.outlineVariant),
              _sliderRow(context, 'IV Defesa', '$_ivDef', 0, 15, _ivDef.toDouble(),
                (v) => setState(() => _ivDef = v.round())),
              Divider(height: 1, color: scheme.outlineVariant),
              _sliderRow(context, 'IV HP', '$_ivHp', 0, 15, _ivHp.toDouble(),
                (v) => setState(() => _ivHp = v.round())),
            ]),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.primary.withOpacity(0.3)),
            ),
            child: Column(children: [
              Text('$_cpResult',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w700,
                  color: scheme.primary)),
              Text('Combat Power',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Text('CP Máximo (Nível 40, 15/15/15): ${_pokemon!.maxCp}',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _infoBox(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))),
      ]),
    );
  }

  Widget _sliderRow(BuildContext context, String label, String valStr,
      num min, num max, double val, ValueChanged<double> onChanged) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(valStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        Slider(value: val, min: min.toDouble(), max: max.toDouble(),
          divisions: (max - min).round(), onChanged: onChanged),
      ]),
    );
}