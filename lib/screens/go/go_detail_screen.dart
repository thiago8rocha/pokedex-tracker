import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pokedex_tracker/models/pokemon.dart';
import 'package:pokedex_tracker/services/pokedex_data_service.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart';

// ─── POKÉMON REGIONAIS NO GO ──────────────────────────────────────
// Chave: ID nacional. Valor: região exclusiva.
// null = disponível globalmente.
const Map<int, String> _goRegionals = {
  // Geração I
  83:  'Ásia',
  115: 'Austrália / NZ',
  122: 'Europa',
  128: 'América do Norte',
  // Geração II
  214: 'América do Sul / Sul dos EUA',
  222: 'Regiões Tropicais',
  313: 'Europa / Ásia / Austrália',
  314: 'Américas / África',
  // Geração III
  324: 'Ásia do Sul',
  335: 'América do Norte / Ásia',
  336: 'América do Sul / Europa',
  337: 'Américas',
  338: 'Europa / Ásia / Austrália',
  357: 'África / Mediterrâneo',
  369: 'Austrália / NZ',
  // Geração IV
  417: 'América do Norte / Rússia',
  422: 'Oceano Atlântico',
  423: 'Oceano Pacífico',
  441: 'Hemisfério Sul',
  455: 'América do Norte',
  480: 'Ásia-Pacífico',
  481: 'Europa',
  482: 'Américas',
  // Geração V
  511: 'Ásia-Pacífico',
  513: 'Américas',
  515: 'Europa / África',
  538: 'América do Norte',
  539: 'Ásia / Austrália',
  556: 'América do Sul / América Central',
  561: 'Egito / Grécia',
};

String? _getRegional(int pokemonId) => _goRegionals[pokemonId];


// ─── EVOLUÇÕES NO POKÉMON GO ──────────────────────────────────────
// Requisitos especiais além de candy padrão
const Map<int, String> _goEvoRequirements = {
  // Eevee (133) → evoluções por nome / itens
  133:  'Candy (25) + apelido ou caminhada de 10km como Buddy',
  // Tyrogue (236) → depende dos stats
  236:  'Candy (25) — evolução depende dos stats (ATK/DEF/STA)',
  // Feebas (349) → caminhada
  349:  'Candy (100) + caminhar 20km como Buddy',
  // Wurmple (265) → aleatório
  265:  'Candy (12) — evolução aleatória (Silcoon ou Cascoon)',
  // Burmy (412) → depende do manto
  412:  'Candy (50) — depende do manto equipado',
  // Mime Jr. (439) → regional
  439:  'Candy (50) — exclusivo de regiões europeias',
  // Galarian Yamask (562) → desafio
  562:  '10 raids como Buddy + Candy (50)',
  // Pancham (674) → tipo sombrio
  674:  'Candy (50) + capturar 32 Pokémon do tipo Sombrio',
  // Spritzee (682) → incenso
  682:  'Candy (50) + usar Incenso',
  // Swirlix (685) → item alimentação
  685:  'Candy (50) + dar 25 doces ao Buddy',
  // Sliggoo (0) geração → clima
  705:  'Candy (100) + tempo chuvoso ou neblinoso',
};

// Itens de evolução GO (ID do Pokémon → item necessário)
const Map<int, String> _goEvoItems = {
  // Sinnoh Stones
  94:  'Pedra de Sinnoh',   // Gengar
  106: 'Pedra de Sinnoh',   // Hitmonlee (via Tyrogue)
  107: 'Pedra de Sinnoh',   // Hitmonchan (via Tyrogue)
  214: 'Pedra de Sinnoh',   // Heracross — não evolui, mas exibe
  233: 'Módulo de Upgrade',  // Porygon2
  474: 'Módulo de Upgrade',  // Porygon-Z
  461: 'Pedra de Sinnoh',   // Weavile
  462: 'Pedra de Sinnoh ou Módulo de Isca Magnética',   // Magnezone
  463: 'Pedra de Sinnoh',   // Lickilicky
  464: 'Pedra de Sinnoh',   // Rhyperior
  465: 'Pedra de Sinnoh',   // Tangrowth
  466: 'Pedra de Sinnoh',   // Electivire
  467: 'Pedra de Sinnoh',   // Magmortar
  468: 'Pedra de Sinnoh',   // Togekiss
  469: 'Pedra de Sinnoh',   // Yanmega
  470: 'Pedra de Sinnoh',   // Leafeon (+ Módulo de Isca Musgosa)
  471: 'Pedra de Sinnoh',   // Glaceon (+ Módulo de Isca Glacial)
  472: 'Pedra de Sinnoh',   // Gliscor
  473: 'Pedra de Sinnoh',   // Mamoswine
  // Unova Stones
  526: 'Pedra de Unova',    // Gigalith
  530: 'Pedra de Unova',    // Excadrill
  549: 'Pedra de Unova',    // Lilligant
  553: 'Pedra de Unova',    // Krookodile
  555: 'Pedra de Unova',    // Darmanitan
  560: 'Pedra de Unova',    // Scrafty
  579: 'Pedra de Unova',    // Reuniclus
  586: 'Pedra de Unova',    // Sawsbuck (sazonal)
  589: 'Pedra de Unova',    // Escavalier (+ troca)
  592: 'Pedra de Unova',    // Frillish
  617: 'Pedra de Unova',    // Accelgor (+ troca)
  618: 'Pedra de Unova',    // Stunfisk de Galar
  // Dragon Scale
  230: 'Escama de Dragão',  // Kingdra
  // Sun Stone
  45:  'Pedra Solar',       // Vileplume
  182: 'Pedra Solar',       // Bellossom
  192: 'Pedra Solar',       // Sunflora
  315: 'Pedra Solar',       // Roselia → Roserade
  407: 'Pedra Solar',       // Roserade
  // Metal Coat
  212: 'Casaco de Metal',   // Scizor
  208: 'Casaco de Metal',   // Steelix
  // King's Rock
  186: 'Pedra do Rei',      // Politoed
  199: 'Pedra do Rei',      // Slowking
  // Magnetic Lure
};

