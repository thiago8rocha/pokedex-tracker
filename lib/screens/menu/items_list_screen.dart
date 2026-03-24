import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/screens/menu/item_detail_screen.dart';

// ─── Modelo ───────────────────────────────────────────────────────
class ItemEntry {
  final String      nameEn;
  final String      namePt;
  final String      category;
  final String      categoryPt;
  final String      pocket;
  final int         cost;
  final String      effect;
  final String      flavor;
  final String      sprite;
  final List<String> versions;

  const ItemEntry({
    required this.nameEn, required this.namePt,
    required this.category, required this.categoryPt,
    required this.pocket, required this.cost,
    required this.effect, required this.flavor,
    required this.sprite, required this.versions,
  });

  String get displayName => namePt.isNotEmpty
      ? namePt
      : nameEn.split('-').map((w) =>
          w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w).join(' ');

  // Descrição para a lista: usa effect, ou flavor como fallback
  String get shortDesc => effect.isNotEmpty ? effect : flavor;

  // URL da sprite: usa campo sprite do JSON, ou constrói fallback via nameEn
  String get spriteUrl => sprite.isNotEmpty
      ? sprite
      : 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/$nameEn.png';
}

// ─── Mapeamento versão PokeAPI → gameId ───────────────────────────
const _versionToGameId = {
  'red': 'red___blue', 'blue': 'red___blue', 'yellow': 'yellow',
  'gold': 'gold___silver', 'silver': 'gold___silver', 'crystal': 'crystal',
  'ruby': 'ruby___sapphire', 'sapphire': 'ruby___sapphire',
  'firered': 'firered___leafgreen_(gba)', 'leafgreen': 'firered___leafgreen_(gba)',
  'emerald': 'emerald',
  'diamond': 'diamond___pearl', 'pearl': 'diamond___pearl',
  'platinum': 'platinum',
  'heartgold': 'heartgold___soulsilver', 'soulsilver': 'heartgold___soulsilver',
  'black': 'black___white', 'white': 'black___white',
  'black-2': 'black_2___white_2', 'white-2': 'black_2___white_2',
  'x': 'x___y', 'y': 'x___y',
  'omega-ruby': 'omega_ruby___alpha_sapphire',
  'alpha-sapphire': 'omega_ruby___alpha_sapphire',
  'sun': 'sun___moon', 'moon': 'sun___moon',
  'ultra-sun': 'ultra_sun___ultra_moon', 'ultra-moon': 'ultra_sun___ultra_moon',
  'lets-go-pikachu': 'lets_go_pikachu___eevee',
  'lets-go-eevee': 'lets_go_pikachu___eevee',
  'sword': 'sword___shield', 'shield': 'sword___shield',
  'brilliant-diamond': 'brilliant_diamond___shining_pearl',
  'shining-pearl': 'brilliant_diamond___shining_pearl',
  'legends-arceus': 'legends_arceus',
  'scarlet': 'scarlet___violet', 'violet': 'scarlet___violet',
};

