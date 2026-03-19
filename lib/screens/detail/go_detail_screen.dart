import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart';

class GoDetailScreen extends StatefulWidget {
  final Pokemon pokemon;
  final bool caught;
  final VoidCallback onToggleCaught;

  const GoDetailScreen({
    super.key,
    required this.pokemon,
    required this.caught,
    required this.onToggleCaught,
  });

  @override
  State<GoDetailScreen> createState() => _GoDetailScreenState();
}

class _GoDetailScreenState extends State<GoDetailScreen>
    with SingleTickerProviderStateMixin {

  late bool _caught;
  late TabController _tabController;

  List<Map<String, dynamic>> _forms = [];
  bool _loading = true;

  static const _tabs = ['Info', 'Status', 'Formas', 'Calc. CP'];

  @override
  void initState() {
    super.initState();
    _caught = widget.caught;
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadForms();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadForms() async {
    try {
      final r = await http.get(Uri.parse('$kApiBase/pokemon-species/${widget.pokemon.id}'));
      if (r.statusCode == 200 && mounted) {
        final species = json.decode(r.body) as Map<String, dynamic>;
        final varieties = species['varieties'] as List<dynamic>? ?? [];
        final forms = <Map<String, dynamic>>[];
        for (final v in varieties) {
          final url = v['pokemon']['url'] as String;
          final name = v['pokemon']['name'] as String;
          try {
            final rf = await http.get(Uri.parse(url));
            if (rf.statusCode == 200) {
              final fd = json.decode(rf.body) as Map<String, dynamic>;
              final types = (fd['types'] as List<dynamic>).map((t) => t['type']['name'] as String).toList();
              forms.add({'name': name, 'id': fd['id'] as int, 'types': types,
                'isDefault': v['is_default'] as bool, 'game': null});
            }
          } catch (_) {}
        }
        if (mounted) setState(() { _forms = forms; _loading = false; });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
          ),
        ],
        body: Column(children: [
          Material(
            elevation: 0,
            child: TabBar(
              controller: _tabController,
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          Expanded(child: TabBarView(
            controller: _tabController,
            children: [
              _GoInfoTab(pokemon: widget.pokemon),
              StatusTab(pokemon: widget.pokemon),
              FormsTab(forms: _forms, loading: _loading),
              _CpCalcTab(pokemon: widget.pokemon),
            ],
          )),
        ]),
      ),
    );
  }
}

// ─── ABA INFO GO ─────────────────────────────────────────────────

class _GoInfoTab extends StatelessWidget {
  final Pokemon pokemon;
  const _GoInfoTab({required this.pokemon});

  int get _maxCp {
    const cpm40 = 0.7903;
    double sqrt(num n) { if (n <= 0) return 0; double x = n.toDouble(); for (int i = 0; i < 30; i++) x = (x + n / x) / 2; return x; }
    final cp = ((pokemon.baseAttack + 15) * sqrt(pokemon.baseDefense + 15) *
        sqrt(pokemon.baseHp + 15) * cpm40 * cpm40 / 10).floor();
    return cp < 10 ? 10 : cp;
  }

  @override
  Widget build(BuildContext context) {
    final bg = neutralBg(context);
    final border = neutralBorder(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        secTitle(context, 'STATS POKÉMON GO'),
        Container(
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Row(children: [
              _statBox(context, '${pokemon.baseAttack}', 'Ataque'),
              Container(width: 0.5, height: 40, color: border),
              _statBox(context, '${pokemon.baseDefense}', 'Defesa'),
              Container(width: 0.5, height: 40, color: border),
              _statBox(context, '${pokemon.baseHp}', 'HP'),
            ]),
            Divider(height: 0.5, color: border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('CP Máximo (Nível 40)',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                Text('$_maxCp', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        secTitle(context, 'DISPONIBILIDADE'),
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, childAspectRatio: 2.8,
          crossAxisSpacing: 8, mainAxisSpacing: 8,
          children: [
            _availCell(context, 'Shiny', '✓ Disponível', const Color(0xFF34C759)),
            _availCell(context, 'Shadow', '✓ GO Rocket', const Color(0xFFFF9500)),
            _availCell(context, 'Regional', '✗ Global', Colors.red),
            _availCell(context, 'Lucky', 'Via troca', const Color(0xFFFFCC00)),
          ],
        ),
        const SizedBox(height: 16),
        secTitle(context, 'COMO OBTER'),
        _obtainCard(context, Icons.catching_pokemon_outlined, const Color(0xFF4a9020),
          'Encontro selvagem', 'Ambientes urbanos e parques'),
        const SizedBox(height: 8),
        _obtainCard(context, Icons.star_border_outlined, const Color(0xFFc8a020),
          'Raid de 3 estrelas', 'Disponível como chefe de raid'),
        const SizedBox(height: 16),
        secTitle(context, 'VARIANTES'),
        Row(children: [
          _variantCard(context, pokemon.id, 'Normal'),
          const SizedBox(width: 8),
          _variantCard(context, pokemon.id, 'Shiny'),
          const SizedBox(width: 8),
          _variantCard(context, pokemon.id, 'Shadow'),
        ]),
      ]),
    );
  }

  Widget _statBox(BuildContext ctx, String val, String lbl) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(lbl, style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
      ]),
    ),
  );

  Widget _availCell(BuildContext ctx, String label, String value, Color color) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: neutralBg(ctx), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );

  Widget _obtainCard(BuildContext ctx, IconData icon, Color iconColor, String title, String sub) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: neutralBg(ctx), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(sub, style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
        ]),
      ]),
    );

  Widget _variantCard(BuildContext ctx, int id, String label) {
    final sprite = label == 'Shiny'
        ? 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/shiny/$id.png'
        : 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png';
    return Expanded(child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: neutralBg(ctx), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Image.network(sprite, width: 52, height: 52,
          errorBuilder: (_, __, ___) => const Icon(Icons.catching_pokemon, size: 40)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(ctx).textTheme.labelSmall?.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        Text(label == 'Shadow' ? '—' : '✓',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: label == 'Shadow' ? Theme.of(ctx).colorScheme.onSurfaceVariant : Colors.green)),
      ]),
    ));
  }
}

