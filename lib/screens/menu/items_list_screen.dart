import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/screens/menu/item_detail_screen.dart';

// ─── Modelo ───────────────────────────────────────────────────────
class ItemEntry {
  final String nameEn;
  final String namePt;
  final String category;
  final String categoryPt;
  final String pocket;
  final int    cost;
  final String effect;
  final String flavor;
  final String sprite;
  final List<String> versions;

  const ItemEntry({
    required this.nameEn,
    required this.namePt,
    required this.category,
    required this.categoryPt,
    required this.pocket,
    required this.cost,
    required this.effect,
    required this.flavor,
    required this.sprite,
    required this.versions,
  });

  String get displayName => namePt.isNotEmpty
      ? namePt
      : nameEn.split('-').map((w) =>
          w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w).join(' ');
}

// Mapeamento versão PokeAPI → gameId do app
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
  'ultra-sun': 'ultra_sun___ultra_moon',
  'ultra-moon': 'ultra_sun___ultra_moon',
  'lets-go-pikachu': 'lets_go_pikachu___eevee',
  'lets-go-eevee': 'lets_go_pikachu___eevee',
  'sword': 'sword___shield', 'shield': 'sword___shield',
  'brilliant-diamond': 'brilliant_diamond___shining_pearl',
  'shining-pearl': 'brilliant_diamond___shining_pearl',
  'legends-arceus': 'legends_arceus',
  'scarlet': 'scarlet___violet', 'violet': 'scarlet___violet',
};

// ─── Ícones de bolsa ──────────────────────────────────────────────
const _pocketIcon = {
  'Pokébolas':   Icons.catching_pokemon,
  'Pokébolas Especiais': Icons.catching_pokemon,
  'Pokébolas Apricorn': Icons.catching_pokemon,
  'Medicina':    Icons.medical_services_outlined,
  'Batalha':     Icons.bolt_outlined,
  'Frutas':      Icons.eco_outlined,
  'Itens':       Icons.inventory_2_outlined,
  'MTs/MOs':     Icons.disc_full_outlined,
  'Itens Chave': Icons.vpn_key_outlined,
  'Ingredientes':Icons.restaurant_outlined,
  'Treinamento': Icons.fitness_center_outlined,
};

// ─── Cache global do item_map ─────────────────────────────────────
Map<String, dynamic>? _itemMapCache;

// ─── Tela ─────────────────────────────────────────────────────────
class ItemsListScreen extends StatefulWidget {
  const ItemsListScreen({super.key});
  @override State<ItemsListScreen> createState() => _ItemsListScreenState();
}

class _ItemsListScreenState extends State<ItemsListScreen> {
  // Todos os itens agrupados por categoria
  Map<String, List<ItemEntry>> _grouped    = {};
  bool                         _loading    = true;
  bool                         _searching  = false;
  String                       _search     = '';
  String?                      _activeGameId;
  bool                         _filterByGame = true;
  final _searchCtrl = TextEditingController();

  // Categorias ordenadas para exibição
  static const _categoryOrder = [
    'Pokébolas', 'Pokébolas Especiais', 'Pokébolas Apricorn',
    'Medicina', 'Batalha', 'Frutas',
    'Itens Seguráveis', 'Itens Choice', 'Melhoria de Tipo',
    'Evolução', 'Pedras Evolutivas', 'Mega Pedras', 'Cristais Z',
    'MTs/MOs', 'Vitaminas', 'Treinamento', 'Incensos',
    'Itens Específicos', 'Memórias', 'Pratos',
    'Colecionáveis', 'Itens Valiosos', 'Achados', 'Joias',
    'Natureza', 'Batalha', 'Fragmentos Tera', 'Orbs Tera',
    'Ingredientes', 'Itens Chave', 'Outros',
  ];

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);

    // Obter jogo ativo
    final lastDex = await StorageService().getLastPokedexId();
    _activeGameId = (lastDex == null ||
        lastDex.startsWith('pokopia') ||
        lastDex == 'pokémon_go' ||
        lastDex == 'nacional')
        ? null : lastDex;

    // Carregar item_map.json
    if (_itemMapCache == null) {
      try {
        final raw = await rootBundle.loadString('assets/data/item_map.json');
        _itemMapCache = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        _itemMapCache = {};
      }
    }

    _buildGrouped();
    if (mounted) setState(() => _loading = false);
  }

  void _buildGrouped() {
    final map  = _itemMapCache ?? {};
    final game = _filterByGame ? _activeGameId : null;

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
        versions:   (v['versions'] as List<dynamic>?)?.cast<String>() ?? [],
      );
    }).where((item) {
      // Filtrar por jogo se necessário
      if (game != null && item.versions.isNotEmpty) {
        return item.versions.any((v) => _versionToGameId[v] == game);
      }
      return true;
    }).toList();

    // Aplicar busca
    final filtered = _search.isEmpty ? entries : entries.where((item) {
      final q = _search.toLowerCase();
      return item.displayName.toLowerCase().contains(q) ||
             item.nameEn.toLowerCase().contains(q) ||
             item.categoryPt.toLowerCase().contains(q);
    }).toList();

    // Agrupar por categoria PT
    final grouped = <String, List<ItemEntry>>{};
    for (final item in filtered) {
      (grouped[item.categoryPt] ??= []).add(item);
    }
    // Ordenar itens dentro de cada categoria
    for (final list in grouped.values) {
      list.sort((a, b) => a.displayName.compareTo(b.displayName));
    }

    _grouped = grouped;
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _search = '';
        _searchCtrl.clear();
        _buildGrouped();
      }
    });
  }

  // Ordena categorias conforme _categoryOrder, o resto no final
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
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
          // Toggle filtro por jogo
          if (_activeGameId != null)
            IconButton(
              tooltip: _filterByGame ? 'Mostrando itens do jogo' : 'Mostrando todos os itens',
              icon: Icon(
                _filterByGame ? Icons.filter_alt : Icons.filter_alt_off,
                color: _filterByGame ? scheme.primary : null,
              ),
              onPressed: () => setState(() {
                _filterByGame = !_filterByGame;
                _buildGrouped();
              }),
            ),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _grouped.isEmpty
              ? _EmptyState(
                  hasFilter: _filterByGame && _activeGameId != null,
                  onClear: () => setState(() { _filterByGame = false; _buildGrouped(); }),
                )
              : CustomScrollView(slivers: [
                  // Contador + info de jogo
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(children: [
                      Text(
                        '${_grouped.values.fold(0, (s, l) => s + l.length)} itens'
                        '${_filterByGame && _activeGameId != null ? ' do jogo ativo' : ''}',
                        style: TextStyle(fontSize: 11,
                            color: scheme.onSurfaceVariant)),
                    ]),
                  )),

                  // Categorias expandíveis
                  for (final cat in _sortedCategories)
                    _CategorySliver(
                      category: cat,
                      items: _grouped[cat]!,
                      pocket: _grouped[cat]!.first.pocket,
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ]),
    );
  }
}