// ─── Jogos com gradiente (igual outras telas) ─────────────────────
const _gamesByGen = <int, List<Map<String, dynamic>>>{
  1: [
    {'name': 'Red / Blue',  'id': 'red___blue',  'c1': 0xFFE53935, 'c2': 0xFF1565C0},
    {'name': 'Yellow',      'id': 'yellow',      'c1': 0xFFFDD835, 'c2': 0xFFFF8F00},
  ],
  2: [
    {'name': 'Gold / Silver',          'id': 'gold___silver',            'c1': 0xFFFFCA28, 'c2': 0xFFB0BEC5},
    {'name': 'Crystal',                'id': 'crystal',                  'c1': 0xFF29B6F6, 'c2': 0xFFE1F5FE},
  ],
  3: [
    {'name': 'Ruby / Sapphire',        'id': 'ruby___sapphire',          'c1': 0xFFE53935, 'c2': 0xFF1E88E5},
    {'name': 'FireRed / LeafGreen',    'id': 'firered___leafgreen_(gba)', 'c1': 0xFFEF5350, 'c2': 0xFF43A047},
    {'name': 'Emerald',                'id': 'emerald',                  'c1': 0xFF43A047, 'c2': 0xFF00BCD4},
  ],
  4: [
    {'name': 'Diamond / Pearl',        'id': 'diamond___pearl',          'c1': 0xFF90CAF9, 'c2': 0xFFF48FB1},
    {'name': 'Platinum',               'id': 'platinum',                 'c1': 0xFF78909C, 'c2': 0xFFCFD8DC},
    {'name': 'HeartGold / SoulSilver', 'id': 'heartgold___soulsilver',   'c1': 0xFFFFCA28, 'c2': 0xFFB0BEC5},
  ],
  5: [
    {'name': 'Black / White',          'id': 'black___white',            'c1': 0xFF424242, 'c2': 0xFFBDBDBD},
    {'name': 'Black 2 / White 2',      'id': 'black_2___white_2',        'c1': 0xFF1A237E, 'c2': 0xFFE0E0E0},
  ],
  6: [
    {'name': 'X / Y',                  'id': 'x___y',                    'c1': 0xFF1565C0, 'c2': 0xFFE53935},
    {'name': 'Omega Ruby / Alpha Sapphire', 'id': 'omega_ruby___alpha_sapphire', 'c1': 0xFFE53935, 'c2': 0xFF1E88E5},
  ],
  7: [
    {'name': 'Sun / Moon',             'id': 'sun___moon',               'c1': 0xFFFF8F00, 'c2': 0xFF7B1FA2},
    {'name': 'Ultra Sun / Ultra Moon', 'id': 'ultra_sun___ultra_moon',   'c1': 0xFFFF6F00, 'c2': 0xFF4A148C},
    {'name': "Let's Go Pikachu / Eevee", 'id': 'lets_go_pikachu___eevee', 'c1': 0xFFFDD835, 'c2': 0xFF8D6E63},
  ],
  8: [
    {'name': 'Sword / Shield',         'id': 'sword___shield',           'c1': 0xFF42A5F5, 'c2': 0xFFEF5350},
    {'name': 'Brilliant Diamond / Shining Pearl', 'id': 'brilliant_diamond___shining_pearl', 'c1': 0xFF42A5F5, 'c2': 0xFFEC407A},
    {'name': 'Legends: Arceus',        'id': 'legends_arceus',           'c1': 0xFFFFCA28, 'c2': 0xFFFFFDE7},
  ],
  9: [
    {'name': 'Scarlet / Violet',       'id': 'scarlet___violet',         'c1': 0xFFEF6C00, 'c2': 0xFF7B1FA2},
    {'name': 'Legends: Z-A',           'id': 'legends_z-a',              'c1': 0xFF546E7A, 'c2': 0xFFFFD54F},
  ],
};

Map<String, dynamic>? _findGame(String id) {
  for (final gen in _gamesByGen.values)
    for (final g in gen)
      if (g['id'] == id) return g;
  return null;
}

// ─── Ícones por bolsa ─────────────────────────────────────────────
const _pocketIcon = {
  'Pokébolas':   Icons.catching_pokemon,
  'Pokébolas Especiais': Icons.catching_pokemon,
  'Pokébolas Apricorn': Icons.catching_pokemon,
  'Medicina':    Icons.medical_services_outlined,
  'Batalha':     Icons.bolt_outlined,
  'Frutas':      Icons.eco_outlined,
  'Itens':       Icons.inventory_2_outlined,
  'Itens Seguráveis': Icons.shield_outlined,
  'MTs/MOs':     Icons.disc_full_outlined,
  'Itens Chave': Icons.vpn_key_outlined,
  'Ingredientes':Icons.restaurant_outlined,
  'Treinamento': Icons.fitness_center_outlined,
};

