import 'package:flutter/material.dart';
import 'package:dexcurator/services/storage_service.dart';
import 'package:dexcurator/services/pokeapi_service.dart';
import 'package:dexcurator/screens/pokedex_screen.dart';
import 'package:dexcurator/screens/settings_screen.dart';
import 'package:dexcurator/screens/pokopia/pokopia_hub_screen.dart';
import 'package:dexcurator/screens/go/go_hub_screen.dart';
import 'package:dexcurator/screens/pocket/pocket_hub_screen.dart';
import 'package:dexcurator/screens/menu/moves_list_screen.dart';
import 'package:dexcurator/screens/menu/abilities_list_screen.dart';
import 'package:dexcurator/screens/menu/natures_list_screen.dart';
import 'package:dexcurator/screens/menu/teams_screen.dart';
import 'package:dexcurator/screens/menu/items_list_screen.dart';
import 'package:dexcurator/screens/detail/detail_shared.dart'
    show typeNamePt, typeIconColors;

// ─── MODELOS ─────────────────────────────────────────────────────

class _DlcInfo {
  final String name;
  final int total;
  final String sectionApiName;
  const _DlcInfo({required this.name, required this.total, required this.sectionApiName});
}

class _PokedexEntry {
  final String name;
  final String year;
  final int totalBase;
  final List<_DlcInfo> dlcs;
  final bool isPokopiaDex;
  final int? pokopiaHabitatTotal;
  final int cardColor1;
  final int cardColor2;
  final int generation;

  const _PokedexEntry({
    required this.name,
    required this.year,
    required this.totalBase,
    this.dlcs = const [],
    this.isPokopiaDex = false,
    this.pokopiaHabitatTotal,
    this.cardColor1 = 0xFFE8E8F0,
    this.cardColor2 = 0xFFE8E8F0,
    this.generation = 0,
  });

  String get pokedexId =>
      name.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_').replaceAll("'", '');
}

// ─── GERAÇÃO POR JOGO ────────────────────────────────────────────

const Map<String, List<int>> _gameGenerations = {
  'Red / Blue': [1], 'Yellow': [1],
  'Gold / Silver': [1, 2], 'Crystal': [1, 2],
  'Ruby / Sapphire': [1, 2, 3], 'FireRed / LeafGreen (GBA)': [1], 'Emerald': [1, 2, 3],
  'Diamond / Pearl': [1, 2, 3, 4], 'Platinum': [1, 2, 3, 4],
  'HeartGold / SoulSilver': [1, 2, 3, 4],
  'Black / White': [1, 2, 3, 4, 5], 'Black 2 / White 2': [1, 2, 3, 4, 5],
  'X / Y': [1, 2, 3, 4, 5, 6], 'Omega Ruby / Alpha Sapphire': [1, 2, 3, 4, 5, 6],
  'Sun / Moon': [1, 2, 3, 4, 5, 6, 7], 'Ultra Sun / Ultra Moon': [1, 2, 3, 4, 5, 6, 7],
  "Let's Go Pikachu / Eevee": [1],
  'Sword / Shield': [1, 2, 3, 4, 5, 6, 7, 8],
  'Brilliant Diamond / Shining Pearl': [1, 2, 3, 4],
  'Legends: Arceus': [1, 2, 3, 4, 8],
  'Scarlet / Violet': [1, 2, 3, 4, 5, 6, 7, 8, 9],
  'Legends: Z-A': [1, 2, 3, 4, 5, 6, 7, 8, 9],
  'FireRed / LeafGreen': [1],
  'Nacional': [1, 2, 3, 4, 5, 6, 7, 8, 9],
  'Pokémon GO': [1, 2, 3, 4, 5, 6, 7, 8, 9],
};

// ─── NAVEGAÇÃO ────────────────────────────────────────────────────

enum _NavTab { home, pocket, go, pokopia }