// ─── Sliver de categoria ──────────────────────────────────────────
class _CategorySliver extends StatefulWidget {
  final String category; final List<ItemEntry> items; final String pocket;
  const _CategorySliver({required this.category, required this.items, required this.pocket});
  @override State<_CategorySliver> createState() => _CategorySliverState();
}

class _CategorySliverState extends State<_CategorySliver> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon   = _pocketIcon[widget.pocket] ?? Icons.inventory_2_outlined;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header da categoria
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(children: [
                Icon(icon, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.category,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700))),
                Text('${widget.items.length}',
                    style: TextStyle(fontSize: 11,
                        color: scheme.onSurfaceVariant)),
                const SizedBox(width: 4),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16, color: scheme.onSurfaceVariant),
              ]),
            ),
          ),

          // Lista de itens da categoria
          if (_expanded) ...[
            ...widget.items.map((item) => _ItemTile(item: item)),
            const SizedBox(height: 4),
          ],

          Divider(height: 1, color: scheme.outlineVariant.withOpacity(0.4)),
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
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ItemDetailScreen(item: item))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: scheme.outlineVariant, width: 0.5)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Sprite do item
          _ItemSprite(url: item.sprite, size: 40),
          const SizedBox(width: 10),
          // Info
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.displayName,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            if (item.effect.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(item.effect,
                  style: TextStyle(fontSize: 11,
                      color: scheme.onSurfaceVariant, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ])),
          // Custo
          if (item.cost > 0)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₽${_formatCost(item.cost)}',
                  style: TextStyle(fontSize: 10,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500)),
            ]),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 14,
              color: scheme.onSurfaceVariant.withOpacity(0.4)),
        ]),
      ),
    );
  }

  String _formatCost(int cost) {
    if (cost >= 1000) return '${(cost / 1000).toStringAsFixed(cost % 1000 == 0 ? 0 : 1)}k';
    return cost.toString();
  }
}

// ─── Sprite do item ───────────────────────────────────────────────
class ItemSprite extends StatelessWidget {
  final String url; final double size;
  const ItemSprite({super.key, required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return SizedBox(width: size, height: size,
          child: Icon(Icons.inventory_2_outlined, size: size * 0.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant
                  .withOpacity(0.4)));
    }
    return Image.network(url, width: size, height: size, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => SizedBox(width: size, height: size,
            child: Icon(Icons.inventory_2_outlined, size: size * 0.6,
                color: Theme.of(context).colorScheme.onSurfaceVariant
                    .withOpacity(0.4))));
  }
}

// Alias privado para uso interno
typedef _ItemSprite = ItemSprite;

// ─── Estado vazio ─────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasFilter; final VoidCallback onClear;
  const _EmptyState({required this.hasFilter, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inventory_2_outlined, size: 48,
          color: scheme.onSurfaceVariant.withOpacity(0.4)),
      const SizedBox(height: 12),
      Text(hasFilter
          ? 'Nenhum item encontrado para o jogo ativo.\nGere o item_map.json primeiro.'
          : 'item_map.json não encontrado.\nRode o script generate_item_map.py.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
      if (hasFilter) ...[
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onClear,
            child: const Text('Ver todos os itens')),
      ],
    ]));
  }
}