// ─── Ordem de categorias ──────────────────────────────────────────
const _categoryOrder = [
  'Pokébolas', 'Pokébolas Especiais', 'Pokébolas Apricorn',
  'Medicina', 'Recuperação de PP', 'Vitaminas', 'Reviver', 'Cura de Status',
  'Bônus de Batalha', 'Batalha',
  'Frutas', 'Frutas de Emergência', 'Frutas de Proteção',
  'Itens Seguráveis', 'Itens Choice', 'Melhoria de Tipo',
  'Evolução', 'Pedras Evolutivas', 'Incensos',
  'Mega Pedras', 'Cristais Z', 'Fragmentos Tera', 'Orbs Tera',
  'MTs/MOs', 'Treinamento',
  'Memórias', 'Pratos', 'Itens Específicos',
  'Joias', 'Colecionáveis', 'Itens Valiosos', 'Achados',
  'Ingredientes', 'Itens Chave', 'Outros',
];

// ─── Cache global ─────────────────────────────────────────────────
Map<String, dynamic>? _itemMapCache;

// ─── Tela ─────────────────────────────────────────────────────────
class ItemsListScreen extends StatefulWidget {
  const ItemsListScreen({super.key});
  @override State<ItemsListScreen> createState() => _ItemsListScreenState();
}

