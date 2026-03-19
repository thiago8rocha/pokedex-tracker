import 'package:flutter/material.dart';
import 'package:pokedex_tracker/services/storage_service.dart';
import 'package:pokedex_tracker/screens/pokedex_screen.dart';
import 'package:pokedex_tracker/screens/settings_screen.dart';

// ─── MODELOS ─────────────────────────────────────────────────────

class _DlcInfo {
  final String name;
  final int total;
  final String sectionApiName;
  const _DlcInfo({
    required this.name,
    required this.total,
    required this.sectionApiName,
  });
}

class _PokedexEntry {
  final String name;
  final String year;
  final int totalBase;
  final List<_DlcInfo> dlcs;
  final bool isPokopiaDex;
  final int? pokopiaHabitatTotal;

  const _PokedexEntry({
    required this.name,
    required this.year,
    required this.totalBase,
    this.dlcs = const [],
    this.isPokopiaDex = false,
    this.pokopiaHabitatTotal,
  });

  String get pokedexId =>
      name.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_').replaceAll("'", '');
}

// ─── TABS ─────────────────────────────────────────────────────────

enum _NavTab { home, nacional, times, go, pokopia }

// ─── HOME SCREEN ──────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  final Map<String, int> _caughtCounts = {};
  Set<String>? _activePokedexIds;
  _NavTab _currentTab = _NavTab.home;

  // ── Catálogo ─────────────────────────────────────────────────

  static const _PokedexEntry _nacEntry  = _PokedexEntry(name: 'Nacional',    year: '',     totalBase: 1025);
  static const _PokedexEntry _goEntry   = _PokedexEntry(name: 'Pokémon GO',  year: '2016', totalBase: 941);

  static const List<_PokedexEntry> _gameEntries = [
    // ── Sem DLC ──────────────────────────────────────────────
    _PokedexEntry(name: "Let's Go Pikachu / Eevee",          year: '2018', totalBase: 153),
    _PokedexEntry(name: 'Brilliant Diamond / Shining Pearl', year: '2021', totalBase: 493),
    _PokedexEntry(name: 'Legends: Arceus',                   year: '2022', totalBase: 242),
    _PokedexEntry(name: 'FireRed / LeafGreen',               year: '2026', totalBase: 386),

    // ── Com DLC ──────────────────────────────────────────────
    _PokedexEntry(
      name: 'Sword / Shield', year: '2019', totalBase: 400,
      dlcs: [
        _DlcInfo(name: 'Isle of Armor',  total: 210, sectionApiName: 'isle-of-armor'),
        _DlcInfo(name: 'Crown Tundra',   total: 210, sectionApiName: 'crown-tundra'),
      ],
    ),
    _PokedexEntry(
      name: 'Scarlet / Violet', year: '2022', totalBase: 400,
      dlcs: [
        _DlcInfo(name: 'Teal Mask',   total: 200, sectionApiName: 'kitakami'),
        _DlcInfo(name: 'Indigo Disk', total: 243, sectionApiName: 'blueberry'),
      ],
    ),
    _PokedexEntry(
      name: 'Legends: Z-A', year: '2025', totalBase: 132,
      dlcs: [_DlcInfo(name: 'Mega Dimension', total: 132, sectionApiName: 'mega-dimension')],
    ),

    // ── Pokopia ──────────────────────────────────────────────
    _PokedexEntry(
      name: 'Pokopia', year: '2026', totalBase: 311,
      isPokopiaDex: true,
      pokopiaHabitatTotal: 200,
    ),
  ];

  static _PokedexEntry get _pokopiaEntry =>
      _gameEntries.firstWhere((e) => e.isPokopiaDex);

  // ── Lifecycle ────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final active = await _storage.getActivePokedexIds();
    if (!mounted) return;
    setState(() => _activePokedexIds = active);
    for (final e in [..._gameEntries, _goEntry, _nacEntry]) {
      final c = await _storage.getCaughtCount(e.pokedexId);
      if (!mounted) return;
      setState(() => _caughtCounts[e.pokedexId] = c);
    }
  }

  bool _isActive(_PokedexEntry e) =>
      _activePokedexIds == null || _activePokedexIds!.contains(e.pokedexId);

  bool get _goActive      => _isActive(_goEntry);
  bool get _pokopiaActive => _gameEntries.any((e) => e.isPokopiaDex && _isActive(e));

  void _openPokedex(_PokedexEntry entry, {String? sectionFilter}) async {
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

  void _onNavTap(_NavTab tab) {
    if (tab == _NavTab.nacional) { _openPokedex(_nacEntry);      return; }
    if (tab == _NavTab.go)       { _openPokedex(_goEntry);       return; }
    if (tab == _NavTab.pokopia)  { _openPokedex(_pokopiaEntry);  return; }
    if (tab == _NavTab.times) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Times — em breve')),
      );
      return;
    }
    setState(() => _currentTab = tab);
  }

  // ── Build principal ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokedex'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
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
      body: RefreshIndicator(onRefresh: _loadCounts, child: _buildBody()),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Body ──────────────────────────────────────────────────────

  Widget _buildBody() {
    final activeEntries = _gameEntries.where(_isActive).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // 1. Card Nacional
          _buildNacionalCard(context),

          // 2. Card Pokémon GO (condicional)
          if (_goActive) ...[
            const SizedBox(height: 10),
            _buildGoCard(context),
          ],

          const SizedBox(height: 14),

          // 3. Grid 2 colunas — altura automática por conteúdo
          if (activeEntries.isEmpty)
            _buildEmptyState(context)
          else
            LayoutBuilder(builder: (ctx, constraints) {
              final w = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: activeEntries.map((e) {
                  Widget card;
                  if (e.isPokopiaDex) {
                    card = _buildPokopiaCard(context, e);
                  } else if (e.dlcs.isNotEmpty) {
                    card = _buildDlcCard(context, e);
                  } else {
                    card = _buildSimpleCard(context, e);
                  }
                  return SizedBox(width: w, child: card);
                }).toList(),
              );
            }),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  FUNÇÕES DE CARD — uma por tipo
  // ════════════════════════════════════════════════════════════

  // ── 1. Nacional ──────────────────────────────────────────────
  // Fundo neutro levemente elevado, sem ícone, largura total
  Widget _buildNacionalCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caught = _caughtCounts[_nacEntry.pokedexId] ?? 0;
    const total  = 1025;

    return GestureDetector(
      onTap: () => _openPokedex(_nacEntry),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          // Cor neutra elevada — sem rosa, sem cor de marca
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('National Pokédex',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('$caught / $total',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant)),
            ]),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // ── 2. Pokémon GO ─────────────────────────────────────────────
  // Mesmo visual da Nacional — fundo neutro, sem ícone
  Widget _buildGoCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caught = _caughtCounts[_goEntry.pokedexId] ?? 0;
    final total  = _goEntry.totalBase;
    final complete = caught >= total;

    return GestureDetector(
      onTap: () => _openPokedex(_goEntry),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pokémon GO',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('$caught / $total',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: complete
                      ? const Color(0xFF34C759)
                      : scheme.onSurfaceVariant)),
            ]),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // ── 3. Card simples (sem DLC) ─────────────────────────────────
  // Nome centralizado, "Capturados" + X / Y centralizados
  Widget _buildSimpleCard(BuildContext context, _PokedexEntry entry) {
    final scheme  = Theme.of(context).colorScheme;
    final caught  = _caughtCounts[entry.pokedexId] ?? 0;
    final total   = entry.totalBase;
    final complete = caught >= total;

    return _CardShell(
      complete: complete,
      onTap: () => _openPokedex(entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(entry.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600, fontSize: 12, height: 1.3)),
            const SizedBox(height: 8),
            Text('Capturados',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text('$caught / $total',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: complete ? const Color(0xFF34C759) : scheme.onSurface)),
          ],
        ),
      ),
    );
  }

  // ── 4. Card com DLC ───────────────────────────────────────────
  // Nome centralizado, Capturados + X/Y, separador, linhas de DLC
  Widget _buildDlcCard(BuildContext context, _PokedexEntry entry) {
    final scheme  = Theme.of(context).colorScheme;
    final caught  = _caughtCounts[entry.pokedexId] ?? 0;
    final total   = entry.totalBase;
    final complete = caught >= total;

    return _CardShell(
      complete: complete,
      onTap: () => _openPokedex(entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nome centralizado
            Text(entry.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600, fontSize: 12, height: 1.3)),
            const SizedBox(height: 8),
            Text('Capturados',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text('$caught / $total',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: complete ? const Color(0xFF34C759) : scheme.onSurface)),
            const SizedBox(height: 10),
            // Separador
            Divider(height: 1, thickness: 0.5, color: scheme.outlineVariant),
            const SizedBox(height: 8),
            // Linhas de DLC — alinhadas à esquerda
            ...entry.dlcs.map((dlc) => _buildDlcRow(context, scheme, dlc.name,
              dlc.total, () => _openPokedex(entry, sectionFilter: dlc.sectionApiName))),
          ],
        ),
      ),
    );
  }

  // ── 5. Card Pokopia ───────────────────────────────────────────
  // Nome centralizado.
  // Amigos e Habitats: dois contadores no mesmo nível hierárquico,
  // separados por uma linha fina — igual a DLCs, sem nenhum "principal".
  Widget _buildPokopiaCard(BuildContext context, _PokedexEntry entry) {
    final scheme      = Theme.of(context).colorScheme;
    final amigosCaught = _caughtCounts[entry.pokedexId] ?? 0;
    final amigosTotal  = entry.totalBase;
    final habitatTotal = entry.pokopiaHabitatTotal ?? 0;

    return _CardShell(
      complete: false, // Pokopia não tem estado "completo" claro
      onTap: () => _openPokedex(entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nome centralizado
            Text(entry.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600, fontSize: 12, height: 1.3)),
            const SizedBox(height: 10),
            // Separador
            Divider(height: 1, thickness: 0.5, color: scheme.outlineVariant),
            const SizedBox(height: 8),
            // Amigos — mesmo nível que Habitats
            _buildDlcRow(context, scheme, 'Amigos', amigosTotal,
              () => _openPokedex(entry),
              caught: amigosCaught),
            // Separador entre Amigos e Habitats
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Divider(height: 1, thickness: 0.5, color: scheme.outlineVariant),
            ),
            // Habitats — mesmo nível que Amigos
            _buildDlcRow(context, scheme, 'Habitats', habitatTotal,
              () => _openPokedex(entry, sectionFilter: 'pokopia-habitats')),
          ],
        ),
      ),
    );
  }

  // ── Linha de DLC / contador ───────────────────────────────────
  Widget _buildDlcRow(
    BuildContext context,
    ColorScheme scheme,
    String name,
    int total,
    VoidCallback onTap, {
    int? caught,
  }) {
    final valueText = caught != null ? '$caught / $total' : '— / $total';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10, color: scheme.onSurfaceVariant),
                overflow: TextOverflow.ellipsis),
            ),
            Text(valueText,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10, fontWeight: FontWeight.w500,
                color: scheme.onSurface)),
          ],
        ),
      ),
    );
  }

  // ── Estado vazio ──────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'Nenhuma Pokedex ativa.\nAcesse Configurações para ativar.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  // ── Bottom Navigation ─────────────────────────────────────────
  Widget _buildBottomNav() {
    final items = <_NavItem>[
      const _NavItem(tab: _NavTab.home,     icon: Icons.home_outlined,          label: 'Inicio'),
      const _NavItem(tab: _NavTab.nacional, icon: Icons.menu_book_outlined,     label: 'Nacional'),
      const _NavItem(tab: _NavTab.times,    icon: Icons.groups_2_outlined,      label: 'Times'),
      if (_goActive)
        const _NavItem(tab: _NavTab.go,     icon: Icons.public_outlined,        label: 'GO'),
      if (_pokopiaActive)
        const _NavItem(tab: _NavTab.pokopia, icon: Icons.nature_people_outlined, label: 'Pokopia'),
    ];

    return SafeArea(
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: items.map((item) {
            final isActive = _currentTab == item.tab;
            final color = isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant;
            return Expanded(
              child: InkWell(
                onTap: () => _onNavTap(item.tab),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 22, color: color),
                    const SizedBox(height: 2),
                    Text(item.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: color)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  final _NavTab tab;
  final IconData icon;
  final String label;
  const _NavItem({required this.tab, required this.icon, required this.label});
}

// ─── SHELL COMPARTILHADA DOS CARDS DO GRID ────────────────────────
// Borda visível (width: 1), cor de fundo, borda-radius, GestureDetector

class _CardShell extends StatelessWidget {
  final bool complete;
  final VoidCallback onTap;
  final Widget child;

  const _CardShell({
    required this.complete,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            // Borda com width: 1 para ficar visível — 0.5 some no subpixel
            color: complete
                ? const Color(0xFF34C759).withOpacity(0.5)
                : scheme.outlineVariant,
            width: 1,
          ),
        ),
        child: child,
      ),
    );
  }
}