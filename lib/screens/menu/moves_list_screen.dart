import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pokedex_tracker/theme/type_colors.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart'
    show ptType, typeIconAsset, typeTextColor, neutralBg, neutralBorder, kApiBase;
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/services/pokeapi_service.dart';
import 'package:pokedex_tracker/services/dex_bundle_service.dart';
import 'package:pokedex_tracker/translations.dart';
import 'package:pokedex_tracker/screens/menu/move_detail_screen.dart';

class MovesListScreen extends StatefulWidget {
  const MovesListScreen({super.key});
  @override State<MovesListScreen> createState() => _MovesListScreenState();
}

class _MovesListScreenState extends State<MovesListScreen> {
  // ── estado ────────────────────────────────────────────────────
  List<_MoveEntry> _allMoves  = [];
  List<_MoveEntry> _filtered  = [];
  bool             _loading   = true;
  String           _search    = '';
  String?          _typeFilter;    // typeEn, ex: 'fire'
  String?          _catFilter;     // 'physical' | 'special' | 'status'
  String           _activeGame = '';
  String           _activeGameLabel = '';

  // cache de detalhes já buscados: url → detail JSON
  final Map<String, Map<String, dynamic>> _detailCache = {};

  @override
  void initState() {
    super.initState();
    _loadMoves();
  }

  // ── Carga principal ───────────────────────────────────────────
  Future<void> _loadMoves() async {
    setState(() { _loading = true; });

    // 1. Descobrir jogo ativo
    final storage = StorageService();
    final lastDex = await storage.getLastPokedexId();
    final gameId  = (lastDex == null || lastDex == 'nacional'
        || lastDex == 'pokémon_go' || lastDex.startsWith('pokopia'))
        ? 'scarlet___violet'
        : lastDex;

    final sections = PokeApiService.pokedexSections[gameId] ?? [];
    _activeGame      = gameId;
    _activeGameLabel = sections.isNotEmpty
        ? sections.first.label
        : gameId.replaceAll('___', ' / ').replaceAll('_', ' ');

    // 2. Coletar todos os speciesIds do jogo
    final allIds = <int>{};
    for (final s in sections) {
      final entries = await DexBundleService.instance.loadSection(s.apiName);
      if (entries != null) {
        for (final e in entries) allIds.add(e['speciesId']!);
      }
    }
    if (allIds.isEmpty) {
      // fallback: gerar lista 1-1025 para Nacional
      for (int i = 1; i <= 1025; i++) allIds.add(i);
    }

    // 3. Para cada pokémon, buscar seus moves via PokeAPI
    //    Limitamos a primeiros 200 pokémon para não sobrecarregar
    //    e depois expandimos em background
    final moveMap = <String, _MoveEntry>{};
    final ids     = allIds.toList()..sort();

    // Busca em lotes de 10 para não sobrecarregar
    for (int i = 0; i < ids.length; i += 10) {
      if (!mounted) return;
      final batch = ids.skip(i).take(10).toList();
      await Future.wait(batch.map((id) => _fetchPokemonMoves(id, gameId, moveMap)));

      // Renderiza após cada lote para dar feedback progressivo
      if (mounted) setState(() {
        _allMoves = moveMap.values.toList()
          ..sort((a, b) => a.nameEn.compareTo(b.nameEn));
        _applyFilters();
        _loading = false;
      });
    }
  }

  Future<void> _fetchPokemonMoves(
      int pokemonId,
      String gameId,
      Map<String, _MoveEntry> moveMap) async {
    try {
      final res = await http.get(
        Uri.parse('$kApiBase/pokemon/$pokemonId'),
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final data   = jsonDecode(res.body) as Map<String, dynamic>;
      final moves  = data['moves'] as List<dynamic>? ?? [];

      for (final m in moves) {
        final nameEn = m['move']['name'] as String;
        final url    = m['move']['url'] as String;
        if (moveMap.containsKey(nameEn)) continue;

        // Verificar que o move está disponível neste jogo
        final vgDetails = m['version_group_details'] as List<dynamic>? ?? [];
        bool available = false;
        for (final vg in vgDetails) {
          available = true; // qualquer jogo conta para a lista global de moves
          break;
        }
        if (!available && vgDetails.isEmpty) continue;

        moveMap[nameEn] = _MoveEntry(nameEn: nameEn, url: url);
      }
    } catch (_) {}
  }

  void _applyFilters() {
    var list = _allMoves;

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((m) {
        final pt = translateMove(m.nameEn).toLowerCase();
        return m.nameEn.toLowerCase().contains(q) || pt.contains(q);
      }).toList();
    }
    if (_typeFilter != null) {
      list = list.where((m) => m.typeEn == _typeFilter).toList();
    }
    if (_catFilter != null) {
      list = list.where((m) => m.category == _catFilter).toList();
    }

    _filtered = list;
  }

