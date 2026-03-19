import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart';

class GoDetailScreen extends StatefulWidget {
  final Pokemon pokemon;
  final bool caught;
  final VoidCallback onToggleCaught;
  // Navegação entre Pokémon
  final String? prevName;
  final int?    prevId;
  final String? nextName;
  final int?    nextId;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const GoDetailScreen({
    super.key,
    required this.pokemon,
    required this.caught,
    required this.onToggleCaught,
    this.prevName, this.prevId,
    this.nextName, this.nextId,
    this.onPrev,  this.onNext,
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

  // Aba Calc. CP removida — agora está na calculadora standalone
  static const _tabs = ['Info', 'Status', 'Formas'];

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
          final url  = v['pokemon']['url'] as String;
          final name = v['pokemon']['name'] as String;
          try {
            final rf = await http.get(Uri.parse(url));
            if (rf.statusCode == 200) {
              final fd    = json.decode(rf.body) as Map<String, dynamic>;
              final types = (fd['types'] as List<dynamic>)
                  .map((t) => t['type']['name'] as String).toList();
              // Shadow e formas de evento também aparecem aqui como varieties
              forms.add({
                'name': name,
                'id': fd['id'] as int,
                'types': types,
                'isDefault': v['is_default'] as bool,
                'game': null,
              });
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
            ),
          ),
          Expanded(child: TabBarView(
            controller: _tabController,
            children: [
              _GoInfoTab(pokemon: widget.pokemon),
              StatusTab(pokemon: widget.pokemon),
              FormsTab(forms: _forms, loading: _loading),
            ],
          )),
        ]),
      ),
    );
  }
}

// ─── ABA INFO GO ─────────────────────────────────────────────────

class _GoInfoTab extends StatefulWidget {
  final Pokemon pokemon;
  const _GoInfoTab({required this.pokemon});

  @override
  State<_GoInfoTab> createState() => _GoInfoTabState();
}

class _GoInfoTabState extends State<_GoInfoTab> {
  int _goAtk = 0, _goDef = 0, _goSta = 0;
  bool _loadingStats = true;

  // Busca os stats GO reais da pogoapi.net — valores precisos do game master
  Future<void> _loadGoStats() async {
    try {
      final r = await http.get(
        Uri.parse('https://pogoapi.net/api/v1/pokemon_stats.json'));
      if (r.statusCode == 200 && mounted) {
        // A resposta pode ser lista ou mapa dependendo da versão da API
        final body = json.decode(r.body);
        List<dynamic> list;
        if (body is List) {
          list = body;
        } else if (body is Map) {
          // Formato alternativo: { "1": {...}, "2": {...} }
          list = body.values.toList();
        } else {
          list = [];
        }
        for (final p in list) {
          final pid = p['id'] ?? p['pokemon_id'];
          if (pid != null && (pid as num).toInt() == widget.pokemon.id) {
            final atk = (p['base_attack'] ?? p['attack'] ?? 0) as num;
            final def = (p['base_defense'] ?? p['defense'] ?? 0) as num;
            final sta = (p['base_stamina'] ?? p['stamina'] ?? 0) as num;
            if (atk.toInt() > 0 && mounted) {
              setState(() {
                _goAtk = atk.toInt();
                _goDef = def.toInt();
                _goSta = sta.toInt();
                _loadingStats = false;
              });
              return;
            }
            break;
          }
        }
      }
    } catch (_) {}

    // Fallback: buscar do endpoint de stats da PokeAPI e aplicar escala empírica
    // A escala ~2.0 é uma aproximação razoável para a maioria dos Pokémon
    try {
      final r = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon/${widget.pokemon.id}'));
      if (r.statusCode == 200 && mounted) {
        final d = json.decode(r.body) as Map<String, dynamic>;
        final stats = d['stats'] as List<dynamic>;
        int atk = 0, spatk = 0, def = 0, spdef = 0, hp = 0, spd = 0;
        for (final s in stats) {
          final sname = s['stat']['name'] as String;
          final base  = (s['base_stat'] as num).toInt();
          switch (sname) {
            case 'attack':          atk   = base; break;
            case 'special-attack':  spatk = base; break;
            case 'defense':         def   = base; break;
            case 'special-defense': spdef = base; break;
            case 'hp':              hp    = base; break;
            case 'speed':           spd   = base; break;
          }
        }
        // Fórmula de conversão com speedMod e escala empírica
        final speedMod = 1 + (spd - 75) / 500;
        final higherAtk = atk >= spatk ? atk : spatk;
        final lowerAtk  = atk >= spatk ? spatk : atk;
        final higherDef = def >= spdef ? def : spdef;
        final lowerDef  = def >= spdef ? spdef : def;
        // Multiplicador empírico ajustado para compensar a escala da Niantic
        const scale = 2.0;
        final goAtk = ((7 * higherAtk + lowerAtk) / 8 * speedMod * scale).round().clamp(1, 999);
        final goDef = ((5 * higherDef + 3 * lowerDef) / 8 * speedMod * scale).round().clamp(1, 999);
        final goSta = (hp * 1.75 + 50).floor().clamp(20, 9999);
        if (mounted) setState(() {
          _goAtk = goAtk; _goDef = goDef; _goSta = goSta;
          _loadingStats = false;
        });
        return;
      }
    } catch (_) {}

    // Último fallback
    if (mounted) setState(() {
      _goAtk = widget.pokemon.baseAttack;
      _goDef = widget.pokemon.baseDefense;
      _goSta = (widget.pokemon.baseHp * 1.75 + 50).floor();
      _loadingStats = false;
    });
  }

