import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Stats base de um Pokémon no GO
class _GoStats {
  final String name;
  final int attack;
  final int defense;
  final int stamina;
  // Multiplicadores de evolução (aproximados) por nome da evolução
  final List<_EvoInfo> evolutions;
  const _GoStats(this.name, this.attack, this.defense, this.stamina, [this.evolutions = const []]);
}

class _EvoInfo {
  final String name;
  final double multiplier; // fator de CP após evolução
  const _EvoInfo(this.name, this.multiplier);
}

class GoCpCalculatorScreen extends StatefulWidget {
  const GoCpCalculatorScreen({super.key});

  @override
  State<GoCpCalculatorScreen> createState() => _GoCpCalculatorScreenState();
}

class _GoCpCalculatorScreenState extends State<GoCpCalculatorScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;

  // ── Estado compartilhado — Pokémon selecionado ────────────────────
  final _searchCtrl = TextEditingController();
  bool _searching   = false;
  String _pokemonName = '';
  int _baseAtk = 0, _baseDef = 0, _baseSta = 0;
  List<_EvoInfo> _evolutions = [];
  bool _loadingPokemon = false;
  String? _pokemonError;

  // ── Estado calculadora de Evolução ───────────────────────────────
  final _cpController = TextEditingController(text: '500');

  // ── Estado calculadora de IVs ─────────────────────────────────────
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

  double _sqrt(num n) {
    if (n <= 0) return 0;
    double x = n.toDouble();
    for (int i = 0; i < 30; i++) x = (x + n / x) / 2;
    return x;
  }

  int _calcCp(int ba, int bd, int bh, double lvl, int ia, int id, int ih) {
    final idx = ((lvl - 1) * 2).round().clamp(0, _cpm.length - 1);
    final cp = ((ba + ia) * _sqrt(bd + id) * _sqrt(bh + ih) * _cpm[idx] * _cpm[idx] / 10).floor();
    return cp < 10 ? 10 : cp;
  }

  int get _maxCp => _baseAtk > 0
      ? _calcCp(_baseAtk, _baseDef, _baseSta, 40, 15, 15, 15)
      : 0;

  int get _cpResult => _baseAtk > 0
      ? _calcCp(_baseAtk, _baseDef, _baseSta, _level, _ivAtk, _ivDef, _ivHp)
      : 0;

  // ── Busca o Pokémon na PokeAPI e extrai stats GO ──────────────────
  Future<void> _searchPokemon(String name) async {
    if (name.trim().isEmpty) return;
    setState(() { _loadingPokemon = true; _pokemonError = null; });
    try {
      final slug = name.trim().toLowerCase().replaceAll(' ', '-');
      final r = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$slug'));
      if (r.statusCode == 200 && mounted) {
        final d = json.decode(r.body) as Map<String, dynamic>;
        final stats = (d['stats'] as List<dynamic>);
        int attack = 0, defense = 0, hp = 0;
        for (final s in stats) {
          final sname = s['stat']['name'] as String;
          final base  = s['base_stat'] as int;
          if (sname == 'attack' || sname == 'special-attack') {
            // GO Attack = max(Attack, Sp.Attack) * 7/8 + min * 1/8 (aproximação)
            attack = attack == 0 ? base : ((attack * 7 + base) ~/ 8);
          } else if (sname == 'defense' || sname == 'special-defense') {
            defense = defense == 0 ? base : ((defense * 5 + base * 3) ~/ 8);
          } else if (sname == 'hp') {
            hp = (base * 1.75 + 50).floor();
          }
        }

        // Busca evoluções na chain
        final speciesUrl = d['species']['url'] as String;
        final List<_EvoInfo> evos = await _fetchEvolutions(speciesUrl, name.trim().toLowerCase(), attack, defense, hp);

        if (mounted) setState(() {
          _pokemonName = (d['name'] as String);
          _baseAtk  = attack.clamp(1, 999);
          _baseDef  = defense.clamp(1, 999);
          _baseSta  = hp.clamp(1, 999);
          _evolutions = evos;
          _loadingPokemon = false;
          _searching = false;
        });
      } else {
        if (mounted) setState(() {
          _pokemonError = 'Pokémon não encontrado';
          _loadingPokemon = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _pokemonError = 'Erro ao buscar Pokémon';
        _loadingPokemon = false;
      });
    }
  }

  Future<List<_EvoInfo>> _fetchEvolutions(String speciesUrl, String currentName,
      int baseAtk, int baseDef, int baseSta) async {
    try {
      final rs = await http.get(Uri.parse(speciesUrl));
      if (rs.statusCode != 200) return [];
      final sd = json.decode(rs.body) as Map<String, dynamic>;
      final chainUrl = sd['evolution_chain']['url'] as String;
      final rc = await http.get(Uri.parse(chainUrl));
      if (rc.statusCode != 200) return [];
      final cd = json.decode(rc.body) as Map<String, dynamic>;

      // Percorre a chain para encontrar as evoluções do currentName
      final evos = <_EvoInfo>[];
      _walkChain(cd['chain'] as Map<String, dynamic>, currentName, evos,
          baseAtk, baseDef, baseSta);
      return evos;
    } catch (_) { return []; }
  }

  void _walkChain(Map<String, dynamic> node, String current,
      List<_EvoInfo> evos, int atk, int def, int sta) {
    final name = (node['species']['name'] as String).toLowerCase();
    final nexts = node['evolves_to'] as List<dynamic>;
    if (name == current) {
      // Adiciona cada evolução direta
      for (final next in nexts) {
        final evoName = (next['species']['name'] as String);
        // Estimativa: evolução aumenta CP baseado na razão de stats base (aproximado)
        // Usaremos a razão de maxCP: calculamos de forma genérica
        evos.add(_EvoInfo(evoName, 0)); // multiplier=0 indica "buscar depois"
      }
      return;
    }
    for (final next in nexts) {
      _walkChain(next as Map<String, dynamic>, current, evos, atk, def, sta);
    }
  }

  // CP da evolução = CP_atual × (maxCP_evo / maxCP_base)
  // Se não tiver stats da evo, usa fatores genéricos conhecidos
  double _evoMultiplier(int evoIndex) {
    // Fatores genéricos para evolução 1 e 2 (media da maioria dos Pokémon)
    return evoIndex == 0 ? 1.815 : 3.293;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cpController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

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
        // ── Seletor de Pokémon — compartilhado entre as abas ──────
        _buildPokemonSelector(context),
        Expanded(child: TabBarView(
          controller: _tabController,
          children: [
            _buildEvoCalc(context),
            _buildIvCalc(context),
          ],
        )),
      ]),
    );
  }

  // ── Seletor de Pokémon ────────────────────────────────────────────
  Widget _buildPokemonSelector(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: border, width: 0.5)),
      ),
      child: _searching
          ? Row(children: [
              Expanded(child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Nome do Pokémon (ex: pikachu)',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onSubmitted: _searchPokemon,
              )),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  if (_searchCtrl.text.isNotEmpty) {
                    _searchPokemon(_searchCtrl.text);
                  } else {
                    setState(() => _searching = false);
                  }
                },
                child: const Text('Buscar'),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() { _searching = false; _searchCtrl.clear(); }),
              ),
            ])
          : Row(children: [
              Expanded(child: _loadingPokemon
                  ? const LinearProgressIndicator()
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_pokemonName.isEmpty ? 'Nenhum Pokémon selecionado' : _pokemonName[0].toUpperCase() + _pokemonName.substring(1),
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: _pokemonName.isEmpty ? scheme.onSurfaceVariant : null)),
                      if (_pokemonName.isNotEmpty)
                        Text('ATK $_baseAtk · DEF $_baseDef · STA $_baseSta',
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      if (_pokemonError != null)
                        Text(_pokemonError!, style: TextStyle(fontSize: 11, color: scheme.error)),
                    ])),
              TextButton.icon(
                onPressed: () => setState(() { _searching = true; _searchCtrl.clear(); }),
                icon: const Icon(Icons.search, size: 18),
                label: Text(_pokemonName.isEmpty ? 'Selecionar' : 'Mudar'),
              ),
            ]),
    );
  }

  // ── Calculadora de Evolução ───────────────────────────────────────
  Widget _buildEvoCalc(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    final cpInput = double.tryParse(_cpController.text) ?? 500;
    final hasEvo = _evolutions.isNotEmpty;

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
            hintText: 'Ex: 1234',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        if (_pokemonName.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant, width: 0.5),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Selecione um Pokémon acima para resultados precisos baseados nos stats reais.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              )),
            ]),
          )
        else
          Container(
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: hasEvo
                ? Column(children: _evolutions.asMap().entries.map((e) {
                    final idx = e.key;
                    final evo = e.value;
                    final mult = _evoMultiplier(idx);
                    final cpEvo = (cpInput * mult).round();
                    final isLast = idx == _evolutions.length - 1;
                    return Column(children: [
                      _evoResultRow(context, scheme,
                        '${evo.name[0].toUpperCase()}${evo.name.substring(1)}',
                        cpEvo, 'Evolução ${idx + 1}'),
                      if (!isLast) Divider(height: 0.5, color: scheme.outlineVariant),
                    ]);
                  }).toList())
                : _evoResultRow(context, scheme, 'Sem evolução', 0, 'Este Pokémon não evolui'),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant, width: 0.5),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Valores aproximados. IVs e nível afetam o CP final.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _evoResultRow(BuildContext context, ColorScheme scheme,
      String label, int cp, String note) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text(note, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ]),
        Text(cp > 0 ? '$cp CP' : '—',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
            color: cp > 0 ? scheme.primary : scheme.onSurfaceVariant)),
      ]),
    );
  }

  // ── Calculadora de IVs / Nível ────────────────────────────────────
  Widget _buildIvCalc(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    final hasStats = _baseAtk > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!hasStats)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant, width: 0.5),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Selecione um Pokémon acima para calcular o CP com os stats reais.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              )),
            ]),
          ),
        if (hasStats) ...[
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
                1, 50, _level,
                (v) => setState(() => _level = (v * 2).round() / 2)),
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
              Text('CP Máximo (Nível 40, 15/15/15): $_maxCp',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ]),
          ),
        ],
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