class _ItemsListScreenState extends State<ItemsListScreen> {
  Map<String, List<ItemEntry>> _grouped   = {};
  bool                         _loading   = true;
  bool                         _searching = false;
  String                       _search    = '';
  // Jogo ativo
  String               _activeGameId   = 'scarlet___violet';
  String               _activeGameName = 'Scarlet / Violet';
  int                  _activeC1       = 0xFFEF6C00;
  int                  _activeC2       = 0xFF7B1FA2;
  bool                 _filterByGame   = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _init(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _init() async {
    // Restaurar jogo ativo
    final lastDex = await StorageService().getLastPokedexId();
    if (lastDex != null &&
        !lastDex.startsWith('pokopia') &&
        lastDex != 'pokémon_go' &&
        lastDex != 'nacional') {
      final g = _findGame(lastDex);
      if (g != null) {
        _activeGameId   = lastDex;
        _activeGameName = g['name'] as String;
        _activeC1       = g['c1'] as int;
        _activeC2       = g['c2'] as int;
      }
    }

    // Carregar item_map.json — parsear em background para não travar a UI
    if (_itemMapCache == null) {
      try {
        final raw = await rootBundle.loadString('assets/data/item_map.json');
        // compute() roda o jsonDecode em um isolate separado
        _itemMapCache = await compute(
          (String s) => jsonDecode(s) as Map<String, dynamic>, raw);
      } catch (_) {
        _itemMapCache = {};
      }
    }

    _buildGrouped();
    if (mounted) setState(() => _loading = false);
  }

  void _buildGrouped() {
    final map  = _itemMapCache ?? {};
    final gameId = _filterByGame ? _activeGameId : null;

    // Categorias sem relevância para display (ruído do JSON)
    const skipCategories = {
      'Cristais Dynamax', 'Ingredientes de Sanduíche', 'Ingredientes de Curry',
      'Piquenique', 'Dados', 'Jogo',
    };

    final entries = map.entries.map((e) {
      final v = e.value as Map<String, dynamic>;
      return ItemEntry(
        nameEn:     e.key,
        namePt:     v['namePt']     as String? ?? '',
        category:   v['category']   as String? ?? 'other',
        categoryPt: v['categoryPt'] as String? ?? 'Outros',
        pocket:     v['pocket']     as String? ?? 'Itens',
        cost:       (v['cost'] as num?)?.toInt() ?? 0,
        effect:     v['effect']     as String? ?? '',
        flavor:     v['flavor']     as String? ?? '',
        sprite:     v['sprite']     as String? ?? '',
        versions:   (v['versions'] as List<dynamic>?)
            ?.cast<String>()
            .where((s) => s.isNotEmpty)
            .toList() ?? [],
      );
    }).where((item) {
      // Excluir categorias irrelevantes
      if (skipCategories.contains(item.categoryPt)) return false;
      // Filtrar por jogo quando versions estão disponíveis
      if (gameId != null && item.versions.isNotEmpty) {
        return item.versions.any((v) => _versionToGameId[v] == gameId);
      }
      return true;
    }).where((item) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return item.displayName.toLowerCase().contains(q) ||
             item.nameEn.toLowerCase().contains(q);
    }).toList();

    // Agrupar por categoria
    final grouped = <String, List<ItemEntry>>{};
    for (final item in entries) {
      (grouped[item.categoryPt] ??= []).add(item);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.displayName.compareTo(b.displayName));
    }
    _grouped = grouped;
  }

  void _changeGame(Map<String, dynamic> g) {
    setState(() {
      _activeGameId   = g['id'] as String;
      _activeGameName = g['name'] as String;
      _activeC1       = g['c1'] as int;
      _activeC2       = g['c2'] as int;
      _filterByGame   = true;
      _buildGrouped();
    });
  }

  void _showGamePicker() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _GamePickerSheet(
          selected: _activeGameId, gamesByGen: _gamesByGen),
    );
    if (result != null && mounted) _changeGame(result);
  }

  void _toggleSearch() => setState(() {
    _searching = !_searching;
    if (!_searching) { _search = ''; _searchCtrl.clear(); _buildGrouped(); }
  });

  List<String> get _sortedCategories {
    final cats = _grouped.keys.toList();
    cats.sort((a, b) {
      final ia = _categoryOrder.indexOf(a);
      final ib = _categoryOrder.indexOf(b);
      if (ia == -1 && ib == -1) return a.compareTo(b);
      if (ia == -1) return 1;
      if (ib == -1) return -1;
      return ia.compareTo(ib);
    });
    return cats;
  }

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final opacity = isDark ? 0.45 : 0.28;
    final c1 = Color(_activeC1);
    final c2 = Color(_activeC2);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl, autofocus: true,
                onChanged: (v) => setState(() { _search = v; _buildGrouped(); }),
                decoration: const InputDecoration(
                    hintText: 'Buscar item...', border: InputBorder.none),
                style: const TextStyle(fontSize: 16),
              )
            : const Text('Itens'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [

              // Banner do jogo ativo — igual ao de Golpes
              GestureDetector(
                onTap: _showGamePicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [c1.withOpacity(opacity),
                               c2.withOpacity(opacity)])),
                  child: Row(children: [
                    Expanded(child: Text(_activeGameName,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600))),
                    // Toggle "jogo ativo / todos"
                    GestureDetector(
                      onTap: () => setState(() {
                        _filterByGame = !_filterByGame;
                        _buildGrouped();
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _filterByGame
                              ? scheme.primary.withOpacity(0.15)
                              : scheme.surfaceContainerHighest
                                  .withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: _filterByGame
                                  ? scheme.primary.withOpacity(0.5)
                                  : scheme.outlineVariant,
                              width: 0.5)),
                        child: Text(
                          _filterByGame
                              ? 'Jogo ativo'
                              : 'Todos os jogos',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _filterByGame
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.expand_more, size: 18,
                        color: scheme.onSurfaceVariant),
                  ]),
                ),
              ),

              // Lista
              Expanded(
                child: _grouped.isEmpty
                    ? _EmptyState(
                        filterActive: _filterByGame,
                        onShowAll: () => setState(() {
                          _filterByGame = false; _buildGrouped();
                        }),
                      )
                    : CustomScrollView(slivers: [
                        for (final cat in _sortedCategories)
                          _CategorySliver(
                            category: cat,
                            items: _grouped[cat]!,
                            pocket: _grouped[cat]!.first.pocket,
                          ),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 24)),
                      ]),
              ),
            ]),
    );
  }
}

