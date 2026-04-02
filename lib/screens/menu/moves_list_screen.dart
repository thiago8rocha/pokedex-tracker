import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:dexcurator/theme/type_colors.dart';
import 'package:dexcurator/screens/detail/detail_shared.dart'
    show ptType, typeIconAsset, typeTextColor, neutralBg, kApiBase, PokeballLoader;
import 'package:dexcurator/services/storage_service.dart';
import 'package:dexcurator/services/pokeapi_service.dart';
import 'package:dexcurator/services/dex_bundle_service.dart';
import 'package:dexcurator/services/move_warmup_service.dart';
import 'package:dexcurator/translations.dart';
import 'package:dexcurator/screens/menu/move_detail_screen.dart';

// ─── Modelo público ───────────────────────────────────────────────
class MoveEntry {
  final String nameEn;
  final String url;
  String    typeEn     = '';
  String    category   = '';
  int?      power;
  int?      accuracy;
  int?      pp;
  String    effect     = '';
  String    flavor     = '';
  List<int> pokemonIds = [];
  MoveEntry({required this.nameEn, required this.url});
}

// ─── Dados dos jogos (mesmo formato da home) ──────────────────────
const _gamesByGen = <int, List<Map<String, dynamic>>>{
  1: [
    {'name': 'Red / Blue',            'id': 'red___blue',                   'c1': 0xFFE53935, 'c2': 0xFF1565C0},
    {'name': 'Yellow',                'id': 'yellow',                       'c1': 0xFFFDD835, 'c2': 0xFFFF8F00},
  ],
  2: [
    {'name': 'Gold / Silver',         'id': 'gold___silver',                'c1': 0xFFFFCA28, 'c2': 0xFFB0BEC5},
    {'name': 'Crystal',               'id': 'crystal',                      'c1': 0xFF29B6F6, 'c2': 0xFFE1F5FE},
  ],
  3: [
    {'name': 'Ruby / Sapphire',       'id': 'ruby___sapphire',              'c1': 0xFFE53935, 'c2': 0xFF1E88E5},
    {'name': 'FireRed / LeafGreen',   'id': 'firered___leafgreen_(gba)',     'c1': 0xFFEF5350, 'c2': 0xFF43A047},
    {'name': 'Emerald',               'id': 'emerald',                      'c1': 0xFF43A047, 'c2': 0xFF00BCD4},
  ],
  4: [
    {'name': 'Diamond / Pearl',       'id': 'diamond___pearl',              'c1': 0xFF90CAF9, 'c2': 0xFFF48FB1},
    {'name': 'Platinum',              'id': 'platinum',                     'c1': 0xFF78909C, 'c2': 0xFFCFD8DC},
    {'name': 'HeartGold / SoulSilver','id': 'heartgold___soulsilver',       'c1': 0xFFFFCA28, 'c2': 0xFFB0BEC5},
  ],
  5: [
    {'name': 'Black / White',         'id': 'black___white',                'c1': 0xFF424242, 'c2': 0xFFBDBDBD},
    {'name': 'Black 2 / White 2',     'id': 'black_2___white_2',            'c1': 0xFF1A237E, 'c2': 0xFFE0E0E0},
  ],
  6: [
    {'name': 'X / Y',                 'id': 'x___y',                        'c1': 0xFF1565C0, 'c2': 0xFFE53935},
    {'name': 'Omega Ruby / Alpha Sapphire', 'id': 'omega_ruby___alpha_sapphire', 'c1': 0xFFE53935, 'c2': 0xFF1E88E5},
  ],
  7: [
    {'name': 'Sun / Moon',            'id': 'sun___moon',                   'c1': 0xFFFF8F00, 'c2': 0xFF7B1FA2},
    {'name': 'Ultra Sun / Ultra Moon','id': 'ultra_sun___ultra_moon',       'c1': 0xFFFF6F00, 'c2': 0xFF4A148C},
    {'name': "Let's Go Pikachu / Eevee", 'id': 'lets_go_pikachu___eevee',  'c1': 0xFFFDD835, 'c2': 0xFF8D6E63},
  ],
  8: [
    {'name': 'Sword / Shield',        'id': 'sword___shield',               'c1': 0xFF42A5F5, 'c2': 0xFFEF5350},
    {'name': 'Brilliant Diamond / Shining Pearl', 'id': 'brilliant_diamond___shining_pearl', 'c1': 0xFF42A5F5, 'c2': 0xFFEC407A},
    {'name': 'Legends: Arceus',       'id': 'legends_arceus',               'c1': 0xFFFFCA28, 'c2': 0xFFFFFDE7},
  ],
  9: [
    {'name': 'Scarlet / Violet',      'id': 'scarlet___violet',             'c1': 0xFFEF6C00, 'c2': 0xFF7B1FA2},
    {'name': 'Legends: Z-A',          'id': 'legends_z-a',                  'c1': 0xFF546E7A, 'c2': 0xFFFFD54F},
  ],
};

