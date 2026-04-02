import 'dart:convert';
import 'package:dexcurator/screens/detail/detail_shared.dart'
    show PokeballLoader;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dexcurator/screens/settings_screen.dart';
import 'package:dexcurator/translations.dart';
import 'package:dexcurator/screens/menu/ability_detail_screen.dart';

class AbilitiesListScreen extends StatefulWidget {
  const AbilitiesListScreen({super.key});
  @override State<AbilitiesListScreen> createState() => _AbilitiesListScreenState();
}

class _AbilitiesListScreenState extends State<AbilitiesListScreen> {
  List<_AbilityEntry> _all      = [];
  List<_AbilityEntry> _filtered = [];
  bool                _loading  = true;
  bool                _searching = false;
  String              _search   = '';
  int?                _genFilter;
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/data/ability_map.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;

    final entries = map.entries.map((e) {
      final v      = e.value as Map<String, dynamic>;
      final main   = (v['main']   as List<dynamic>).cast<int>();
      final hidden = (v['hidden'] as List<dynamic>).cast<int>();
      final desc   = (v['effect_short'] as String?)?.isNotEmpty == true
          ? v['effect_short'] as String
          : v['desc'] as String? ?? '';
      return _AbilityEntry(
        nameEn:      e.key,
        description: desc,
        mainIds:     main,
        hiddenIds:   hidden,
        gen:         (v['gen'] as int?) ?? 1,
        effectLong:  v['effect_long'] as String? ?? '',
        flavor:      v['flavor']      as String? ?? '',
      );
    }).toList()
      ..sort((a, b) => translateAbility(a.nameEn).compareTo(translateAbility(b.nameEn)));

    if (mounted) setState(() { _all = entries; _applyFilters(); _loading = false; });
  }

  void _applyFilters() {
    var list = _all;
    if (_genFilter != null) {
      list = list.where((a) => a.gen == _genFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((a) {
        final pt = translateAbility(a.nameEn).toLowerCase();
        return a.nameEn.toLowerCase().contains(q) || pt.contains(q) ||
               a.description.toLowerCase().contains(q);
      }).toList();
    }
    _filtered = list;
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _search = '';
        _searchCtrl.clear();
        _applyFilters();
      }
    });
  }

  void _showGenFilter() async {
    final result = await showMenu<int?>(
      context: context,
      position: _genButtonPosition(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        _genItem(context, null, 'Todas as gerações'),
        for (int g = 1; g <= 9; g++)
          _genItem(context, g, 'Geração $g'),
      ],
    );
    if (result != 'cancelled' && mounted) {
      setState(() { _genFilter = result as int?; _applyFilters(); });
    }
  }

  PopupMenuItem<int?> _genItem(BuildContext ctx, int? value, String label) {
    final selected = _genFilter == value;
    return PopupMenuItem<int?>(
      value: value,
      child: Row(children: [
        Expanded(child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal))),
        if (selected) Icon(Icons.check, size: 16,
            color: Theme.of(ctx).colorScheme.primary),
      ]),
    );
  }

  // Posição do botão de geração para o menu aparecer abaixo dele
  RelativeRect _genButtonPosition() {
    final RenderBox? box = _genKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return const RelativeRect.fromLTRB(0, 56, 0, 0);
    final pos = box.localToGlobal(Offset.zero);
    return RelativeRect.fromLTRB(
      pos.dx, pos.dy + box.size.height, pos.dx + box.size.width, 0);
  }

  final GlobalKey _genKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final genLabel = _genFilter == null ? 'Todas as gerações' : 'Geração $_genFilter';

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() { _search = v; _applyFilters(); }),
                decoration: const InputDecoration(
                  hintText: 'Buscar habilidade...',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 16),
              )
            : const Text('Habilidades'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),

      body: Column(children: [
        // Dropdown de geração
        GestureDetector(
          key: _genKey,
          onTap: _showGenFilter,
          child: Container(
            color: scheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(children: [
              Text(genLabel,
                  style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _genFilter != null
                          ? scheme.primary
                          : scheme.onSurfaceVariant)),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, size: 16,
                  color: _genFilter != null
                      ? scheme.primary
                      : scheme.onSurfaceVariant),
            ]),
          ),
        ),

        // Lista
        Expanded(
          child: _loading
              ? Center(child: PokeballLoader())
              : _filtered.isEmpty
                  ? Center(child: Text('Nenhuma habilidade encontrada',
                      style: TextStyle(color: scheme.onSurfaceVariant)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1,
                          color: scheme.outlineVariant.withOpacity(0.5)),
                      itemBuilder: (ctx, i) => _AbilityTile(
                        entry: _filtered[i],
                        onTap: () => Navigator.push(ctx, MaterialPageRoute(
                          builder: (_) => AbilityDetailScreen(entry: _filtered[i]),
                        )),
                      ),
                    ),
        ),
      ]),
    );
  }
}

// ─── Tile da lista ────────────────────────────────────────────────
class _AbilityTile extends StatelessWidget {
  final _AbilityEntry entry;
  final VoidCallback  onTap;
  const _AbilityTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final namePt = translateAbility(entry.nameEn);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(namePt,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            if (entry.description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(entry.description,
                  style: TextStyle(fontSize: 12,
                      color: scheme.onSurfaceVariant, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ])),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 16,
              color: scheme.onSurfaceVariant.withOpacity(0.4)),
        ]),
      ),
    );
  }
}

// ─── Modelo público ───────────────────────────────────────────────
class AbilityEntry {
  final String    nameEn;
  final String    description;
  final List<int> mainIds;
  final List<int> hiddenIds;
  final int       gen;
  final String    effectLong;
  final String    flavor;

  const AbilityEntry({
    required this.nameEn,
    required this.description,
    required this.mainIds,
    required this.hiddenIds,
    required this.gen,
    this.effectLong = '',
    this.flavor     = '',
  });
}

typedef _AbilityEntry = AbilityEntry;