// ─── Picker de jogo ───────────────────────────────────────────────
class _GamePickerSheet extends StatelessWidget {
  final String selected;
  final Map<int, List<Map<String, dynamic>>> gamesByGen;
  const _GamePickerSheet(
      {required this.selected, required this.gamesByGen});

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final opacity = isDark ? 0.45 : 0.28;

    Widget card(Map<String, dynamic> g) {
      final sel = g['id'] == selected;
      final c1  = Color(g['c1'] as int).withOpacity(opacity);
      final c2  = Color(g['c2'] as int).withOpacity(opacity);
      return GestureDetector(
        onTap: () => Navigator.pop(context, g),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c1, c2]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: sel ? scheme.primary : scheme.outlineVariant,
                width: sel ? 2 : 1)),
          child: Row(children: [
            Expanded(child: Text(g['name'] as String,
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? scheme.primary : scheme.onSurface))),
            if (sel)
              Icon(Icons.check_circle, size: 16, color: scheme.primary),
          ]),
        ),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Selecionar Jogo',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(child: ListView(controller: ctrl,
            padding: const EdgeInsets.all(12),
            children: gamesByGen.entries.map((e) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
                    child: Text('Geração ${e.key}', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.5))),
                ...e.value.map(card),
              ],
            )).toList())),
      ]),
    );
  }
}

// ─── Categoria expansível ─────────────────────────────────────────
class _CategorySliver extends StatefulWidget {
  final String category; final List<ItemEntry> items; final String pocket;
  const _CategorySliver({required this.category, required this.items,
      required this.pocket});
  @override State<_CategorySliver> createState() => _CategorySliverState();
}

class _CategorySliverState extends State<_CategorySliver> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon   = _pocketIcon[widget.pocket] ??
        _pocketIcon[widget.category] ??
        Icons.inventory_2_outlined;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 4),
              child: Row(children: [
                Icon(icon, size: 15, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.category,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700))),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16, color: scheme.onSurfaceVariant),
              ]),
            ),
          ),
          if (_expanded) ...[
            ...widget.items.map((item) => _ItemTile(item: item)),
            const SizedBox(height: 4),
          ],
          Divider(height: 1,
              color: scheme.outlineVariant.withOpacity(0.4)),
        ]),
      ),
    );
  }
}

// ─── Tile de item ─────────────────────────────────────────────────
class _ItemTile extends StatelessWidget {
  final ItemEntry item;
  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: scheme.outlineVariant, width: 0.5)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Sprite
          ItemSprite(url: item.spriteUrl, size: 38),
          const SizedBox(width: 10),
          // Nome + descrição
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.displayName,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            if (item.shortDesc.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(item.shortDesc,
                  style: TextStyle(fontSize: 11,
                      color: scheme.onSurfaceVariant, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ])),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 14,
              color: scheme.onSurfaceVariant.withOpacity(0.4)),
        ]),
      ),
    );
  }
}

// ─── Sprite com fallback ──────────────────────────────────────────
class ItemSprite extends StatelessWidget {
  final String url; final double size;
  const ItemSprite({super.key, required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = SizedBox(width: size, height: size,
        child: Icon(Icons.inventory_2_outlined, size: size * 0.55,
            color: scheme.onSurfaceVariant.withOpacity(0.35)));

    if (url.isEmpty) return placeholder;
    return Image.network(url, width: size, height: size,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder,
        errorBuilder: (_, __, ___) => placeholder);
  }
}

// ─── Estado vazio ─────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool filterActive; final VoidCallback onShowAll;
  const _EmptyState({required this.filterActive, required this.onShowAll});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inventory_2_outlined, size: 48,
          color: scheme.onSurfaceVariant.withOpacity(0.4)),
      const SizedBox(height: 12),
      Text(
        filterActive
            ? 'Nenhum item encontrado para este jogo.\nGere o item_map.json primeiro.'
            : 'item_map.json não encontrado.\nRode o script generate_item_map.py.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
      if (filterActive) ...[
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onShowAll,
          child: const Text('Ver todos os jogos'),
        ),
      ],
    ]));
  }
}