const _specialGames = <Map<String, dynamic>>[
  {'name': 'Nacional', 'id': 'nacional', 'c1': 0xFFE8524A, 'c2': 0xFFB71C1C},
];

// ─── Tela principal ───────────────────────────────────────────────
class MovesListScreen extends StatefulWidget {
  const MovesListScreen({super.key});
  @override State<MovesListScreen> createState() => _MovesListScreenState();
}

class _MovesListScreenState extends State<MovesListScreen> {
  List<MoveEntry> _allMoves  = [];
  List<MoveEntry> _filtered  = [];
  bool            _loading   = true;
  String          _search    = '';
  String?         _typeFilter;
  String?         _catFilter;
  String          _activeGameId    = 'scarlet___violet';
  String          _activeGameName  = 'Scarlet / Violet';
  int             _activeGameC1    = 0xFFEF6C00;
  int             _activeGameC2    = 0xFF7B1FA2;

  // Cache compartilhado: começa com o warmup, preenchido também pela tela
  Map<String, Map<String, dynamic>> get _detailCache => MoveWarmupService.cache;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _initGame() async {
    final lastDex = await StorageService().getLastPokedexId();
    if (lastDex != null && !lastDex.startsWith('pokopia') && lastDex != 'pokémon_go') {
      // Encontrar o jogo correspondente nos dados
      for (final gen in _gamesByGen.values) {
        for (final g in gen) {
          if (g['id'] == lastDex) {
            _activeGameId   = lastDex;
            _activeGameName = g['name'] as String;
            _activeGameC1   = g['c1'] as int;
            _activeGameC2   = g['c2'] as int;
            break;
          }
        }
      }
    }
    _loadMoves();
  }

  Future<void> _loadMoves() async {
    setState(() { _loading = true; _allMoves = []; _filtered = []; });

    // Tentar carregar do move_map.json local (instantâneo, sem rede)
    final localMap = await _tryLoadMoveMap();
    if (localMap != null) {
      await _loadFromMoveMap(localMap);
    } else {
      await _loadFromApi();
    }
  }

  // Carrega move_map.json uma vez e cacheia
  static Map<String, dynamic>? _moveMapData;
  Future<Map<String, dynamic>?> _tryLoadMoveMap() async {
    if (_moveMapData != null) return _moveMapData;
    try {
      final raw = await rootBundle.loadString('assets/data/move_map.json');
      _moveMapData = jsonDecode(raw) as Map<String, dynamic>;
      return _moveMapData;
    } catch (_) { return null; }
  }

  Future<void> _loadFromMoveMap(Map<String, dynamic> localMap) async {
    // Obter IDs do jogo ativo
    final gameIds = await _getGameIds();

    final entries = <MoveEntry>[];
    for (final kv in localMap.entries) {
      final nameEn    = kv.key;
      final data      = kv.value as Map<String, dynamic>;
      final allPoke   = (data['pokemon'] as List<dynamic>).cast<int>();
      final gamePoke  = gameIds.isEmpty
          ? allPoke
          : allPoke.where((id) => gameIds.contains(id)).toList();
      if (gamePoke.isEmpty && gameIds.isNotEmpty) continue;

      final e = MoveEntry(nameEn: nameEn, url: '$kApiBase/move/$nameEn');
      e.typeEn     = data['type']   as String? ?? '';
      e.category   = data['cat']    as String? ?? '';
      e.power      = data['power']  as int?;
      e.accuracy   = data['acc']    as int?;
      e.pp         = data['pp']     as int?;
      e.effect     = data['effect'] as String? ?? '';
      e.flavor     = data['flavor'] as String? ?? '';
      e.pokemonIds = gamePoke;
      entries.add(e);
    }
    entries.sort((a, b) => translateMove(a.nameEn).compareTo(translateMove(b.nameEn)));
    if (mounted) setState(() { _allMoves = entries; _applyFilters(); _loading = false; });
  }

  Future<Set<int>> _getGameIds() async {
    final sections = PokeApiService.pokedexSections[_activeGameId] ?? [];
    final ids = <int>{};
    for (final s in sections) {
      final entries = await DexBundleService.instance.loadSection(s.apiName);
      if (entries != null) for (final e in entries) ids.add(e['speciesId']!);
    }
    return ids;
  }