// Candy necessário padrão por família
const Map<int, int> _goCandyCost = {
  // Evoluções de 1 estágio
  133: 25, 236: 25,
  // Evoluções de 2 estágios (1o → 2o)
};

// Como obter no GO (ID → lista de fontes)
const Map<int, List<String>> _goObtain = {
  // Exclusivos de Raid
  144: ['Raid de 5 estrelas (Lendário)'],
  145: ['Raid de 5 estrelas (Lendário)'],
  146: ['Raid de 5 estrelas (Lendário)'],
  150: ['Raid de 5 estrelas (Lendário)'],
  151: ['Evento especial (pesquisa)'],
  243: ['Raid de 5 estrelas (Lendário)'],
  244: ['Raid de 5 estrelas (Lendário)'],
  245: ['Raid de 5 estrelas (Lendário)'],
  249: ['Raid de 5 estrelas (Lendário)'],
  250: ['Raid de 5 estrelas (Lendário)'],
  251: ['Evento especial (pesquisa)'],
  // Míticos
  385: ['Evento especial (pesquisa)'],
  386: ['Evento especial (pesquisa)'],
  // Exclusivos de evolução (não aparecem selvagens)
  3:   ['Evolução de Ivysaur'],
  6:   ['Evolução de Charmeleon'],
  9:   ['Evolução de Wartortle'],
};

// Pokémon exclusivos de Shadow (Team Rocket)
const Set<int> _goShadowOnly = {
  52, 66, 92, 109, 147, 246,
};

// Pokémon disponíveis em ovos
const Map<int, String> _goEggs = {
  // 2km
  10: '2km', 13: '2km', 16: '2km', 19: '2km', 21: '2km',
  // 5km
  7: '5km', 1: '5km', 4: '5km',
  // 10km
  147: '10km', 246: '10km', 443: '10km',
};

List<String> _getObtainMethods(int pokemonId) {
  // Se tem dados específicos, usar
  if (_goObtain.containsKey(pokemonId)) return _goObtain[pokemonId]!;

  final methods = <String>[];

  // Regional = só aparece em certas regiões
  if (_goRegionals.containsKey(pokemonId)) {
    methods.add('Selvagem — exclusivo de ${_goRegionals[pokemonId]}');
  } else {
    methods.add('Selvagem');
  }

  // Ovo
  if (_goEggs.containsKey(pokemonId)) {
    methods.add('Ovo de ${_goEggs[pokemonId]}');
  }

  // Shadow
  if (_goShadowOnly.contains(pokemonId)) {
    methods.add('Resgate do Team Rocket (Shadow)');
  }

  return methods.isEmpty ? ['Encontro selvagem'] : methods;
}