// ─── HOME SCREEN ──────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();

  final Map<String, int> _caughtCounts = {};
  final Map<String, int> _dlcCounts = {};
  Set<String>? _activePokedexIds;
  _NavTab _currentTab = _NavTab.home;

  // Filtros
  _PokedexEntry? _selectedGame;
  Set<int> _selectedGens = {};
  Set<String> _selectedTypes = {};

  // ── Catálogo ─────────────────────────────────────────────────

  static const _PokedexEntry _nacEntry = _PokedexEntry(
    name: 'Nacional', year: '', totalBase: 1025, generation: 0,
    cardColor1: 0xFFE8524A, cardColor2: 0xFFB71C1C);

  static const _PokedexEntry _goEntry = _PokedexEntry(
    name: 'Pokémon GO', year: '2016', totalBase: 941, generation: 0,
    cardColor1: 0xFF4285F4, cardColor2: 0xFF0D47A1);

  static const List<_PokedexEntry> _gameEntries = [
    _PokedexEntry(name: 'Red / Blue',       year: '1996', totalBase: 151, generation: 1, cardColor1: 0xFFE53935, cardColor2: 0xFF1565C0),
    _PokedexEntry(name: 'Yellow',            year: '1998', totalBase: 151, generation: 1, cardColor1: 0xFFFDD835, cardColor2: 0xFFFF8F00),
    _PokedexEntry(name: 'Gold / Silver',     year: '1999', totalBase: 251, generation: 2, cardColor1: 0xFFFFCA28, cardColor2: 0xFFB0BEC5),
    _PokedexEntry(name: 'Crystal',           year: '2000', totalBase: 251, generation: 2, cardColor1: 0xFF29B6F6, cardColor2: 0xFFE1F5FE),
    _PokedexEntry(name: 'Ruby / Sapphire',   year: '2002', totalBase: 386, generation: 3, cardColor1: 0xFFE53935, cardColor2: 0xFF1E88E5),
    _PokedexEntry(name: 'FireRed / LeafGreen (GBA)', year: '2004', totalBase: 386, generation: 3, cardColor1: 0xFFEF5350, cardColor2: 0xFF43A047),
    _PokedexEntry(name: 'Emerald',           year: '2004', totalBase: 386, generation: 3, cardColor1: 0xFF43A047, cardColor2: 0xFF00BCD4),
    _PokedexEntry(name: 'Diamond / Pearl',   year: '2006', totalBase: 493, generation: 4, cardColor1: 0xFF90CAF9, cardColor2: 0xFFF48FB1),
    _PokedexEntry(name: 'Platinum',          year: '2008', totalBase: 493, generation: 4, cardColor1: 0xFF78909C, cardColor2: 0xFFCFD8DC),
    _PokedexEntry(name: 'HeartGold / SoulSilver', year: '2009', totalBase: 493, generation: 4, cardColor1: 0xFFFFCA28, cardColor2: 0xFFB0BEC5),
    _PokedexEntry(name: 'Black / White',     year: '2010', totalBase: 649, generation: 5, cardColor1: 0xFF424242, cardColor2: 0xFFBDBDBD),
    _PokedexEntry(name: 'Black 2 / White 2', year: '2012', totalBase: 649, generation: 5, cardColor1: 0xFF1A237E, cardColor2: 0xFFE0E0E0),
    _PokedexEntry(name: 'X / Y',             year: '2013', totalBase: 721, generation: 6, cardColor1: 0xFF1565C0, cardColor2: 0xFFE53935),
    _PokedexEntry(name: 'Omega Ruby / Alpha Sapphire', year: '2014', totalBase: 721, generation: 6, cardColor1: 0xFFE53935, cardColor2: 0xFF1E88E5),
    _PokedexEntry(name: 'Sun / Moon',        year: '2016', totalBase: 807, generation: 7, cardColor1: 0xFFFF8F00, cardColor2: 0xFF7B1FA2),
    _PokedexEntry(name: 'Ultra Sun / Ultra Moon', year: '2017', totalBase: 807, generation: 7, cardColor1: 0xFFFF6F00, cardColor2: 0xFF4A148C),
    _PokedexEntry(name: "Let's Go Pikachu / Eevee", year: '2018', totalBase: 153, generation: 7, cardColor1: 0xFFFDD835, cardColor2: 0xFF8D6E63),
    _PokedexEntry(
      name: 'Sword / Shield', year: '2019', totalBase: 400, generation: 8,
      cardColor1: 0xFF42A5F5, cardColor2: 0xFFEF5350,
      dlcs: [
        _DlcInfo(name: 'Isle of Armor',  total: 210, sectionApiName: 'isle-of-armor'),
        _DlcInfo(name: 'Crown Tundra',   total: 210, sectionApiName: 'crown-tundra'),
      ],
    ),
    _PokedexEntry(name: 'Brilliant Diamond / Shining Pearl', year: '2021', totalBase: 493, generation: 8, cardColor1: 0xFF42A5F5, cardColor2: 0xFFEC407A),
    _PokedexEntry(name: 'Legends: Arceus', year: '2022', totalBase: 242, generation: 8, cardColor1: 0xFFFFCA28, cardColor2: 0xFFFFFDE7),
    _PokedexEntry(
      name: 'Scarlet / Violet', year: '2022', totalBase: 400, generation: 9,
      cardColor1: 0xFFEF6C00, cardColor2: 0xFF7B1FA2,
      dlcs: [
        _DlcInfo(name: 'Teal Mask',   total: 200, sectionApiName: 'kitakami'),
        _DlcInfo(name: 'Indigo Disk', total: 243, sectionApiName: 'blueberry'),
      ],
    ),
    _PokedexEntry(
      name: 'Legends: Z-A', year: '2025', totalBase: 132, generation: 9,
      cardColor1: 0xFF546E7A, cardColor2: 0xFFFFD54F,
      dlcs: [_DlcInfo(name: 'Mega Dimension', total: 132, sectionApiName: 'mega-dimension')],
    ),
    _PokedexEntry(name: 'FireRed / LeafGreen', year: '2026', totalBase: 386, generation: 1, cardColor1: 0xFFEF5350, cardColor2: 0xFF43A047),
    _PokedexEntry(
      name: 'Pokopia', year: '2026', totalBase: 304, generation: 0,
      cardColor1: 0xFF9C27B0, cardColor2: 0xFF7986CB,
      isPokopiaDex: true, pokopiaHabitatTotal: 200,
    ),
  ];

  static _PokedexEntry get _pokopiaEntry =>
      _gameEntries.firstWhere((e) => e.isPokopiaDex);

  List<_PokedexEntry> get _filterableGames =>
      [_nacEntry, _goEntry, ..._gameEntries.where((e) => !e.isPokopiaDex)];

  // ── Lifecycle ────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadCounts();
    _restoreLastGame();
  }

  Future<void> _restoreLastGame() async {
    final lastId = await _storage.getLastPokedexId();
    if (lastId == null || !mounted) return;
    final all = [_nacEntry, _goEntry, ..._gameEntries];
    final found = all.where((e) => e.pokedexId == lastId).firstOrNull;
    if (found != null && mounted) setState(() => _selectedGame = found);
  }

  Future<void> _loadCounts() async {
    // Busca tudo em paralelo e aplica em um único setState
    final active = await _storage.getActivePokedexIds();
    if (!mounted) return;

    final allEntries = [..._gameEntries, _goEntry, _nacEntry];

    // Lança todas as buscas em paralelo
    final mainFutures = allEntries.map((e) async {
      final c = await _storage.getCaughtCount(e.pokedexId);
      return MapEntry(e.pokedexId, c);
    });

    final dlcFutures = <Future<MapEntry<String, int>>>[];
    for (final e in _gameEntries) {
      for (final dlc in e.dlcs) {
        final key = '${e.pokedexId}/${dlc.sectionApiName}';
        dlcFutures.add(_storage
            .getCaughtCountForSection(e.pokedexId, dlc.sectionApiName)
            .then((c) => MapEntry(key, c)));
      }
      if (e.isPokopiaDex) {
        const sec = 'pokopia-habitats';
        final key = '${e.pokedexId}/$sec';
        dlcFutures.add(_storage
            .getCaughtCountForSection(e.pokedexId, sec)
            .then((c) => MapEntry(key, c)));
        dlcFutures.add(_storage
            .getCaughtMap('pokopia_event', pokopiaEventSpeciesIds)
            .then((m) => MapEntry(
                '${e.pokedexId}/event',
                m.values.where((v) => v).length)));
      }
    }

    final results = await Future.wait([...mainFutures, ...dlcFutures]);
    if (!mounted) return;

    final newCaught  = <String, int>{};
    final newDlc     = <String, int>{};
    for (final r in results) {
      if (allEntries.any((e) => e.pokedexId == r.key)) {
        newCaught[r.key] = r.value;
      } else {
        newDlc[r.key] = r.value;
      }
    }

    setState(() {
      _activePokedexIds = active;
      _caughtCounts.addAll(newCaught);
      _dlcCounts.addAll(newDlc);
    });
  }

  int _dlcCaught(_PokedexEntry entry, String sectionApiName) =>
      _dlcCounts['${entry.pokedexId}/$sectionApiName'] ?? 0;

  bool _isActive(_PokedexEntry e) =>
      _activePokedexIds == null || _activePokedexIds!.contains(e.pokedexId);

  bool get _goActive => _isActive(_goEntry);
  bool get _pokopiaActive => _gameEntries.any((e) => e.isPokopiaDex && _isActive(e));

  void _openPokedex(_PokedexEntry entry, {String? sectionFilter}) async {
    await _storage.setLastPokedexId(entry.pokedexId);
    setState(() => _selectedGame = entry);
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => PokedexScreen(
        pokedexId: entry.pokedexId,
        pokedexName: entry.name,
        totalPokemon: entry.totalBase,
        initialSectionFilter: sectionFilter,
      ),
    ));
    _loadCounts();
  }

  // ── Filtros ───────────────────────────────────────────────────

  List<_PokedexEntry> get _filteredEntries {
    if (_selectedGame != null) return [_selectedGame!];
    var entries = _gameEntries.where((e) => _isActive(e) && !e.isPokopiaDex).toList();
    if (_selectedGens.isNotEmpty) {
      entries = entries.where((e) {
        final gens = _gameGenerations[e.name] ?? [];
        return _selectedGens.any((g) => gens.contains(g));
      }).toList();
    }
    return entries;
  }

  void _showGameDropdown() async {
    final sentinel = const _PokedexEntry(name: '__clear__', year: '', totalBase: 0);
    final result = await showModalBottomSheet<_PokedexEntry>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _GamePickerSheet(
        games: _filterableGames.where((e) => _isActive(e) || e == _nacEntry).toList(),
        selected: _selectedGame,
        clearSentinel: sentinel,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedGame = result.name == '__clear__' ? null : result;
      _selectedGens.clear();
      _selectedTypes.clear();
    });
  }

  void _showGenDropdown() async {
    final available = _selectedGame != null
        ? (_gameGenerations[_selectedGame!.name] ?? List.generate(9, (i) => i + 1))
        : List.generate(9, (i) => i + 1);
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _GenPickerSheet(
          available: available, selected: Set.from(_selectedGens)),
    );
    if (result != null && mounted) setState(() => _selectedGens = result);
  }

  void _showTypeDropdown() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _TypePickerSheet(selected: Set.from(_selectedTypes)),
    );
    if (result != null && mounted) setState(() => _selectedTypes = result);
  }

  // ── NavBar ────────────────────────────────────────────────────

  void _onNavTap(_NavTab tab) {
    if (tab == _NavTab.pocket) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const PocketHubScreen()));
      return;
    }
    if (tab == _NavTab.go) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const GoHubScreen()));
      return;
    }
    if (tab == _NavTab.pokopia) {
      Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PokopiaHubScreen()))
          .then((_) => _loadCounts());
      return;
    }
    setState(() => _currentTab = tab);
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokédex'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _loadCounts();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(onRefresh: _loadCounts, child: _buildBody()),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildFilterBar(),
        const SizedBox(height: 12),
        _buildNacionalCard(context),
        const SizedBox(height: 10),
        _buildFilteredContent(),
        const SizedBox(height: 8),
      ]),
    );
  }

  // ── Barra de filtros ──────────────────────────────────────────

  Widget _buildFilterBar() {
    final hasGame = _selectedGame != null;
    final hasGen  = _selectedGens.isNotEmpty;
    final hasType = _selectedTypes.isNotEmpty;

    String gameLabel = hasGame ? _selectedGame!.name : 'Jogo';
    if (gameLabel.length > 18) gameLabel = '${gameLabel.substring(0, 16)}…';

    String genLabel = hasGen
        ? (_selectedGens.length == 1
            ? 'Gen ${_selectedGens.first}'
            : '${_selectedGens.length} gerações')
        : 'Geração';

    String typeLabel = hasType
        ? _selectedTypes.map((t) => typeNamePt[t] ?? t).join(' + ')
        : 'Tipo';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _FilterDropButton(
          label: gameLabel, active: hasGame, onTap: _showGameDropdown,
          onClear: hasGame ? () => setState(() {
            _selectedGame = null; _selectedGens.clear(); _selectedTypes.clear();
          }) : null,
        ),
        const SizedBox(width: 8),
        _FilterDropButton(
          label: genLabel, active: hasGen, onTap: _showGenDropdown,
          onClear: hasGen ? () => setState(() => _selectedGens.clear()) : null,
        ),
        const SizedBox(width: 8),
        _FilterDropButton(
          label: typeLabel, active: hasType, onTap: _showTypeDropdown,
          onClear: hasType ? () => setState(() => _selectedTypes.clear()) : null,
        ),
      ]),
    );
  }

  // ── Conteúdo filtrado ─────────────────────────────────────────

  Widget _buildFilteredContent() {
    final entries = _filteredEntries;
    final showGo = _goActive &&
        (_selectedGame == null || _selectedGame == _goEntry);
    final showPokopia = _pokopiaActive && _selectedGame == null;

    final all = <_PokedexEntry>[
      if (showGo && (_selectedGame == _goEntry || _selectedGame == null)) _goEntry,
      ...entries.where((e) => e != _nacEntry && e != _goEntry),
      if (showPokopia) _pokopiaEntry,
    ];

    if (all.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text(
          _activePokedexIds?.isEmpty == true
              ? 'Nenhuma Pokédex ativa.\nAcesse Configurações para ativar.'
              : 'Nenhum Pokémon encontrado com esse filtro.\nTente outra combinação.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        )),
      );
    }

    return _buildGrid(context, all);
  }

  // ── Grid 2 colunas ────────────────────────────────────────────

  Widget _buildGrid(BuildContext context, List<_PokedexEntry> entries) {
    final rows = <Widget>[];
    for (int i = 0; i < entries.length; i += 2) {
      final left  = entries[i];
      final right = i + 1 < entries.length ? entries[i + 1] : null;
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _buildCard(context, left)),
          const SizedBox(width: 10),
          Expanded(child: right != null
              ? _buildCard(context, right)
              : const SizedBox.shrink()),
        ]),
      ));
      if (i + 2 < entries.length) rows.add(const SizedBox(height: 10));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _buildCard(BuildContext context, _PokedexEntry e) {
    if (e.isPokopiaDex)    return _buildPokopiaCard(context, e);
    if (e.dlcs.isNotEmpty) return _buildDlcCard(context, e);
    return _buildSimpleCard(context, e);
  }

  // ── Cards ─────────────────────────────────────────────────────

  Widget _buildNacionalCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caught = _caughtCounts[_nacEntry.pokedexId] ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _openPokedex(_nacEntry),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft, end: Alignment.centerRight,
            colors: [
              Color(_nacEntry.cardColor1).withOpacity(isDark ? 0.4 : 0.35),
              Color(_nacEntry.cardColor2).withOpacity(isDark ? 0.4 : 0.35),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('National Pokédex',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('$caught/1025',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ]),
      ),
    );
  }

  Widget _buildSimpleCard(BuildContext context, _PokedexEntry entry) {
    final scheme  = Theme.of(context).colorScheme;
    final caught  = _caughtCounts[entry.pokedexId] ?? 0;
    final total   = entry.totalBase;
    return _CardShell(
      complete: caught >= total,
      onTap: () => _openPokedex(entry),
      cardColor1: Color(entry.cardColor1), cardColor2: Color(entry.cardColor2),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(entry.name, textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600, fontSize: 12, height: 1.3)),
            Expanded(child: Center(child: _buildCountRow(
              context, scheme, _regionFor(entry.name), caught, total))),
          ]),
      ),
    );
  }

  Widget _buildDlcCard(BuildContext context, _PokedexEntry entry) {
    final scheme   = Theme.of(context).colorScheme;
    final caught   = _caughtCounts[entry.pokedexId] ?? 0;
    final total    = entry.totalBase;
    return _CardShell(
      complete: caught >= total,
      onTap: () => _openPokedex(entry),
      cardColor1: Color(entry.cardColor1), cardColor2: Color(entry.cardColor2),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(entry.name, textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600, fontSize: 12, height: 1.3)),
            const Spacer(),
            _buildCountRow(context, scheme, _regionFor(entry.name), caught, total),
            ...entry.dlcs.expand((dlc) {
              final dlcCaught = _dlcCaught(entry, dlc.sectionApiName);
              return [
                _buildSeparator(scheme),
                _buildCountRow(context, scheme, dlc.name, dlcCaught, dlc.total,
                  onTap: () => _openPokedex(entry, sectionFilter: dlc.sectionApiName)),
              ];
            }),
            const SizedBox(height: 4),
          ]),
      ),
    );
  }

  Widget _buildPokopiaCard(BuildContext context, _PokedexEntry entry) {
    final scheme        = Theme.of(context).colorScheme;
    final amigosCaught  = _caughtCounts[entry.pokedexId] ?? 0;
    final eventCaught   = _dlcCounts['${entry.pokedexId}/event'] ?? 0;
    final amigosTotal   = entry.totalBase;
    final habitatCaught = _dlcCaught(entry, 'pokopia-habitats');
    final habitatTotal  = entry.pokopiaHabitatTotal ?? 0;
    return _CardShell(
      complete: false,
      onTap: () => _openPokedex(entry),
      cardColor1: Color(entry.cardColor1), cardColor2: Color(entry.cardColor2),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(entry.name, textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600, fontSize: 12, height: 1.3)),
            const Spacer(),
            _buildCountRow(context, scheme, 'Amigos',
                amigosCaught + eventCaught, amigosTotal),
            _buildSeparator(scheme),
            _buildCountRow(context, scheme, 'Habitats', habitatCaught, habitatTotal,
              onTap: () => _openPokedex(entry, sectionFilter: 'pokopia-habitats')),
            const SizedBox(height: 2),
          ]),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  Widget _buildCountRow(BuildContext context, ColorScheme scheme,
      String label, int caught, int total, {VoidCallback? onTap}) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 10.5, color: scheme.onSurfaceVariant))),
        Text('$caught/$total',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 10.5, fontWeight: FontWeight.w600, color: scheme.onSurface)),
      ]),
    );
    return onTap != null
        ? GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: row)
        : row;
  }

  Widget _buildSeparator(ColorScheme scheme) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Container(height: 1, color: scheme.onSurface.withOpacity(0.15)),
  );

  String _regionFor(String n) => const {
    'Red / Blue': 'Kanto', 'Yellow': 'Kanto',
    'Gold / Silver': 'Johto', 'Crystal': 'Johto',
    'Ruby / Sapphire': 'Hoenn', 'FireRed / LeafGreen (GBA)': 'Kanto', 'Emerald': 'Hoenn',
    'Diamond / Pearl': 'Sinnoh', 'Platinum': 'Sinnoh', 'HeartGold / SoulSilver': 'Johto',
    'Black / White': 'Unova', 'Black 2 / White 2': 'Unova',
    'X / Y': 'Kalos', 'Omega Ruby / Alpha Sapphire': 'Hoenn',
    'Sun / Moon': 'Alola', 'Ultra Sun / Ultra Moon': 'Alola',
    "Let's Go Pikachu / Eevee": 'Kanto', 'Sword / Shield': 'Galar',
    'Brilliant Diamond / Shining Pearl': 'Sinnoh', 'Legends: Arceus': 'Hisui',
    'Scarlet / Violet': 'Paldea', 'Legends: Z-A': 'Lumiose',
    'FireRed / LeafGreen': 'Kanto',
  }[n] ?? n;

  // ── Drawer ────────────────────────────────────────────────────

  Widget _buildDrawer() {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(child: SafeArea(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text('Menu', style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, fontSize: 18))),
        Divider(color: scheme.outlineVariant),
        _DrawerItem(icon: Icons.sports_martial_arts_outlined, label: 'Golpes',
          onTap: () { Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MovesListScreen())); }),
        _DrawerItem(icon: Icons.auto_awesome_outlined, label: 'Habilidades',
          onTap: () { Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AbilitiesListScreen())); }),
        _DrawerItem(icon: Icons.psychology_outlined, label: 'Naturezas',
          onTap: () { Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NaturesListScreen())); }),
        Divider(color: scheme.outlineVariant),
        _DrawerItem(icon: Icons.groups_2_outlined, label: 'Times',
          onTap: () { Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TeamsScreen())); }),
        _DrawerItem(icon: Icons.inventory_2_outlined, label: 'Itens',
          onTap: () { Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ItemsListScreen())); }),
        const Spacer(),
        Divider(color: scheme.outlineVariant),
        _DrawerItem(icon: Icons.settings_outlined, label: 'Configurações',
          onTap: () async { Navigator.pop(context);
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            _loadCounts(); }),
        const SizedBox(height: 8),
      ],
    )));
  }

  // ── Bottom Nav ────────────────────────────────────────────────

  Widget _buildBottomNav() {
    const items = [
      (_NavTab.home,    Icons.home_outlined,         'Início'),
      (_NavTab.pocket,  Icons.style_outlined,         'Pocket'),
      (_NavTab.go,      Icons.public_outlined,        'GO'),
      (_NavTab.pokopia, Icons.nature_people_outlined, 'Pokopia'),
    ];
    return SafeArea(child: Container(
      height: 62,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant, width: 0.5)),
      ),
      child: Row(children: items.map((item) {
        final isActive = _currentTab == item.$1;
        final color = isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant;
        return Expanded(child: InkWell(
          onTap: () => _onNavTap(item.$1),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(item.$2, size: 22, color: color),
            const SizedBox(height: 2),
            Text(item.$3, style: TextStyle(fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: color)),
          ]),
        ));
      }).toList()),
    ));
  }
}