// ─── CALC CP GO ──────────────────────────────────────────────────

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

  double _sqrt(num n) { if (n <= 0) return 0; double x = n.toDouble(); for (int i = 0; i < 30; i++) x = (x + n / x) / 2; return x; }

  int _calcCp(int ba, int bd, int bh, double lvl, int ia, int id, int ih) {
    final idx = ((lvl - 1) * 2).round().clamp(0, _cpm.length - 1);
    final cp = ((ba + ia) * _sqrt(bd + id) * _sqrt(bh + ih) * _cpm[idx] * _cpm[idx] / 10).floor();
    return cp < 10 ? 10 : cp;
  }

  int get _maxCp => _calcCp(widget.pokemon.baseAttack, widget.pokemon.baseDefense,
      widget.pokemon.baseHp, 40, 15, 15, 15);

  @override
  Widget build(BuildContext context) {
    final bg = neutralBg(context);
    final cpCalc = _calcCp(widget.pokemon.baseAttack, widget.pokemon.baseDefense,
        widget.pokemon.baseHp, _level, _ivAtk, _ivDef, _ivHp);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            for (final e in [('evo', 'Evolução'), ('iv', 'IVs exatos')])
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _mode = e.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _mode == e.$1 ? Theme.of(context).colorScheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(e.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: _mode == e.$1 ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center),
                ),
              )),
          ]),
        ),
        const SizedBox(height: 16),
        if (_mode == 'evo') ...[
          Text('CP atual para estimar após evolução',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('CP atual', style: const TextStyle(fontSize: 12)),
            Text(_currentCp.toInt().toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          Slider(value: _currentCp, min: 10, max: (_maxCp * 0.85).toDouble(),
            onChanged: (v) => setState(() => _currentCp = v)),
          const SizedBox(height: 8),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 8),
          Row(children: [
            _evoBox(context, '${(_currentCp * 1.815).round()}', 'Evolução 1'),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.arrow_forward, size: 18, color: Colors.grey)),
            _evoBox(context, '${(_currentCp * 3.293).round()}', 'Evolução 2'),
          ]),
        ] else ...[
          _sliderRow('Nível', _level.toStringAsFixed(_level % 1 == 0 ? 0 : 1), 1, 50, _level,
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
            Text('$cpCalc', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600)),
            Text('Combat Power', style: TextStyle(fontSize: 11,
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
        color: neutralBg(ctx), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: neutralBorder(ctx), width: 0.5)),
      child: Column(children: [
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        Text(lbl, style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
      ]),
    ),
  );

  Widget _sliderRow(String label, String valStr, num min, num max, double val, ValueChanged<double> onChanged) =>
    Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(valStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
      Slider(value: val, min: min.toDouble(), max: max.toDouble(),
        divisions: (max - min).round(), onChanged: onChanged),
    ]);
}