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
  final step = _goEvoCost[pokemonId];
  if (step == null) return '';
  final candy = '${step.candy} Doces';
  if (step.extra != null && step.extra!.isNotEmpty) {
    return '$candy + ${step.extra}';
  }
  return candy;
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
  static const _tabs = ['Sobre', 'Status', 'Formas'];

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
              _GoStatusTab(pokemon: widget.pokemon),
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
// ─── CANDY POR FAMÍLIA NO GO ──────────────────────────────────────
// Mapeado pelo ID do Pokémon que RECEBE a evolução (não o base)
// Formato: {idEvolução: (candyCusto, requisitosExtras)}

class _GoEvoStep {
  final int candy;
  final String? extra; // requisito adicional além do candy
  const _GoEvoStep(this.candy, {this.extra});
}

const Map<int, _GoEvoStep> _goEvoCost = {
  // Gen 1
  2:   _GoEvoStep(25),   // Ivysaur
  3:   _GoEvoStep(100),  // Venusaur
  5:   _GoEvoStep(25),   // Charmeleon
  6:   _GoEvoStep(100),  // Charizard
  8:   _GoEvoStep(25),   // Wartortle
  9:   _GoEvoStep(100),  // Blastoise
  11:  _GoEvoStep(12),   // Metapod
  12:  _GoEvoStep(50),   // Butterfree
  14:  _GoEvoStep(12),   // Kakuna
  15:  _GoEvoStep(50),   // Beedrill
  17:  _GoEvoStep(12),   // Pidgeotto
  18:  _GoEvoStep(50),   // Pidgeot
  20:  _GoEvoStep(50),   // Raticate
  22:  _GoEvoStep(50),   // Fearow
  24:  _GoEvoStep(50),   // Arbok
  26:  _GoEvoStep(50),   // Raichu
  28:  _GoEvoStep(50),   // Sandslash
  30:  _GoEvoStep(25),   // Nidorina
  31:  _GoEvoStep(100),  // Nidoqueen
  33:  _GoEvoStep(25),   // Nidorino
  34:  _GoEvoStep(100),  // Nidoking
  36:  _GoEvoStep(50),   // Clefable
  38:  _GoEvoStep(50),   // Ninetales
  40:  _GoEvoStep(50),   // Wigglytuff
  42:  _GoEvoStep(50),   // Golbat
  44:  _GoEvoStep(25),   // Gloom
  45:  _GoEvoStep(100, extra: 'Pedra Solar'), // Vileplume
  47:  _GoEvoStep(50),   // Parasect
  49:  _GoEvoStep(50),   // Venomoth
  51:  _GoEvoStep(50),   // Dugtrio
  53:  _GoEvoStep(50),   // Persian
  55:  _GoEvoStep(50),   // Golduck
  57:  _GoEvoStep(50),   // Primeape
  59:  _GoEvoStep(50),   // Arcanine
  61:  _GoEvoStep(25),   // Poliwhirl
  62:  _GoEvoStep(100),  // Poliwrath
  64:  _GoEvoStep(25),   // Kadabra
  65:  _GoEvoStep(100),  // Alakazam
  67:  _GoEvoStep(25),   // Machoke
  68:  _GoEvoStep(100),  // Machamp
  70:  _GoEvoStep(25),   // Weepinbell
  71:  _GoEvoStep(100),  // Victreebel
  73:  _GoEvoStep(50),   // Tentacruel
  75:  _GoEvoStep(25),   // Graveler
  76:  _GoEvoStep(100),  // Golem
  78:  _GoEvoStep(50),   // Rapidash
  80:  _GoEvoStep(50),   // Slowbro
  82:  _GoEvoStep(50),   // Magneton
  85:  _GoEvoStep(50),   // Dodrio
  87:  _GoEvoStep(50),   // Dewgong
  89:  _GoEvoStep(50),   // Muk
  91:  _GoEvoStep(50),   // Cloyster
  93:  _GoEvoStep(25),   // Haunter
  94:  _GoEvoStep(100, extra: 'Pedra de Sinnoh'), // Gengar
  97:  _GoEvoStep(50),   // Hypno
  99:  _GoEvoStep(50),   // Kingler
  101: _GoEvoStep(50),   // Electrode
  103: _GoEvoStep(50),   // Exeggutor
  105: _GoEvoStep(50),   // Marowak
  110: _GoEvoStep(50),   // Weezing
  112: _GoEvoStep(50),   // Rhydon
  115: _GoEvoStep(50),   // Kangaskhan (regional)
  117: _GoEvoStep(50),   // Seadra
  119: _GoEvoStep(50),   // Seaking
  121: _GoEvoStep(50),   // Starmie
  124: _GoEvoStep(50),   // Jynx
  125: _GoEvoStep(50),   // Electabuzz
  126: _GoEvoStep(50),   // Magmar
  130: _GoEvoStep(400),  // Gyarados
  134: _GoEvoStep(25),   // Vaporeon
  135: _GoEvoStep(25),   // Jolteon
  136: _GoEvoStep(25),   // Flareon
  139: _GoEvoStep(50),   // Omastar
  141: _GoEvoStep(50),   // Kabutops
  143: _GoEvoStep(50),   // Snorlax
  // Gen 2
  153: _GoEvoStep(25),
  154: _GoEvoStep(100),
  156: _GoEvoStep(25),
  157: _GoEvoStep(100),
  159: _GoEvoStep(25),
  160: _GoEvoStep(100),
  162: _GoEvoStep(50),
  164: _GoEvoStep(50),
  166: _GoEvoStep(50),
  168: _GoEvoStep(50),
  170: _GoEvoStep(25),
  171: _GoEvoStep(50),
  178: _GoEvoStep(50),
  182: _GoEvoStep(50, extra: 'Pedra Solar'), // Bellossom
  184: _GoEvoStep(50),
  186: _GoEvoStep(100, extra: 'Pedra do Rei'), // Politoed
  188: _GoEvoStep(25),
  189: _GoEvoStep(100),
  192: _GoEvoStep(50, extra: 'Pedra Solar'), // Sunflora
  196: _GoEvoStep(25, extra: 'Espeon: 10km como Buddy + durante o dia'),
  197: _GoEvoStep(25, extra: 'Umbreon: 10km como Buddy + durante a noite'),
  199: _GoEvoStep(50, extra: 'Pedra do Rei'), // Slowking
  202: _GoEvoStep(50),
  205: _GoEvoStep(50),
  208: _GoEvoStep(50, extra: 'Casaco de Metal'), // Steelix
  210: _GoEvoStep(50),
  212: _GoEvoStep(50, extra: 'Casaco de Metal'), // Scizor
  214: _GoEvoStep(50),
  215: _GoEvoStep(50),
  219: _GoEvoStep(50),
  221: _GoEvoStep(50),
  224: _GoEvoStep(50),
  226: _GoEvoStep(50),
  229: _GoEvoStep(50),
  230: _GoEvoStep(100, extra: 'Escama de Dragão'), // Kingdra
  232: _GoEvoStep(50),
  233: _GoEvoStep(50, extra: 'Módulo de Upgrade'), // Porygon2
  237: _GoEvoStep(50),
  241: _GoEvoStep(50),
  // Gen 3+
  256: _GoEvoStep(25),
  257: _GoEvoStep(100),
  259: _GoEvoStep(25),
  260: _GoEvoStep(100),
  262: _GoEvoStep(50),
  264: _GoEvoStep(50),
  267: _GoEvoStep(12),
  269: _GoEvoStep(50),
  272: _GoEvoStep(50),
  275: _GoEvoStep(50),
  277: _GoEvoStep(12),
  279: _GoEvoStep(50),
  282: _GoEvoStep(50),
  284: _GoEvoStep(50),
  286: _GoEvoStep(50),
  291: _GoEvoStep(50),
  295: _GoEvoStep(50),
  297: _GoEvoStep(50),
  301: _GoEvoStep(50),
  303: _GoEvoStep(50),
  306: _GoEvoStep(50),
  308: _GoEvoStep(50),
  310: _GoEvoStep(50),
  315: _GoEvoStep(25),
  407: _GoEvoStep(100, extra: 'Pedra Solar'), // Roserade
  319: _GoEvoStep(50),
  323: _GoEvoStep(50),
  330: _GoEvoStep(50),
  334: _GoEvoStep(50),
  340: _GoEvoStep(50),
  342: _GoEvoStep(50),
  344: _GoEvoStep(50),
  346: _GoEvoStep(50),
  348: _GoEvoStep(50),
  350: _GoEvoStep(100, extra: 'Caminhar 20km como Buddy'), // Milotic
  354: _GoEvoStep(50),
  357: _GoEvoStep(50),
  362: _GoEvoStep(50),
  365: _GoEvoStep(50),
  368: _GoEvoStep(50),
  370: _GoEvoStep(50),
  373: _GoEvoStep(50),
  376: _GoEvoStep(50),
  380: _GoEvoStep(50),
  381: _GoEvoStep(50),
  // Sinnoh
  398: _GoEvoStep(50),
  400: _GoEvoStep(50),
  402: _GoEvoStep(25),
  403: _GoEvoStep(25),
  404: _GoEvoStep(100),
  407: _GoEvoStep(100, extra: 'Pedra Solar'),
  409: _GoEvoStep(50),
  411: _GoEvoStep(50),
  414: _GoEvoStep(50),
  416: _GoEvoStep(50),
  418: _GoEvoStep(50),
  419: _GoEvoStep(100),
  421: _GoEvoStep(50),
  424: _GoEvoStep(50),
  426: _GoEvoStep(50),
  430: _GoEvoStep(50),
  432: _GoEvoStep(50),
  435: _GoEvoStep(50),
  437: _GoEvoStep(50),
  441: _GoEvoStep(50),
  448: _GoEvoStep(50),
  450: _GoEvoStep(50),
  452: _GoEvoStep(50),
  454: _GoEvoStep(50),
  457: _GoEvoStep(50),
  460: _GoEvoStep(100),
  461: _GoEvoStep(100, extra: 'Pedra de Sinnoh'),
  462: _GoEvoStep(100, extra: 'Pedra de Sinnoh ou Módulo de Isca Magnética'),
  463: _GoEvoStep(100, extra: 'Pedra de Sinnoh'),
  464: _GoEvoStep(100, extra: 'Pedra de Sinnoh'),
  465: _GoEvoStep(100, extra: 'Pedra de Sinnoh'),
  466: _GoEvoStep(100, extra: 'Pedra de Sinnoh'),
  467: _GoEvoStep(100, extra: 'Pedra de Sinnoh'),
  468: _GoEvoStep(100, extra: 'Pedra de Sinnoh'),
  469: _GoEvoStep(100, extra: 'Pedra de Sinnoh'),
  470: _GoEvoStep(25, extra: 'Módulo de Isca Musgosa'),  // Leafeon
  471: _GoEvoStep(25, extra: 'Módulo de Isca Glacial'),  // Glaceon
  472: _GoEvoStep(100, extra: 'Pedra de Sinnoh'),
  473: _GoEvoStep(100, extra: 'Pedra de Sinnoh'),
  474: _GoEvoStep(100, extra: 'Módulo de Upgrade'),
  // Unova+
  503: _GoEvoStep(50),
  505: _GoEvoStep(50),
  508: _GoEvoStep(50),
  510: _GoEvoStep(50),
  512: _GoEvoStep(50),
  514: _GoEvoStep(50),
  516: _GoEvoStep(50),
  518: _GoEvoStep(50),
  521: _GoEvoStep(50),
  523: _GoEvoStep(50),
  525: _GoEvoStep(25),
  526: _GoEvoStep(100, extra: 'Pedra de Unova'),
  528: _GoEvoStep(50),
  530: _GoEvoStep(50, extra: 'Pedra de Unova'),
  534: _GoEvoStep(50),
  537: _GoEvoStep(50),
  542: _GoEvoStep(50),
  545: _GoEvoStep(50),
  547: _GoEvoStep(50, extra: 'Módulo de Isca Floral'),
  549: _GoEvoStep(50, extra: 'Pedra de Unova'),
  553: _GoEvoStep(50, extra: 'Pedra de Unova'),
  560: _GoEvoStep(50, extra: 'Pedra de Unova'),
  579: _GoEvoStep(50, extra: 'Pedra de Unova'),
  591: _GoEvoStep(50),
  617: _GoEvoStep(50, extra: 'Pedra de Unova + troca com Karrablast'),
  589: _GoEvoStep(50, extra: 'Pedra de Unova + troca com Shelmet'),
  // Kalos+
  700: _GoEvoStep(25, extra: 'Sylveon: 70 Corações com Buddy'),
  // Outros comuns
  658: _GoEvoStep(50),
  673: _GoEvoStep(50),
  675: _GoEvoStep(50, extra: 'Capturar 32 Pokémon tipo Sombrio como Buddy'),
  683: _GoEvoStep(50, extra: 'Usar Incenso'),
  686: _GoEvoStep(50, extra: 'Dar 25 doces ao Buddy'),
  706: _GoEvoStep(100, extra: 'Tempo chuvoso ou neblinoso'),
};