// ─── FILTER DROP BUTTON ───────────────────────────────────────────

class _FilterDropButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _FilterDropButton({required this.label, required this.active,
    required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg     = active ? scheme.primary : scheme.onSurfaceVariant;
    final bg     = active ? scheme.primary.withOpacity(0.1) : Colors.transparent;
    final border = active ? scheme.primary : scheme.outlineVariant;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 6, onClear != null ? 4 : 12, 6),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border, width: 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
          const SizedBox(width: 4),
          if (onClear != null)
            GestureDetector(onTap: onClear,
              child: Icon(Icons.close, size: 14, color: fg))
          else
            Icon(Icons.keyboard_arrow_down, size: 16, color: fg),
        ]),
      ),
    );
  }
}

// ─── DRAWER ITEM ─────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DrawerItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, size: 22),
    title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
    onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 20), dense: true,
  );
}

// ─── GAME PICKER SHEET ────────────────────────────────────────────

class _GamePickerSheet extends StatelessWidget {
  final List<_PokedexEntry> games;
  final _PokedexEntry? selected;
  final _PokedexEntry clearSentinel;
  const _GamePickerSheet({required this.games, this.selected, required this.clearSentinel});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Selecionar Jogo', style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
            if (selected != null)
              TextButton(onPressed: () => Navigator.pop(context, clearSentinel),
                child: const Text('Limpar')),
          ])),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(child: ListView.builder(
          controller: ctrl, itemCount: games.length,
          itemBuilder: (_, i) {
            final g = games[i];
            final on = selected?.pokedexId == g.pokedexId;
            return ListTile(
              title: Text(g.name, style: TextStyle(fontSize: 13,
                fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                color: on ? scheme.primary : null)),
              subtitle: g.year.isNotEmpty
                  ? Text(g.year, style: const TextStyle(fontSize: 11)) : null,
              trailing: on ? Icon(Icons.check, color: scheme.primary, size: 18) : null,
              onTap: () => Navigator.pop(context, g),
            );
          },
        )),
      ]),
    );
  }
}

