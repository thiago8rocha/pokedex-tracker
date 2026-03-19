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
  // Duas cores para gradiente diagonal (tema claro)
  final int cardColor1;
  final int cardColor2;

  const _PokedexEntry({
    required this.name,
    required this.year,
    required this.totalBase,
    this.dlcs = const [],
    this.isPokopiaDex = false,
    this.pokopiaHabitatTotal,
    this.cardColor1 = 0xFFE8E8F0,
    this.cardColor2 = 0xFFE8E8F0,
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

  // Contadores da Pokedex principal
  final Map<String, int> _caughtCounts = {};
  // Contadores de DLC: key = 'pokedexId/sectionApiName'
  final Map<String, int> _dlcCounts = {};

  Set<String>? _activePokedexIds;
  _NavTab _currentTab = _NavTab.home;

  // ── Catálogo ─────────────────────────────────────────────────

  static const _PokedexEntry _nacEntry =
      _PokedexEntry(name: 'Nacional',   year: '',     totalBase: 1025,
        cardColor1: 0xFFE8524A, cardColor2: 0xFFB71C1C); // vermelho Pokédex
  static const _PokedexEntry _goEntry =
      _PokedexEntry(name: 'Pokémon GO', year: '2016', totalBase: 941,
        cardColor1: 0xFF4285F4, cardColor2: 0xFF0D47A1); // azul GO

  static const List<_PokedexEntry> _gameEntries = [
    // ── Geração I ────────────────────────────────────────────────
    _PokedexEntry(name: 'Red / Blue', year: '1996', totalBase: 151,
      cardColor1: 0xFFE53935, cardColor2: 0xFF1565C0), // vermelho Charizard / azul Blastoise
    _PokedexEntry(name: 'Yellow', year: '1998', totalBase: 151,
      cardColor1: 0xFFFDD835, cardColor2: 0xFFFF8F00), // amarelo / laranja Pikachu

    // ── Geração II ───────────────────────────────────────────────
    _PokedexEntry(name: 'Gold / Silver', year: '1999', totalBase: 251,
      cardColor1: 0xFFFFCA28, cardColor2: 0xFFB0BEC5), // dourado Ho-Oh / prateado Lugia
    _PokedexEntry(name: 'Crystal', year: '2000', totalBase: 251,
      cardColor1: 0xFF29B6F6, cardColor2: 0xFFE1F5FE), // azul cristal Suicune

    // ── Geração III ──────────────────────────────────────────────
    _PokedexEntry(name: 'Ruby / Sapphire', year: '2002', totalBase: 386,
      cardColor1: 0xFFE53935, cardColor2: 0xFF1E88E5), // vermelho Groudon / azul Kyogre
    _PokedexEntry(name: 'FireRed / LeafGreen (GBA)', year: '2004', totalBase: 386,
      cardColor1: 0xFFEF5350, cardColor2: 0xFF43A047), // vermelho / verde
    _PokedexEntry(name: 'Emerald', year: '2004', totalBase: 386,
      cardColor1: 0xFF43A047, cardColor2: 0xFF00BCD4), // verde esmeralda Rayquaza

    // ── Geração IV ───────────────────────────────────────────────
    _PokedexEntry(name: 'Diamond / Pearl', year: '2006', totalBase: 493,
      cardColor1: 0xFF90CAF9, cardColor2: 0xFFF48FB1), // azul Dialga / rosa Palkia
    _PokedexEntry(name: 'Platinum', year: '2008', totalBase: 493,
      cardColor1: 0xFF78909C, cardColor2: 0xFFCFD8DC), // cinza prateado Giratina
    _PokedexEntry(name: 'HeartGold / SoulSilver', year: '2009', totalBase: 493,
      cardColor1: 0xFFFFCA28, cardColor2: 0xFFB0BEC5), // dourado Ho-Oh / prateado Lugia

    // ── Geração V ────────────────────────────────────────────────
    _PokedexEntry(name: 'Black / White', year: '2010', totalBase: 649,
      cardColor1: 0xFF424242, cardColor2: 0xFFBDBDBD), // preto Reshiram / branco Zekrom
    _PokedexEntry(name: 'Black 2 / White 2', year: '2012', totalBase: 649,
      cardColor1: 0xFF1A237E, cardColor2: 0xFFE0E0E0), // azul escuro / branco Kyurem

    // ── Geração VI ───────────────────────────────────────────────
    _PokedexEntry(name: 'X / Y', year: '2013', totalBase: 721,
      cardColor1: 0xFF1565C0, cardColor2: 0xFFE53935), // azul Xerneas / vermelho Yveltal
    _PokedexEntry(name: 'Omega Ruby / Alpha Sapphire', year: '2014', totalBase: 721,
      cardColor1: 0xFFE53935, cardColor2: 0xFF1E88E5), // vermelho Groudon / azul Kyogre

    // ── Geração VII ──────────────────────────────────────────────
    _PokedexEntry(name: 'Sun / Moon', year: '2016', totalBase: 807,
      cardColor1: 0xFFFF8F00, cardColor2: 0xFF7B1FA2), // laranja Solgaleo / roxo Lunala
    _PokedexEntry(name: 'Ultra Sun / Ultra Moon', year: '2017', totalBase: 807,
      cardColor1: 0xFFFF6F00, cardColor2: 0xFF4A148C), // laranja / roxo escuro Necrozma

    // ── Mobile ───────────────────────────────────────────────────
    // (GO é tratado separadamente como _goEntry)

    // ── Geração VIII (Switch) ─────────────────────────────────────
    _PokedexEntry(name: "Let's Go Pikachu / Eevee", year: '2018', totalBase: 153,
      cardColor1: 0xFFFDD835, cardColor2: 0xFF8D6E63), // amarelo Pikachu / marrom Eevee
    _PokedexEntry(
      name: 'Sword / Shield', year: '2019', totalBase: 400,
      cardColor1: 0xFF42A5F5, cardColor2: 0xFFEF5350, // azul Zacian / vermelho Zamazenta
      dlcs: [
        _DlcInfo(name: 'Isle of Armor',  total: 210, sectionApiName: 'isle-of-armor'),
        _DlcInfo(name: 'Crown Tundra',   total: 210, sectionApiName: 'crown-tundra'),
      ],
    ),
    _PokedexEntry(name: 'Brilliant Diamond / Shining Pearl', year: '2021', totalBase: 493,
      cardColor1: 0xFF42A5F5, cardColor2: 0xFFEC407A), // azul Dialga / rosa Palkia
    _PokedexEntry(name: 'Legends: Arceus', year: '2022', totalBase: 242,
      cardColor1: 0xFFFFCA28, cardColor2: 0xFFFFFDE7), // dourado / branco pérola Arceus
    _PokedexEntry(
      name: 'Scarlet / Violet', year: '2022', totalBase: 400,
      cardColor1: 0xFFEF6C00, cardColor2: 0xFF7B1FA2, // laranja Koraidon / roxo Miraidon
      dlcs: [
        _DlcInfo(name: 'Teal Mask',   total: 200, sectionApiName: 'kitakami'),
        _DlcInfo(name: 'Indigo Disk', total: 243, sectionApiName: 'blueberry'),
      ],
    ),

    // ── Switch futuros ────────────────────────────────────────────
    _PokedexEntry(
      name: 'Legends: Z-A', year: '2025', totalBase: 132,
      cardColor1: 0xFF546E7A, cardColor2: 0xFFFFD54F, // cinza Lumiose / dourado Mega
      dlcs: [_DlcInfo(name: 'Mega Dimension', total: 132, sectionApiName: 'mega-dimension')],
    ),
    _PokedexEntry(name: 'FireRed / LeafGreen', year: '2026', totalBase: 386,
      cardColor1: 0xFFEF5350, cardColor2: 0xFF43A047), // vermelho fogo / verde folha
    _PokedexEntry(
      name: 'Pokopia', year: '2026', totalBase: 311,
      cardColor1: 0xFF9C27B0, cardColor2: 0xFF7986CB, // roxo Ditto / lilás
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

    // Contadores principais
    for (final e in [..._gameEntries, _goEntry, _nacEntry]) {
      final c = await _storage.getCaughtCount(e.pokedexId);
      if (!mounted) return;
      setState(() => _caughtCounts[e.pokedexId] = c);
    }

    // Contadores de DLC — cruzamento seção × capturados
    for (final e in _gameEntries) {
      for (final dlc in e.dlcs) {
        final key = '${e.pokedexId}/${dlc.sectionApiName}';
        final c = await _storage.getCaughtCountForSection(
            e.pokedexId, dlc.sectionApiName);
        if (!mounted) return;
        setState(() => _dlcCounts[key] = c);
      }
      // Habitats do Pokopia
      if (e.isPokopiaDex) {
        const sec = 'pokopia-habitats';
        final key = '${e.pokedexId}/$sec';
        final c = await _storage.getCaughtCountForSection(e.pokedexId, sec);
        if (!mounted) return;
        setState(() => _dlcCounts[key] = c);
      }
    }
  }

  int _dlcCaught(_PokedexEntry entry, String sectionApiName) =>
      _dlcCounts['${entry.pokedexId}/$sectionApiName'] ?? 0;

  bool _isActive(_PokedexEntry e) =>
      _activePokedexIds == null || _activePokedexIds!.contains(e.pokedexId);

  bool get _goActive => _isActive(_goEntry);
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

  Widget _buildBody() {
    final activeEntries = _gameEntries.where(_isActive).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildNacionalCard(context),
          if (_goActive) ...[
            const SizedBox(height: 10),
            _buildGoCard(context),
          ],
          const SizedBox(height: 14),
          if (activeEntries.isEmpty)
            _buildEmptyState(context)
          else
            _buildGrid(context, activeEntries),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Grid 2 colunas com alturas iguais por linha ──────────────
  // IntrinsicHeight força os dois cards de cada linha a terem a
  // mesma altura (a do maior), eliminando espaços vazios.
  Widget _buildGrid(BuildContext context, List<_PokedexEntry> entries) {
    final rows = <Widget>[];
    for (int i = 0; i < entries.length; i += 2) {
      final left  = entries[i];
      final right = i + 1 < entries.length ? entries[i + 1] : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildCard(context, left)),
              const SizedBox(width: 10),
              Expanded(
                child: right != null
                    ? _buildCard(context, right)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
      if (i + 2 < entries.length) rows.add(const SizedBox(height: 10));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _buildCard(BuildContext context, _PokedexEntry e) {
    if (e.isPokopiaDex)    return _buildPokopiaCard(context, e);
    if (e.dlcs.isNotEmpty) return _buildDlcCard(context, e);
    return _buildSimpleCard(context, e);
  }

  // ════════════════════════════════════════════════════════════
  //  FUNÇÕES DE CARD — uma por tipo
  // ════════════════════════════════════════════════════════════

  // ── 1. Nacional ──────────────────────────────────────────────
  Widget _buildNacionalCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caught = _caughtCounts[_nacEntry.pokedexId] ?? 0;
    const total  = 1025;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opacity = isDark ? 0.40 : 0.35;
    final decoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(_nacEntry.cardColor1).withOpacity(opacity),
            Color(_nacEntry.cardColor2).withOpacity(opacity),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant, width: 1));

    return GestureDetector(
      onTap: () => _openPokedex(_nacEntry),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: decoration,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('National Pokédex',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('$caught/$total',
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
  Widget _buildGoCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caught = _caughtCounts[_goEntry.pokedexId] ?? 0;
    final total  = _goEntry.totalBase;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opacity = isDark ? 0.40 : 0.35;
    final decoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(_goEntry.cardColor1).withOpacity(opacity),
            Color(_goEntry.cardColor2).withOpacity(opacity),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant, width: 1));

    return GestureDetector(
      onTap: () => _openPokedex(_goEntry),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: decoration,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pokémon GO',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('$caught/$total',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant)),
            ]),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // ── 3. Card simples (sem DLC) ─────────────────────────────────
  Widget _buildSimpleCard(BuildContext context, _PokedexEntry entry) {
    final scheme   = Theme.of(context).colorScheme;
    final caught   = _caughtCounts[entry.pokedexId] ?? 0;
    final total    = entry.totalBase;
    final complete = caught >= total;

    return _CardShell(
      complete: complete,
      onTap: () => _openPokedex(entry),
      cardColor1: Color(entry.cardColor1),
      cardColor2: Color(entry.cardColor2),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.max, // ocupa toda a altura do IntrinsicHeight
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(entry.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600, fontSize: 12, height: 1.3)),
            // Spacer empurra as linhas de contagem para o rodapé
            const Spacer(),
            _buildCountRow(context, scheme, _regionFor(entry.name), caught, total),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  // ── 4. Card com DLC ───────────────────────────────────────────
  // Nome + região: X/Y
  // ─────────────────
  // DLC1  X/Y
  // ─────────────────
  // DLC2  X/Y
  Widget _buildDlcCard(BuildContext context, _PokedexEntry entry) {
    final scheme   = Theme.of(context).colorScheme;
    final caught   = _caughtCounts[entry.pokedexId] ?? 0;
    final total    = entry.totalBase;
    final complete = caught >= total;

    // Linha principal do jogo
    // Para DLC cards o nome + região fica numa só linha (ex: "Galar: 0/400")
    // "Galar" é o nome da região — usamos o nome do jogo de forma curta
    final regionLabel = _regionFor(entry.name);

    return _CardShell(
      complete: complete,
      onTap: () => _openPokedex(entry),
      cardColor1: Color(entry.cardColor1),
      cardColor2: Color(entry.cardColor2),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Título centralizado
            Text(entry.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600, fontSize: 12, height: 1.3)),
            // Spacer empurra contadores para o rodapé, alinhando com o card vizinho
            const Spacer(),
            // Linha principal: região X/Y
            _buildCountRow(context, scheme, regionLabel, caught, total),
            // DLCs com separador entre cada uma
            ...entry.dlcs.expand((dlc) {
              final dlcCaught = _dlcCaught(entry, dlc.sectionApiName);
              return [
                _buildSeparator(scheme),
                _buildCountRow(context, scheme, dlc.name, dlcCaught, dlc.total,
                  onTap: () => _openPokedex(entry, sectionFilter: dlc.sectionApiName)),
              ];
            }),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  // ── 5. Card Pokopia ───────────────────────────────────────────
  // Pokopia
  // Amigos   X/311
  // ─────────────
  // Habitats X/200
  Widget _buildPokopiaCard(BuildContext context, _PokedexEntry entry) {
    final scheme        = Theme.of(context).colorScheme;
    final amigosCaught  = _caughtCounts[entry.pokedexId] ?? 0;
    final amigosTotal   = entry.totalBase;
    final habitatCaught = _dlcCaught(entry, 'pokopia-habitats');
    final habitatTotal  = entry.pokopiaHabitatTotal ?? 0;

    return _CardShell(
      complete: false,
      onTap: () => _openPokedex(entry),
      cardColor1: Color(entry.cardColor1),
      cardColor2: Color(entry.cardColor2),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Título centralizado
            Text(entry.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600, fontSize: 12, height: 1.3)),
            // Spacer empurra contadores para o rodapé
            const Spacer(),
            // Amigos — sem separador antes dele
            _buildCountRow(context, scheme, 'Amigos', amigosCaught, amigosTotal),
            // Separador ENTRE Amigos e Habitats
            _buildSeparator(scheme),
            // Habitats — mesmo nível que Amigos
            _buildCountRow(context, scheme, 'Habitats', habitatCaught, habitatTotal,
              onTap: () => _openPokedex(entry, sectionFilter: 'pokopia-habitats')),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  // ── Helpers de linha ──────────────────────────────────────────

  Widget _buildCountRow(
    BuildContext context,
    ColorScheme scheme,
    String label,
    int caught,
    int total, {
    VoidCallback? onTap,
  }) {
    final text = '$caught/$total';
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10.5, color: scheme.onSurfaceVariant)),
          ),
          Text(text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10.5, fontWeight: FontWeight.w600,
              color: scheme.onSurface)),
        ],
      ),
    );
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: row,
      );
    }
    return row;
  }

  Widget _buildSeparator(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        height: 1,
        color: scheme.onSurface.withOpacity(0.15),
      ),
    );
  }

  // ── Região por jogo (para linha principal do DLC card) ────────
  String _regionFor(String gameName) {
    switch (gameName) {
      case 'Red / Blue':                          return 'Kanto';
      case 'Yellow':                              return 'Kanto';
      case 'Gold / Silver':                       return 'Johto';
      case 'Crystal':                             return 'Johto';
      case 'Ruby / Sapphire':                     return 'Hoenn';
      case 'FireRed / LeafGreen (GBA)':           return 'Kanto';
      case 'Emerald':                             return 'Hoenn';
      case 'Diamond / Pearl':                     return 'Sinnoh';
      case 'Platinum':                            return 'Sinnoh';
      case 'HeartGold / SoulSilver':              return 'Johto';
      case 'Black / White':                       return 'Unova';
      case 'Black 2 / White 2':                   return 'Unova';
      case 'X / Y':                               return 'Kalos';
      case 'Omega Ruby / Alpha Sapphire':         return 'Hoenn';
      case 'Sun / Moon':                          return 'Alola';
      case 'Ultra Sun / Ultra Moon':              return 'Alola';
      case "Let's Go Pikachu / Eevee":            return 'Kanto';
      case 'Sword / Shield':                      return 'Galar';
      case 'Brilliant Diamond / Shining Pearl':   return 'Sinnoh';
      case 'Legends: Arceus':                     return 'Hisui';
      case 'Scarlet / Violet':                    return 'Paldea';
      case 'Legends: Z-A':                        return 'Lumiose';
      case 'FireRed / LeafGreen':                 return 'Kanto';
      default:                                    return gameName;
    }
  }

  // ── Estado vazio ──────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) => Padding(
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

  // ── Bottom Navigation ─────────────────────────────────────────
  Widget _buildBottomNav() {
    final items = <_NavItem>[
      const _NavItem(tab: _NavTab.home,     icon: Icons.home_outlined,           label: 'Inicio'),
      const _NavItem(tab: _NavTab.nacional, icon: Icons.menu_book_outlined,      label: 'Nacional'),
      const _NavItem(tab: _NavTab.times,    icon: Icons.groups_2_outlined,       label: 'Times'),
      if (_goActive)
        const _NavItem(tab: _NavTab.go,     icon: Icons.public_outlined,         label: 'GO'),
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

class _CardShell extends StatelessWidget {
  final bool complete;
  final VoidCallback onTap;
  final Widget child;
  final Color cardColor1;
  final Color cardColor2;

  const _CardShell({
    required this.complete,
    required this.onTap,
    required this.child,
    required this.cardColor1,
    required this.cardColor2,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Claro: opacidade 0.28 — suave sobre fundo branco
    // Escuro: opacidade 0.22 — mais sutil sobre fundo escuro, evita cores muito saturadas
    final opacity = isDark ? 0.40 : 0.28;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cardColor1.withOpacity(opacity),
              cardColor2.withOpacity(opacity),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
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