String _getEvoInfo(int pokemonId) {
  if (_goEvoRequirements.containsKey(pokemonId)) {
    return _goEvoRequirements[pokemonId]!;
  }
  if (_goEvoItems.containsKey(pokemonId)) {
    return 'Candy + ${_goEvoItems[pokemonId]}';
  }
  return '';
}

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
    // Usar forms_map.json local — sem rede
    try {
      final raw     = await rootBundle.loadString('assets/data/forms_map.json');
      final map     = json.decode(raw) as Map<String, dynamic>;
      final id      = widget.pokemon.id.toString();
      final entries = map[id] as List<dynamic>? ?? [];
      final forms   = <Map<String, dynamic>>[];
      for (final v in entries) {
        final m     = v as Map<String, dynamic>;
        final pid   = m['id'] as int;
        final name  = m['name'] as String;
        final svc   = PokedexDataService.instance;
        final types = svc.getTypes(pid).isNotEmpty
            ? svc.getTypes(pid)
            : svc.getTypes(widget.pokemon.id);
        forms.add({
          'name': name, 'id': pid, 'types': types,
          'isDefault': m['isDefault'] as bool? ?? false, 'game': null,
        });
      }
      if (mounted) setState(() { _forms = forms; _loading = false; });
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
                  child: Center(child: PokeballLoader.small()))
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
            Expanded(child: _availCell(context, 'Shiny',  'Disponível', const Color(0xFF34C759))),
            const SizedBox(width: 8),
            Expanded(child: _availCell(context, 'Shadow', 'Disponível', rocketColor)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _buildRegionalCell(context, widget.pokemon.id)),
            const SizedBox(width: 8),
            Expanded(child: _availCell(context, 'Lucky', 'Via troca', const Color(0xFFFFCC00))),
          ]),
        ]),
        const SizedBox(height: 16),

        // ── Como Obter ────────────────────────────────────────
        secTitle(context, 'COMO OBTER'),
        ..._getObtainMethods(widget.pokemon.id).map((method) {
          IconData icon;
          Color color;
          if (method.contains('Lendário')) {
            icon = Icons.auto_awesome; color = const Color(0xFFE65100);
          } else if (method.contains('Ovo')) {
            icon = Icons.egg_outlined; color = const Color(0xFF1565C0);
          } else if (method.contains('Rocket') || method.contains('Shadow')) {
            icon = Icons.rocket_launch_outlined; color = const Color(0xFF7B1FA2);
          } else if (method.contains('Evento') || method.contains('pesquisa')) {
            icon = Icons.event_outlined; color = const Color(0xFF00897B);
          } else if (method.contains('exclusivo')) {
            icon = Icons.location_on_outlined; color = const Color(0xFFE65100);
          } else if (method.contains('Selvagem') || method.contains('Encontro')) {
            icon = Icons.catching_pokemon_outlined; color = const Color(0xFF4a9020);
          } else {
            icon = Icons.info_outline; color = Colors.grey;
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _obtainCard(context, icon, color, method, ''),
          );
        }),

        // ── Evolução no GO ────────────────────────────────────
        Builder(builder: (ctx) {
          final evoInfo  = _getEvoInfo(widget.pokemon.id);
          final svc      = PokedexDataService.instance;
          final evoChain = svc.getEvoChain(widget.pokemon.id);

          if (evoChain.isEmpty && evoInfo.isEmpty) return const SizedBox();

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            secTitle(context, 'EVOLUÇÃO NO GO'),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: neutralBg(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Cadeia de evolução
                if (evoChain.isNotEmpty) ...[
                  Text('Cadeia',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (int i = 0; i < evoChain.length; i++) ...[
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              'assets/sprites/artwork/${evoChain[i]['id']}.webp',
                              width: 48, height: 48, fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 48),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(evoChain[i]['name'] as String? ?? '',
                            style: const TextStyle(fontSize: 10),
                            textAlign: TextAlign.center),
                        ]),
                        if (i < evoChain.length - 1)
                          const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                      ],
                    ],
                  ),
                  if (evoInfo.isNotEmpty) const SizedBox(height: 10),
                ],
                // Requisito especial
                if (evoInfo.isNotEmpty) ...[
                  Text('Requisito',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline, size: 14, color: Color(0xFF1565C0)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(evoInfo,
                      style: const TextStyle(fontSize: 12, height: 1.4))),
                  ]),
                ],
              ]),
            ),
          ]);
        }),
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

  Widget _buildRegionalCell(BuildContext ctx, int pokemonId) {
    final region = _getRegional(pokemonId);
    final isRegional = region != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: neutralBg(ctx), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Regional', style: TextStyle(fontSize: 10,
          color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(
          isRegional ? region! : 'Global',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isRegional ? 11 : 12,
            fontWeight: FontWeight.w600,
            color: isRegional ? const Color(0xFFE65100) : const Color(0xFF34C759),
          ),
        ),
      ]),
    );
  }

  Widget _obtainCard(BuildContext ctx, IconData icon, Color iconColor, String title, String sub) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: neutralBg(ctx), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          if (sub.isNotEmpty)
            Text(sub, style: TextStyle(fontSize: 11,
              color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
        ])),
      ]),
    );
} // fim _GoInfoTabState