// ─── GENERATION PICKER SHEET ──────────────────────────────────────

class _GenPickerSheet extends StatefulWidget {
  final List<int> available;
  final Set<int> selected;
  const _GenPickerSheet({required this.available, required this.selected});
  @override State<_GenPickerSheet> createState() => _GenPickerSheetState();
}

class _GenPickerSheetState extends State<_GenPickerSheet> {
  late Set<int> _sel;
  @override void initState() { super.initState(); _sel = Set.from(widget.selected); }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Geração', style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
            TextButton(onPressed: () => Navigator.pop(context, <int>{}),
              child: const Text('Limpar')),
          ])),
        Divider(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, runSpacing: 8,
            children: widget.available.map((g) {
              final on = _sel.contains(g);
              return GestureDetector(
                onTap: () => setState(() => on ? _sel.remove(g) : _sel.add(g)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? scheme.primary : scheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: on ? scheme.primary : scheme.outlineVariant)),
                  child: Text('Geração $g', style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: on ? scheme.onPrimary : scheme.onSurface))),
              );
            }).toList()),
        ),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _sel),
              child: const Text('Aplicar')))),
        const SizedBox(height: 16),
      ]),
    );
  }
}

// ─── TYPE PICKER SHEET ────────────────────────────────────────────

class _TypePickerSheet extends StatefulWidget {
  final Set<String> selected;
  const _TypePickerSheet({required this.selected});
  @override State<_TypePickerSheet> createState() => _TypePickerSheetState();
}