// ─── ABA STATUS GO ────────────────────────────────────────────────
// Mostra stats GO (Ataque, Defesa, Stamina, CP máx) +
// Efetividade de tipos com multiplicadores corretos do GO:
//   Super efetivo: 1.6x | Resistência: 0.625x
//   "Imune" (sem imunidade no GO): 0.391x (dupla resistência)

class _GoStatusTab extends StatefulWidget {
  final Pokemon pokemon;
  const _GoStatusTab({required this.pokemon});
  @override
  State<_GoStatusTab> createState() => _GoStatusTabState();
}

class _GoStatusTabState extends State<_GoStatusTab> {
  int _goAtk = 0, _goDef = 0, _goSta = 0;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadGoStats();
  }

  Future<void> _loadGoStats() async {
    // Tentar do bundle local primeiro
    try {
      final svc = PokedexDataService.instance;
      final raw = svc.get(widget.pokemon.id);
      final goAtk = raw?['go_atk'] as int?;
      final goDef = raw?['go_def'] as int?;
      final goSta = raw?['go_sta'] as int?;
      if (goAtk != null && goAtk > 0 && mounted) {
        setState(() {
          _goAtk = goAtk; _goDef = goDef ?? 0; _goSta = goSta ?? 0;
          _loadingStats = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback: pogoapi.net
    try {
      final r = await http.get(Uri.parse('https://pogoapi.net/api/v1/pokemon_stats.json'));
      if (r.statusCode == 200 && mounted) {
        final body = json.decode(r.body);
        final list = body is List ? body : (body as Map).values.toList();
        for (final p in list) {
          final pid = p['id'] ?? p['pokemon_id'];
          if (pid != null && (pid as num).toInt() == widget.pokemon.id) {
            final atk = (p['base_attack'] ?? p['attack'] ?? 0) as num;
            final def = (p['base_defense'] ?? p['defense'] ?? 0) as num;
            final sta = (p['base_stamina'] ?? p['stamina'] ?? 0) as num;
            if (atk.toInt() > 0 && mounted) {
              setState(() {
                _goAtk = atk.toInt(); _goDef = def.toInt(); _goSta = sta.toInt();
                _loadingStats = false;
              });
              return;
            }
            break;
          }
        }
      }
    } catch (_) {}

    // Fallback: calcular via PokeAPI
    try {
      final r = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/${widget.pokemon.id}'));
      if (r.statusCode == 200 && mounted) {
        final d = json.decode(r.body) as Map<String, dynamic>;
        final stats = d['stats'] as List<dynamic>;
        int atk = 0, spatk = 0, def = 0, spdef = 0, hp = 0, spd = 0;
        for (final s in stats) {
          final sname = s['stat']['name'] as String;
          final base  = (s['base_stat'] as num).toInt();
          switch (sname) {
            case 'attack': atk = base; break;
            case 'special-attack': spatk = base; break;
            case 'defense': def = base; break;
            case 'special-defense': spdef = base; break;
            case 'hp': hp = base; break;
            case 'speed': spd = base; break;
          }
        }
        final speedMod = 1 + (spd - 75) / 500;
        final higherAtk = atk >= spatk ? atk : spatk;
        final lowerAtk  = atk >= spatk ? spatk : atk;
        final higherDef = def >= spdef ? def : spdef;
        final lowerDef  = def >= spdef ? spdef : def;
        const scale = 2.0;
        final goAtk = ((7 * higherAtk + lowerAtk) / 8 * speedMod * scale).round().clamp(1, 999);
        final goDef = ((5 * higherDef + 3 * lowerDef) / 8 * speedMod * scale).round().clamp(1, 999);
        final goSta = (hp * 1.75 + 50).floor().clamp(20, 9999);
        if (mounted) setState(() {
          _goAtk = goAtk; _goDef = goDef; _goSta = goSta;
          _loadingStats = false;
        });
      }
    } catch (_) {}

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
    double sqrtD(num n) {
      if (n <= 0) return 0;
      double x = n.toDouble();
      for (int i = 0; i < 30; i++) x = (x + n / x) / 2;
      return x;
    }
    final cp = ((_goAtk + 15) * sqrtD(_goDef + 15) *
        sqrtD(_goSta + 15) * cpm40 * cpm40 / 10).floor();
    return cp < 10 ? 10 : cp;
  }

  // Calcula efetividade com multiplicadores GO
  // GO: 1.6x (SE), 0.625x (NVE), 0.391x ("imune" = dupla resistência)
  Map<String, List<String>> _goEffectiveness() {
    final types = widget.pokemon.types;
    if (types.isEmpty) return {};

    // Tabela de relações (mesma dos jogos principais)
    const chart = {
      'normal':   {'fighting': 2.0, 'ghost': 0.0},
      'fire':     {'water': 2.0, 'ground': 2.0, 'rock': 2.0,
                   'fire': 0.5, 'grass': 0.5, 'ice': 0.5, 'bug': 0.5, 'steel': 0.5, 'fairy': 0.5},
      'water':    {'electric': 2.0, 'grass': 2.0,
                   'fire': 0.5, 'water': 0.5, 'ice': 0.5, 'steel': 0.5},
      'electric': {'ground': 2.0,
                   'electric': 0.5, 'flying': 0.5, 'steel': 0.5},
      'grass':    {'fire': 2.0, 'ice': 2.0, 'poison': 2.0, 'flying': 2.0, 'bug': 2.0,
                   'water': 0.5, 'electric': 0.5, 'grass': 0.5, 'ground': 0.5},
      'ice':      {'fire': 2.0, 'fighting': 2.0, 'rock': 2.0, 'steel': 2.0,
                   'ice': 0.5},
      'fighting': {'flying': 2.0, 'psychic': 2.0, 'fairy': 2.0,
                   'bug': 0.5, 'rock': 0.5, 'dark': 0.5,
                   'ghost': 0.0},
      'poison':   {'ground': 2.0, 'psychic': 2.0,
                   'grass': 0.5, 'fighting': 0.5, 'poison': 0.5, 'bug': 0.5, 'fairy': 0.5,
                   'steel': 0.0},
      'ground':   {'water': 2.0, 'grass': 2.0, 'ice': 2.0,
                   'poison': 0.5, 'rock': 0.5,
                   'electric': 0.0},
      'flying':   {'electric': 2.0, 'ice': 2.0, 'rock': 2.0,
                   'grass': 0.5, 'fighting': 0.5, 'bug': 0.5,
                   'ground': 0.0},
      'psychic':  {'bug': 2.0, 'ghost': 2.0, 'dark': 2.0,
                   'fighting': 0.5, 'psychic': 0.5,
                   'dark': 0.0},
      'bug':      {'fire': 2.0, 'flying': 2.0, 'rock': 2.0,
                   'grass': 0.5, 'fighting': 0.5, 'ground': 0.5},
      'rock':     {'water': 2.0, 'grass': 2.0, 'fighting': 2.0, 'ground': 2.0, 'steel': 2.0,
                   'normal': 0.5, 'fire': 0.5, 'poison': 0.5, 'flying': 0.5},
      'ghost':    {'ghost': 2.0, 'dark': 2.0,
                   'poison': 0.5, 'bug': 0.5,
                   'normal': 0.0, 'fighting': 0.0},
      'dragon':   {'ice': 2.0, 'dragon': 2.0, 'fairy': 2.0,
                   'fire': 0.5, 'water': 0.5, 'electric': 0.5, 'grass': 0.5},
      'dark':     {'fighting': 2.0, 'bug': 2.0, 'fairy': 2.0,
                   'ghost': 0.5, 'dark': 0.5,
                   'psychic': 0.0},
      'steel':    {'fire': 2.0, 'fighting': 2.0, 'ground': 2.0,
                   'normal': 0.5, 'grass': 0.5, 'ice': 0.5, 'flying': 0.5,
                   'psychic': 0.5, 'bug': 0.5, 'rock': 0.5, 'dragon': 0.5,
                   'steel': 0.5, 'fairy': 0.5,
                   'poison': 0.0},
      'fairy':    {'poison': 2.0, 'steel': 2.0,
                   'fighting': 0.5, 'bug': 0.5, 'dark': 0.5,
                   'dragon': 0.0},
    };

    const allTypes = ['normal','fire','water','electric','grass','ice','fighting',
      'poison','ground','flying','psychic','bug','rock','ghost','dragon','dark','steel','fairy'];

    // Calcular multiplicador para cada tipo atacante
    final Map<String, double> mult = {};
    for (final attacker in allTypes) {
      double m = 1.0;
      for (final defender in types) {
        final rel = (chart[defender] ?? {})[attacker] ?? 1.0;
        m *= rel;
      }
      mult[attacker] = m;
    }

    // Converter multiplicadores para GO
    // 0.0 (imune) → 0.391x no GO (dupla resistência)
    // 0.25 → 0.391x no GO (1.6^-2)
    // 0.5 → 0.625x
    // 1.0 → 1.0x
    // 2.0 → 1.6x
    // 4.0 → 2.56x
    double toGo(double m) {
      if (m == 0.0) return 0.391;  // imune → dupla resistência no GO
      if (m == 0.25) return 0.391; // dupla resistência
      if (m == 0.5)  return 0.625;
      if (m == 2.0)  return 1.6;
      if (m == 4.0)  return 2.56;
      return m;
    }

    final groups = <String, List<String>>{
      '2.56x': [],
      '1.6x':  [],
      '0.625x': [],
      '0.391x': [],
    };

    for (final entry in mult.entries) {
      final go = toGo(entry.value);
      if (go == 2.56)  groups['2.56x']!.add(entry.key);
      else if (go == 1.6)   groups['1.6x']!.add(entry.key);
      else if (go == 0.625) groups['0.625x']!.add(entry.key);
      else if (go == 0.391) groups['0.391x']!.add(entry.key);
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = neutralBorder(context);
    final bg     = neutralBg(context);
    final effectiveness = _goEffectiveness();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Stats GO ─────────────────────────────────────────────
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
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      Text('$_maxCp',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
        ),

        const SizedBox(height: 20),

        // ── Efetividade de Tipos GO ───────────────────────────────
        secTitle(context, 'EFETIVIDADE NO GO'),
        Text('Multiplicadores do Pokémon GO: SE=1.6x | Resist.=0.625x | Dupla Resist./Imune=0.391x',
          style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant, height: 1.4)),
        const SizedBox(height: 10),

        for (final entry in [
          ('2.56x', 'Muito fraco a', const Color(0xFFB71C1C)),
          ('1.6x',  'Fraco a',       const Color(0xFFE53935)),
          ('0.625x', 'Resistente a', const Color(0xFF388E3C)),
          ('0.391x', 'Muito resistente a', const Color(0xFF1B5E20)),
        ])
          if (effectiveness[entry.$1] != null && effectiveness[entry.$1]!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(entry.$2,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: entry.$3)),
            ),
            Wrap(
              spacing: 4, runSpacing: 4,
              children: effectiveness[entry.$1]!.map((t) => TypeBadge(type: t)).toList(),
            ),
            const SizedBox(height: 12),
          ],

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
}