  // Fallback via API quando move_map.json não existe
  Future<void> _loadFromApi() async {
    final gameIds = await _getGameIds();
    final ids = gameIds.isEmpty
        ? List.generate(1025, (i) => i + 1) : gameIds.toList()..sort();
    final moveMap = <String, MoveEntry>{};
    for (int i = 0; i < ids.length; i += 15) {
      if (!mounted) return;
      final batch = ids.skip(i).take(15).toList();
      await Future.wait(batch.map((id) async {
        try {
          final res = await http.get(Uri.parse('$kApiBase/pokemon/$id'))
              .timeout(const Duration(seconds: 8));
          if (res.statusCode != 200) return;
          final data  = jsonDecode(res.body) as Map<String, dynamic>;
          for (final m in data['moves'] as List<dynamic>? ?? []) {
            final nameEn = m['move']['name'] as String;
            final url    = m['move']['url'] as String;
            if (!moveMap.containsKey(nameEn)) {
              final e = MoveEntry(nameEn: nameEn, url: url);
              _applyCacheToEntry(e);
              moveMap[nameEn] = e;
            }
          }
        } catch (_) {}
      }));
      if (mounted) setState(() {
        _allMoves = _sortedMoves(moveMap);
        _applyFilters();
        _loading = false;
      });
    }
    _fillMissingFromApi(moveMap.values.toList());
  }

  void _applyCacheToEntry(MoveEntry e) {
    final d = _detailCache[e.url];
    if (d == null) return;
    e.typeEn   = d['type']?['name'] as String? ?? '';
    e.category = d['damage_class']?['name'] as String? ?? '';
    e.power    = d['power'] as int?;
    e.accuracy = d['accuracy'] as int?;
    e.pp       = d['pp'] as int?;
  }

  Future<void> _fillMissingFromApi(List<MoveEntry> moves) async {
    final missing = moves.where((m) => m.typeEn.isEmpty).toList();
    for (int i = 0; i < missing.length; i += 20) {
      if (!mounted) return;
      await Future.wait(missing.skip(i).take(20).map((e) => _loadDetail(e.url)));
      for (final e in _allMoves) _applyCacheToEntry(e);
      if (mounted) setState(() {});
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<Map<String, dynamic>?> _loadDetail(String url) async {
    if (_detailCache.containsKey(url)) {
      _applyToAll(url, _detailCache[url]!);
      return _detailCache[url];
    }
    try {
      final res = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body) as Map<String, dynamic>;
        _detailCache[url] = d;
        _applyToAll(url, d);
        return d;
      }
    } catch (_) {}
    return null;
  }

  void _applyToAll(String url, Map<String, dynamic> d) {
    for (final e in _allMoves) {
      if (e.url == url) {
        e.typeEn   = d['type']?['name'] as String? ?? '';
        e.category = d['damage_class']?['name'] as String? ?? '';
        e.power    = d['power'] as int?;
        e.accuracy = d['accuracy'] as int?;
        e.pp       = d['pp'] as int?;
      }
    }
  }

  List<MoveEntry> _sortedMoves(Map<String, MoveEntry> map) =>
      map.values.toList()
        ..sort((a, b) => translateMove(a.nameEn).compareTo(translateMove(b.nameEn)));