  int get _maxCp {
    if (_goAtk == 0) return 0;
    const cpm40 = 0.7903;
    double sqrt(num n) {
      if (n <= 0) return 0;
      double x = n.toDouble();
      for (int i = 0; i < 30; i++) x = (x + n / x) / 2;
      return x;
    }
    final cp = ((_goAtk + 15) * sqrt(_goDef + 15) *
        sqrt(_goSta + 15) * cpm40 * cpm40 / 10).floor();
    return cp < 10 ? 10 : cp;
  }

  @override
  void initState() {
    super.initState();
    _loadGoStats();
  }

  @override
  Widget build(BuildContext context) {
    final bg     = neutralBg(context);
    final border = neutralBorder(context);
    const rocketColor = Color(0xFF7B1FA2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        secTitle(context, 'STATS POKÉMON GO'),
        Container(
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: _loadingStats
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : Column(children: [
                  Row(children: [
                    _statBox(context, '$_goAtk', 'Ataque'),
                    Container(width: 0.5, height: 40, color: border),
                    _statBox(context, '$_goDef', 'Defesa'),
                    Container(width: 0.5, height: 40, color: border),
                    _statBox(context, '$_goSta', 'Stamina'),
                  ]),
                  Divider(height: 0.5, color: border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('CP Máximo (Nível 40)',
                        style: TextStyle(fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Text('$_maxCp',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
        ),
        const SizedBox(height: 16),
        secTitle(context, 'DISPONIBILIDADE'),
        Column(children: [
          Row(children: [
            Expanded(child: _availCell(context, 'Shiny',    'Disponível',   const Color(0xFF34C759))),
            const SizedBox(width: 8),
            Expanded(child: _availCell(context, 'Shadow',   'Disponível',   rocketColor)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _availCell(context, 'Regional', 'Indisponível', Colors.red)),
            const SizedBox(width: 8),
            Expanded(child: _availCell(context, 'Lucky',    'Via troca',    const Color(0xFFFFCC00))),
          ]),
        ]),
        const SizedBox(height: 16),
        secTitle(context, 'COMO OBTER'),
        _obtainCard(context, Icons.catching_pokemon_outlined, const Color(0xFF4a9020),
          'Encontro selvagem', 'Ambientes urbanos e parques'),
        const SizedBox(height: 8),
        _obtainCard(context, Icons.star_border_outlined, const Color(0xFFc8a020),
          'Raid de 3 estrelas', 'Disponível como chefe de raid'),
      ]),
    );
  }

  Widget _statBox(BuildContext ctx, String val, String lbl) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(lbl, style: TextStyle(fontSize: 10,
          color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
      ]),
    ),
  );

  Widget _availCell(BuildContext ctx, String label, String value, Color color) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: neutralBg(ctx), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(fontSize: 10,
          color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
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
          Text(sub, style: TextStyle(fontSize: 11,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
        ]),
      ]),
    );
} // fim _GoInfoTabState