class _TypePickerSheetState extends State<_TypePickerSheet> {
  late Set<String> _sel;
  @override void initState() { super.initState(); _sel = Set.from(widget.selected); }

  static const _types = [
    'normal','fire','water','electric','grass','ice',
    'fighting','poison','ground','flying','psychic','bug',
    'rock','ghost','dragon','dark','steel','fairy',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.65, minChildSize: 0.5, maxChildSize: 0.9, expand: false,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Tipo (máx. 2)', style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
            TextButton(onPressed: () => Navigator.pop(context, <String>{}),
              child: const Text('Limpar')),
          ])),
        if (_sel.isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(alignment: Alignment.centerLeft,
              child: Text('${_sel.length}/2 selecionado(s)',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)))),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(child: GridView.builder(
          controller: ctrl, padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
            childAspectRatio: 2.6),
          itemCount: _types.length,
          itemBuilder: (_, i) {
            final t = _types[i];
            final label = typeNamePt[t] ?? t;
            final color = typeIconColors[t] ?? const Color(0xFF888888);
            final on = _sel.contains(t);
            final disabled = !on && _sel.length >= 2;
            return GestureDetector(
              onTap: disabled ? null : () => setState(() => on ? _sel.remove(t) : _sel.add(t)),
              child: Opacity(opacity: disabled ? 0.35 : 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: on ? color : color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: on ? color : color.withOpacity(0.35), width: 1)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Image.asset('assets/types/$t.png', width: 20, height: 20,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 20)),
                    const SizedBox(width: 4),
                    Flexible(child: Text(label, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: on ? Colors.white : color))),
                  ]),
                )),
            );
          },
        )),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _sel),
              child: const Text('Aplicar')))),
      ]),
    );
  }
}

// ─── CARD SHELL ───────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  final bool complete;
  final VoidCallback onTap;
  final Widget child;
  final Color cardColor1, cardColor2;
  const _CardShell({required this.complete, required this.onTap,
    required this.child, required this.cardColor1, required this.cardColor2});

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final opacity = isDark ? 0.40 : 0.28;
    return GestureDetector(onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [cardColor1.withOpacity(opacity), cardColor2.withOpacity(opacity)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: complete ? const Color(0xFF34C759).withOpacity(0.5) : scheme.outlineVariant,
            width: 1)),
        child: child,
      ));
  }
}