  void _applyFilters() {
    var list = _allMoves;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((m) {
        final pt = translateMove(m.nameEn).toLowerCase();
        return m.nameEn.toLowerCase().contains(q) || pt.contains(q);
      }).toList();
    }
    if (_typeFilter != null) list = list.where((m) => m.typeEn == _typeFilter).toList();
    if (_catFilter  != null) list = list.where((m) => m.category == _catFilter).toList();
    _filtered = list;
  }

  void _changeGame(Map<String, dynamic> game) {
    setState(() {
      _activeGameId   = game['id'] as String;
      _activeGameName = game['name'] as String;
      _activeGameC1   = game['c1'] as int;
      _activeGameC2   = game['c2'] as int;
      _typeFilter = null;
      _catFilter  = null;
      _search     = '';
    });
    // Disparar warmup para o novo jogo
    MoveWarmupService.startForGame(_activeGameId);
    _loadMoves();
  }

  void _showGamePicker() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _MoveGamePickerSheet(selectedId: _activeGameId),
    );
    if (result != null && mounted) _changeGame(result);
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _FilterSheet(
        selectedType: _typeFilter,
        selectedCat:  _catFilter,
        onApply: (type, cat) => setState(() {
          _typeFilter = type; _catFilter = cat; _applyFilters();
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme    = Theme.of(context).colorScheme;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final opacity   = isDark ? 0.45 : 0.28;
    final hasFilter = _typeFilter != null || _catFilter != null;
    final c1 = Color(_activeGameC1);
    final c2 = Color(_activeGameC2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Golpes'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Badge(isLabelVisible: hasFilter,
                child: const Icon(Icons.filter_list_outlined)),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(children: [
        // Seletor de jogo — mesmo visual da home
        GestureDetector(
          onTap: _showGamePicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft, end: Alignment.centerRight,
                colors: [c1.withOpacity(opacity), c2.withOpacity(opacity)]),
            ),
            child: Row(children: [
              Expanded(child: Text(_activeGameName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              Text('${_filtered.length} golpes',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 6),
              Icon(Icons.expand_more, size: 18, color: scheme.onSurfaceVariant),
            ]),
          ),
        ),

        // Busca
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() { _search = v; _applyFilters(); }),
            decoration: InputDecoration(
              hintText: 'Buscar golpe...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: scheme.outlineVariant)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: scheme.outlineVariant)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
          ),
        ),

        // Chips ativos
        if (hasFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(children: [
              if (_typeFilter != null) _ActiveChip(
                label: ptType(_typeFilter!),
                onRemove: () => setState(() { _typeFilter = null; _applyFilters(); })),
              if (_catFilter != null) ...[
                const SizedBox(width: 6),
                _ActiveChip(
                  label: _catFilter == 'physical' ? 'Físico'
                      : _catFilter == 'special' ? 'Especial' : 'Status',
                  onRemove: () => setState(() { _catFilter = null; _applyFilters(); })),
              ],
            ]),
          ),

        // Lista
        Expanded(
          child: _loading && _filtered.isEmpty
              ? Center(child: PokeballLoader())
              : _filtered.isEmpty
                  ? Center(child: Text('Nenhum golpe encontrado',
                      style: TextStyle(color: scheme.onSurfaceVariant)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) => _MoveCard(
                        entry: _filtered[i],
                        onTap: () => Navigator.push(ctx, MaterialPageRoute(
                          builder: (_) => MoveDetailScreen(
                            entry:        _filtered[i],
                            activeGameId: _activeGameId,
                            detailCache:  _detailCache,
                            loadDetail:   _loadDetail,
                          ),
                        )),
                      ),
                    ),
        ),
      ]),
    );
  }
}

// ─── Game picker sheet — visual igual à home ──────────────────────
class _MoveGamePickerSheet extends StatelessWidget {
  final String selectedId;
  const _MoveGamePickerSheet({required this.selectedId});

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final opacity = isDark ? 0.45 : 0.28;

    Widget card(Map<String, dynamic> g) {
      final id  = g['id'] as String;
      final c1  = Color(g['c1'] as int);
      final c2  = Color(g['c2'] as int);
      final sel = id == selectedId;
      return GestureDetector(
        onTap: () => Navigator.pop(context, g),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [c1.withOpacity(opacity), c2.withOpacity(opacity)]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel ? scheme.primary : scheme.outlineVariant,
              width: sel ? 2 : 1)),
          child: Row(children: [
            Expanded(child: Text(g['name'] as String,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: sel ? scheme.primary : scheme.onSurface))),
            if (sel) Icon(Icons.check_circle, size: 16, color: scheme.primary),
          ]),
        ),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(
            color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Selecionar Jogo',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(child: ListView(controller: ctrl, padding: const EdgeInsets.all(12),
          children: [
            ..._specialGames.map(card),
            const SizedBox(height: 4),
            ..._gamesByGen.entries.map((entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
                    child: Text('Geração ${entry.key}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant, letterSpacing: 0.5))),
                ...entry.value.map(card),
              ],
            )),
          ],
        )),
      ]),
    );
  }
}