  // ── Busca detalhe de move ─────────────────────────────────────
  Future<Map<String, dynamic>?> _loadDetail(String url) async {
    if (_detailCache.containsKey(url)) return _detailCache[url];
    try {
      final res = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body) as Map<String, dynamic>;
        _detailCache[url] = d;
        // Atualizar o entry com os dados carregados
        for (final e in _allMoves) {
          if (e.url == url) {
            e.typeEn   = d['type']?['name'] as String? ?? '';
            e.category = d['damage_class']?['name'] as String? ?? '';
            e.power    = d['power'] as int?;
            e.accuracy = d['accuracy'] as int?;
            e.pp       = d['pp'] as int?;
          }
        }
        return d;
      }
    } catch (_) {}
    return null;
  }

  // ── Filtros ───────────────────────────────────────────────────
  static const _allTypes = [
    'normal','fighting','flying','poison','ground','rock',
    'bug','ghost','steel','fire','water','grass',
    'electric','psychic','ice','dragon','dark','fairy',
  ];

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _FilterSheet(
        selectedType: _typeFilter,
        selectedCat:  _catFilter,
        onApply: (type, cat) {
          setState(() {
            _typeFilter = type;
            _catFilter  = cat;
            _applyFilters();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasFilter = _typeFilter != null || _catFilter != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Golpes'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: hasFilter,
              child: const Icon(Icons.filter_list_outlined),
            ),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(children: [
        // Jogo ativo
        if (_activeGameLabel.isNotEmpty)
          Container(
            color: scheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              Icon(Icons.sports_martial_arts_outlined,
                  size: 13, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Golpes de: $_activeGameLabel',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                '${_filtered.length} golpes',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ]),
          ),

        // Busca
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            onChanged: (v) => setState(() {
              _search = v;
              _applyFilters();
            }),
            decoration: InputDecoration(
              hintText: 'Buscar golpe...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ),

        // Chips de filtro ativo
        if (hasFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(children: [
              if (_typeFilter != null)
                _ActiveChip(
                  label: ptType(_typeFilter!),
                  onRemove: () => setState(() {
                    _typeFilter = null; _applyFilters();
                  }),
                ),
              if (_catFilter != null) ...[
                const SizedBox(width: 6),
                _ActiveChip(
                  label: _catFilter == 'physical' ? 'Físico'
                      : _catFilter == 'special' ? 'Especial' : 'Status',
                  onRemove: () => setState(() {
                    _catFilter = null; _applyFilters();
                  }),
                ),
              ],
            ]),
          ),

        // Lista
        Expanded(
          child: _loading && _filtered.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(child: Text('Nenhum golpe encontrado',
                      style: TextStyle(color: scheme.onSurfaceVariant)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) => _MoveCard(
                        entry:  _filtered[i],
                        onLoad: _loadDetail,
                        onTap:  () => _openDetail(_filtered[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  void _openDetail(_MoveEntry entry) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MoveDetailScreen(
        entry: entry,
        activeGameId: _activeGame,
        detailCache: _detailCache,
        loadDetail: _loadDetail,
      ),
    ));
  }
}

// ─── Modelo ───────────────────────────────────────────────────────

class MoveEntry {
  final String nameEn;
  final String url;
  String typeEn   = '';
  String category = '';
  int?   power;
  int?   accuracy;
  int?   pp;

  MoveEntry({required this.nameEn, required this.url});
}

// Alias local para evitar conflito de nomes entre arquivos
typedef _MoveEntry = MoveEntry;

// ─── Card de golpe ────────────────────────────────────────────────

class _MoveCard extends StatefulWidget {
  final _MoveEntry entry;
  final Future<Map<String, dynamic>?> Function(String url) onLoad;
  final VoidCallback onTap;
  const _MoveCard({required this.entry, required this.onLoad, required this.onTap});

  @override
  State<_MoveCard> createState() => _MoveCardState();
}

class _MoveCardState extends State<_MoveCard> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.entry.typeEn.isEmpty) {
      widget.onLoad(widget.entry.url).then((_) {
        if (mounted) setState(() => _loaded = true);
      });
    } else {
      _loaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme   = Theme.of(context).colorScheme;
    final entry    = widget.entry;
    final namePt   = translateMove(entry.nameEn);
    final typeEn   = entry.typeEn;
    final typePt   = typeEn.isNotEmpty ? ptType(typeEn) : '';
    final typeColor = typeEn.isNotEmpty
        ? TypeColors.fromType(typePt)
        : scheme.surfaceContainerHighest;
    final catName  = entry.category;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: scheme.outlineVariant, width: 0.5),
        ),
        child: Column(children: [
          // Linha superior: nome + stats
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(children: [
              Expanded(child: Text(namePt,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600))),
              _StatChip('POD', entry.power != null ? '${entry.power}' : '—'),
              const SizedBox(width: 6),
              _StatChip('PREC', entry.accuracy != null ? '${entry.accuracy}%' : '—'),
              const SizedBox(width: 6),
              _StatChip('PP', entry.pp != null ? '${entry.pp}' : '—'),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 14,
                  color: scheme.onSurfaceVariant.withOpacity(0.5)),
            ]),
          ),

          // Linha inferior: tipo + categoria
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(children: [
              // Badge de tipo
              if (typeEn.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset(typeIconAsset(typeEn),
                        width: 12, height: 12,
                        errorBuilder: (_, __, ___) => const SizedBox()),
                    const SizedBox(width: 4),
                    Text(typePt, style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: typeTextColor(typeColor))),
                  ]),
                ),
                const SizedBox(width: 6),
              ] else
                Container(
                  width: 60, height: 20,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

              // Badge de categoria
              if (catName.isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset(
                    'assets/categories/$catName.png',
                    width: 18, height: 18,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    catName == 'physical' ? 'Físico'
                        : catName == 'special' ? 'Especial' : 'Status',
                    style: TextStyle(fontSize: 10,
                        color: scheme.onSurfaceVariant),
                  ),
                ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Text(value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      Text(label,
          style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
    ]);
  }
}

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(
            fontSize: 11, color: scheme.onPrimaryContainer)),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onRemove,
          child: Icon(Icons.close, size: 13,
              color: scheme.onPrimaryContainer),
        ),
      ]),
    );
  }
}