// ─── Card de golpe ────────────────────────────────────────────────
class _MoveCard extends StatelessWidget {
  final MoveEntry entry; final VoidCallback onTap;
  const _MoveCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme    = Theme.of(context).colorScheme;
    final namePt    = translateMove(entry.nameEn);
    final typeEn    = entry.typeEn;
    final typePt    = typeEn.isNotEmpty ? ptType(typeEn) : '';
    final typeColor = typeEn.isNotEmpty
        ? TypeColors.fromType(typePt) : scheme.surfaceContainerHighest;
    final catName   = entry.category;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: scheme.outlineVariant, width: 0.5)),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 6),
            child: Row(children: [
              Expanded(child: Text(namePt,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              _Stat('POD',  entry.power    != null ? '${entry.power}'     : '—'),
              const SizedBox(width: 10),
              _Stat('PREC', entry.accuracy != null ? '${entry.accuracy}%' : '—'),
              const SizedBox(width: 10),
              _Stat('PP',   entry.pp       != null ? '${entry.pp}'        : '—'),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 14,
                  color: scheme.onSurfaceVariant.withOpacity(0.4)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(children: [
              if (typeEn.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: typeColor, borderRadius: BorderRadius.circular(4)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset(typeIconAsset(typeEn), width: 11, height: 11,
                        errorBuilder: (_, __, ___) => const SizedBox()),
                    const SizedBox(width: 4),
                    Text(typePt, style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: typeTextColor(typeColor))),
                  ]),
                )
              else
                Container(width: 52, height: 20, decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 8),
              if (catName.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('assets/categories/$catName.png', width: 37, height: 16, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox()),
                const SizedBox(width: 4),
                Text(catName == 'physical' ? 'Físico'
                    : catName == 'special' ? 'Especial' : 'Status',
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);
  @override Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    Text(label, style: TextStyle(fontSize: 9,
        color: Theme.of(context).colorScheme.onSurfaceVariant)),
  ]);
}

class _ActiveChip extends StatelessWidget {
  final String label; final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});
  @override Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 11, color: scheme.onPrimaryContainer)),
        const SizedBox(width: 4),
        GestureDetector(onTap: onRemove,
            child: Icon(Icons.close, size: 13, color: scheme.onPrimaryContainer)),
      ]),
    );
  }
}

// ─── Filter sheet ─────────────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  final String? selectedType, selectedCat;
  final void Function(String?, String?) onApply;
  const _FilterSheet({required this.selectedType, required this.selectedCat,
      required this.onApply});
  @override State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _type, _cat;
  static const _types = [
    'normal','fighting','flying','poison','ground','rock',
    'bug','ghost','steel','fire','water','grass',
    'electric','psychic','ice','dragon','dark','fairy',
  ];
  @override void initState() { super.initState(); _type = widget.selectedType; _cat = widget.selectedCat; }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Filtrar golpes', style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          TextButton(onPressed: () => setState(() { _type = null; _cat = null; }),
              child: const Text('Limpar')),
        ]),
        const SizedBox(height: 10),
        Text('TIPO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: _types.map((t) {
          final sel = _type == t;
          final tc  = TypeColors.fromType(ptType(t));
          return GestureDetector(
            onTap: () => setState(() => _type = sel ? null : t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: sel ? tc : tc.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: sel ? tc : tc.withOpacity(0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Image.asset(typeIconAsset(t), width: 11, height: 11,
                    errorBuilder: (_, __, ___) => const SizedBox()),
                const SizedBox(width: 4),
                Text(ptType(t), style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: sel ? typeTextColor(tc) : tc)),
              ]),
            ),
          );
        }).toList()),
        const SizedBox(height: 14),
        Text('CATEGORIA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Row(children: [
          for (final cat in ['physical', 'special', 'status']) ...[
            _CatBtn(cat: cat, sel: _cat == cat,
                onTap: () => setState(() => _cat = _cat == cat ? null : cat)),
            const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity,
          child: OutlinedButton(
            onPressed: () { Navigator.pop(context); widget.onApply(_type, _cat); },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              side: BorderSide(color: scheme.primary, width: 2)),
            child: const Text('Aplicar'),
          )),
      ]),
    );
  }
}

class _CatBtn extends StatelessWidget {
  final String cat; final bool sel; final VoidCallback onTap;
  const _CatBtn({required this.cat, required this.sel, required this.onTap});
  static const _c = {'physical': Color(0xFFE24B4A), 'special': Color(0xFF9C27B0), 'status': Color(0xFF888888)};
  static const _l = {'physical': 'Físico', 'special': 'Especial', 'status': 'Status'};
  @override Widget build(BuildContext context) {
    final color = _c[cat]!;
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: sel ? color.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: sel ? color
            : Theme.of(context).colorScheme.outlineVariant, width: sel ? 2 : 1)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/categories/$cat.png', width: 35, height: 15, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox()),
        const SizedBox(width: 5),
        Text(_l[cat]!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: sel ? color : Theme.of(context).colorScheme.onSurface)),
      ]),
    ));
  }
}