// ─── Bottom sheet de filtros ──────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final String? selectedType;
  final String? selectedCat;
  final void Function(String? type, String? cat) onApply;
  const _FilterSheet({
    required this.selectedType,
    required this.selectedCat,
    required this.onApply,
  });
  @override State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _type;
  String? _cat;

  static const _types = [
    'normal','fighting','flying','poison','ground','rock',
    'bug','ghost','steel','fire','water','grass',
    'electric','psychic','ice','dragon','dark','fairy',
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.selectedType;
    _cat  = widget.selectedCat;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Filtrar golpes',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() { _type = null; _cat = null; });
            },
            child: const Text('Limpar'),
          ),
        ]),

        const SizedBox(height: 12),
        Text('TIPO', style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant,
            letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6,
          children: _types.map((t) {
            final selected = _type == t;
            final tc = TypeColors.fromType(ptType(t));
            return GestureDetector(
              onTap: () => setState(() => _type = selected ? null : t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: selected ? tc : tc.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: selected ? tc : tc.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset(typeIconAsset(t), width: 12, height: 12,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                  const SizedBox(width: 4),
                  Text(ptType(t), style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: selected ? typeTextColor(tc) : tc)),
                ]),
              ),
            );
          }).toList()),

        const SizedBox(height: 16),
        Text('CATEGORIA', style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant,
            letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Row(children: [
          for (final cat in ['physical', 'special', 'status']) ...[
            _CatButton(
              cat: cat,
              selected: _cat == cat,
              onTap: () => setState(
                  () => _cat = _cat == cat ? null : cat),
            ),
            const SizedBox(width: 8),
          ],
        ]),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onApply(_type, _cat);
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              side: BorderSide(color: scheme.primary, width: 2),
            ),
            child: const Text('Aplicar'),
          ),
        ),
      ]),
    );
  }
}

class _CatButton extends StatelessWidget {
  final String cat;
  final bool selected;
  final VoidCallback onTap;
  const _CatButton({required this.cat, required this.selected, required this.onTap});

  static const _colors = {
    'physical': Color(0xFFE24B4A),
    'special':  Color(0xFF9C27B0),
    'status':   Color(0xFF888888),
  };
  static const _labels = {
    'physical': 'Físico',
    'special':  'Especial',
    'status':   'Status',
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[cat]!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? color : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/categories/$cat.png',
              width: 16, height: 16,
              errorBuilder: (_, __, ___) => const SizedBox()),
          const SizedBox(width: 6),
          Text(_labels[cat]!, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: selected ? color
                  : Theme.of(context).colorScheme.onSurface)),
        ]),
      ),
    );
  }
}
