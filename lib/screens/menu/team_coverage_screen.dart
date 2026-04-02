import 'package:flutter/material.dart';
import 'package:dexcurator/theme/type_colors.dart';
import 'package:dexcurator/screens/detail/detail_shared.dart'
    show ptType, typeIconAsset, calculateWeaknesses, PokeballLoader;
import 'package:dexcurator/services/dex_bundle_service.dart';
import 'package:dexcurator/services/pokeapi_service.dart';
import 'package:dexcurator/services/pokedex_data_service.dart';
import 'package:dexcurator/services/teams_storage_service.dart';
import 'package:dexcurator/screens/menu/teams_screen.dart'
    show TeamsGamePickerSheet, kTeamsGamesByGen, gameById;

const _allTypes = ['normal','fire','water','electric','grass','ice','fighting',
    'poison','ground','flying','psychic','bug','rock','ghost',
    'dragon','dark','steel','fairy'];

class TeamCoverageScreen extends StatefulWidget {
  final Map<String, dynamic> activeGame;
  final List<PokemonTeam>    savedTeams;
  final PokemonTeam?         initial;
  const TeamCoverageScreen({super.key,
      required this.activeGame, required this.savedTeams, this.initial});
  @override State<TeamCoverageScreen> createState() => _TeamCoverageScreenState();
}

class _TeamCoverageScreenState extends State<TeamCoverageScreen>
    with SingleTickerProviderStateMixin {
  late TabController          _tab;
  // Aba "Time Salvo"
  PokemonTeam?                _selectedTeam;
  // Aba "Montar"
  List<int>                   _custom   = [];
  List<int>                   _available= [];
  bool                        _loadingAvail = true;
  Map<String, dynamic>        _game     = {};

  @override
  void initState() {
    super.initState();
    _tab          = TabController(length: 2, vsync: this);
    _game         = Map.from(widget.activeGame);
    _selectedTeam = widget.initial ??
        (widget.savedTeams.isNotEmpty ? widget.savedTeams.first : null);
    _loadAvailable();
    // Se veio com time inicial, vai para aba de times salvos (índice 1)
    if (widget.initial != null) _tab.index = 1;
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _loadAvailable() async {
    final sections = PokeApiService.pokedexSections[_game['id']] ?? [];
    final ids = <int>{};
    for (final s in sections) {
      final e = await DexBundleService.instance.loadSection(s.apiName);
      if (e != null) for (final x in e) ids.add(x['speciesId']!);
    }
    if (ids.isEmpty) for (int i = 1; i <= 1025; i++) ids.add(i);
    if (mounted) setState(() {
      _available    = ids.toList()..sort();
      _loadingAvail = false;
    });
  }

  // ── Cálculo de cobertura ───────────────────────────────────────
  List<int> get _analyzeMembers =>
      _tab.index == 0 ? (_selectedTeam?.members ?? []) : _custom;

  // Fraquezas: conta quantos pokémon do time são fracos a cada tipo
  Map<String, int> _weakCount(List<int> ids) {
    final svc = PokedexDataService.instance;
    final map = <String, int>{};
    for (final id in ids) {
      final wk = calculateWeaknesses(svc.getTypes(id));
      for (final e in wk.entries)
        if (e.value >= 2.0) map[e.key] = (map[e.key] ?? 0) + 1;
    }
    return map;
  }

  // Cobertura ofensiva: quais tipos o time pode acertar com x2
  Set<String> _offensiveCoverage(List<int> ids) {
    final svc      = PokedexDataService.instance;
    final covered  = <String>{};
    for (final id in ids) {
      for (final type in svc.getTypes(id)) {
        // Um pokémon do tipo X pode usar moves do tipo X com STAB
        // e esses moves são super efetivos contra certos tipos
        final chart = _offChart[type.toLowerCase()] ?? {};
        for (final e in chart.entries)
          if (e.value >= 2.0) covered.add(e.key);
      }
    }
    return covered;
  }

  // Tipos não cobertos ofensivamente
  List<String> _uncovered(List<int> ids) {
    final cov = _offensiveCoverage(ids);
    return _allTypes.where((t) => !cov.contains(t)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobertura de Tipos'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tab,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'Montar time'),
            Tab(text: 'Times salvos'),
          ],
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        // ── Aba 1: Montar time ────────────────────────────────────
        _BuildTab(
          available:    _available,
          loading:      _loadingAvail,
          members:      _custom,
          activeGame:   _game,
          onToggle:     (id) => setState(() {
            _custom.contains(id) ? _custom.remove(id)
                : _custom.length < 6 ? _custom.add(id) : null;
          }),
          analysis: _custom.length >= 2
              ? _CoverageAnalysis(
                  weakCount:  _weakCount(_custom),
                  uncovered:  _uncovered(_custom),
                  members:    _custom,
                )
              : null,
        ),
        // ── Aba 2: Times salvos ───────────────────────────────────
        _SavedTeamTab(
          savedTeams: widget.savedTeams,
          selected:   _selectedTeam,
          onSelect:   (t) => setState(() => _selectedTeam = t),
          analysis:   _selectedTeam != null
              ? _CoverageAnalysis(
                  weakCount:  _weakCount(_selectedTeam!.members),
                  uncovered:  _uncovered(_selectedTeam!.members),
                  members:    _selectedTeam!.members,
                )
              : null,
        ),
      ]),
    );
  }
}

// ─── Dados do chart ofensivo ──────────────────────────────────────
const _offChart = {
  'normal':   <String, double>{},
  'fire':     {'grass': 2.0, 'ice': 2.0, 'bug': 2.0, 'steel': 2.0},
  'water':    {'fire': 2.0, 'ground': 2.0, 'rock': 2.0},
  'electric': {'water': 2.0, 'flying': 2.0},
  'grass':    {'water': 2.0, 'ground': 2.0, 'rock': 2.0},
  'ice':      {'grass': 2.0, 'ground': 2.0, 'flying': 2.0, 'dragon': 2.0},
  'fighting': {'normal': 2.0, 'ice': 2.0, 'rock': 2.0, 'dark': 2.0, 'steel': 2.0},
  'poison':   {'grass': 2.0, 'fairy': 2.0},
  'ground':   {'fire': 2.0, 'electric': 2.0, 'poison': 2.0, 'rock': 2.0, 'steel': 2.0},
  'flying':   {'grass': 2.0, 'fighting': 2.0, 'bug': 2.0},
  'psychic':  {'fighting': 2.0, 'poison': 2.0},
  'bug':      {'grass': 2.0, 'psychic': 2.0, 'dark': 2.0},
  'rock':     {'fire': 2.0, 'ice': 2.0, 'flying': 2.0, 'bug': 2.0},
  'ghost':    {'psychic': 2.0, 'ghost': 2.0},
  'dragon':   {'dragon': 2.0},
  'dark':     {'psychic': 2.0, 'ghost': 2.0},
  'steel':    {'ice': 2.0, 'rock': 2.0, 'fairy': 2.0},
  'fairy':    {'fighting': 2.0, 'dragon': 2.0, 'dark': 2.0},
};

// ─── Modelo de análise ────────────────────────────────────────────
class _CoverageAnalysis {
  final Map<String, int> weakCount;
  final List<String>     uncovered;
  final List<int>        members;
  const _CoverageAnalysis({
      required this.weakCount, required this.uncovered, required this.members});
}

// ─── Aba time salvo ───────────────────────────────────────────────
class _SavedTeamTab extends StatelessWidget {
  final List<PokemonTeam>    savedTeams;
  final PokemonTeam?         selected;
  final void Function(PokemonTeam) onSelect;
  final _CoverageAnalysis?   analysis;
  const _SavedTeamTab({required this.savedTeams, required this.selected,
      required this.onSelect, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (savedTeams.isEmpty) return Center(child: Text(
        'Nenhum time salvo.\nCrie um time primeiro.',
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.onSurfaceVariant)));

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Seletor de time
      Text('Selecionar time', style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      ...savedTeams.map((t) {
        final sel = t.id == selected?.id;
        return GestureDetector(
          onTap: () => onSelect(t),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? scheme.primaryContainer.withOpacity(0.3)
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: sel ? scheme.primary : scheme.outlineVariant,
                  width: sel ? 1.5 : 0.5)),
            child: Row(children: [
              if (sel) Icon(Icons.check_circle, size: 14, color: scheme.primary),
              if (sel) const SizedBox(width: 6),
              Expanded(child: Text(t.name, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: sel ? scheme.primary : scheme.onSurface))),
              Text(t.gameName, style: TextStyle(fontSize: 10,
                  color: scheme.onSurfaceVariant)),
            ]),
          ),
        );
      }),
      if (analysis != null) ...[
        const SizedBox(height: 16),
        _CoverageReport(analysis: analysis!),
      ],
    ]);
  }
}

// ─── Aba montar time ──────────────────────────────────────────────
class _BuildTab extends StatefulWidget {
  final List<int>             available, members;
  final bool                  loading;
  final void Function(int)    onToggle;
  final _CoverageAnalysis?    analysis;
  final Map<String, dynamic>  activeGame;
  const _BuildTab({required this.available, required this.members,
      required this.loading, required this.onToggle,
      required this.analysis, required this.activeGame});
  @override State<_BuildTab> createState() => _BuildTabState();
}

class _BuildTabState extends State<_BuildTab> {
  String  _search  = '';
  String? _saveMsg;
  final   _ctrl    = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _saveTeam() async {
    if (widget.members.isEmpty) return;
    final gameId   = widget.activeGame['id']   as String? ?? '';
    final gameName = widget.activeGame['name'] as String? ?? '';
    try {
      final canSave = await TeamsStorageService.instance.canSave(gameId);
      if (!canSave) {
        setState(() => _saveMsg = 'Limite de ${TeamsStorageService.maxPerGame} times atingido.');
        return;
      }
      final team = PokemonTeam(
        id: TeamsStorageService.newId(), gameId: gameId, gameName: gameName,
        name: 'Time de cobertura - $gameName',
        members: List<int>.from(widget.members),
      );
      await TeamsStorageService.instance.save(team);
      setState(() => _saveMsg = 'Time salvo!');
    } catch (e) {
      setState(() => _saveMsg = 'Erro ao salvar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.loading) return Center(child: PokeballLoader());

    final filtered = _search.isEmpty ? widget.available
        : widget.available.where((id) =>
            PokedexDataService.instance.getName(id)
                .toLowerCase().contains(_search.toLowerCase())).toList();

    return Column(children: [
      // Slots do time
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(children: List.generate(6, (i) {
          final filled = i < widget.members.length;
          return Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: filled ? () => widget.onToggle(widget.members[i]) : null,
              child: AspectRatio(aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: filled ? scheme.primaryContainer.withOpacity(0.3)
                        : scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: filled ? scheme.primary : scheme.outlineVariant,
                        width: filled ? 1.5 : 0.5)),
                  child: filled
                      ? Image.asset(
                          'assets/sprites/artwork/${widget.members[i]}.webp',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.catching_pokemon, size: 18,
                                  color: scheme.onSurfaceVariant))
                      : Icon(Icons.add, size: 16,
                          color: scheme.onSurfaceVariant.withOpacity(0.3)),
                ),
              ),
            ),
          ));
        })),
      ),
      if (widget.analysis != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: _CoverageReport(analysis: widget.analysis!),
        ),
      const Divider(height: 1),
      // Botão salvar time montado
      if (widget.members.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            OutlinedButton.icon(
              onPressed: _saveTeam,
              icon: const Icon(Icons.save_outlined, size: 16),
              label: Text('Salvar time (${widget.members.length}/6)'),
              style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  side: BorderSide(color: scheme.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 8)),
            ),
            if (_saveMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_saveMsg!, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: _saveMsg!.startsWith('Erro') || _saveMsg!.startsWith('Limite')
                            ? scheme.error : Colors.green.shade700)),
              ),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: TextField(
          controller: _ctrl,
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Buscar Pokémon...',
            prefixIcon: const Icon(Icons.search, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: scheme.outlineVariant)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            isDense: true,
          ),
        ),
      ),
      Expanded(child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, childAspectRatio: 0.9,
            crossAxisSpacing: 6, mainAxisSpacing: 6),
        itemCount: filtered.length,
        itemBuilder: (ctx, i) {
          final id     = filtered[i];
          final inTeam = widget.members.contains(id);
          final full   = widget.members.length >= 6 && !inTeam;
          final scheme = Theme.of(ctx).colorScheme;
          return GestureDetector(
            onTap: full ? null : () => widget.onToggle(id),
            child: Container(
              decoration: BoxDecoration(
                color: inTeam ? scheme.primaryContainer.withOpacity(0.3)
                    : full ? scheme.surfaceContainer
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: inTeam ? scheme.primary : scheme.outlineVariant,
                    width: inTeam ? 1.5 : 0.5)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: Image.asset(
                      'assets/sprites/artwork/$id.webp',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.catching_pokemon, size: 24,
                          color: scheme.onSurfaceVariant.withOpacity(0.4)))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                    child: Text(PokedexDataService.instance.getName(id),
                        style: TextStyle(fontSize: 8,
                            color: full ? scheme.onSurfaceVariant.withOpacity(0.4)
                                : scheme.onSurface),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          );
        },
      )),
    ]);
  }
}

// ─── Relatório de cobertura ───────────────────────────────────────
class _CoverageReport extends StatelessWidget {
  final _CoverageAnalysis analysis;
  const _CoverageReport({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wk     = analysis.weakCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    final unc    = analysis.uncovered;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Fraquezas compartilhadas
      if (wk.isNotEmpty) ...[
        Text('Fraquezas do time',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6,
          children: wk.map((e) {
            final tc    = TypeColors.fromType(ptType(e.key));
            final level = e.value >= 4 ? scheme.error
                : e.value >= 3 ? Colors.orange : tc;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tc.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: tc.withOpacity(0.4), width: 0.5)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Image.asset(typeIconAsset(e.key), width: 12, height: 12,
                    errorBuilder: (_, __, ___) => const SizedBox()),
                const SizedBox(width: 4),
                Text(ptType(e.key), style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w600, color: tc)),
                const SizedBox(width: 4),
                Text('${e.value}×', style: TextStyle(fontSize: 9,
                    fontWeight: FontWeight.w700, color: level)),
              ]),
            );
          }).toList()),
        const SizedBox(height: 12),
      ],

      // Tipos sem cobertura ofensiva
      Text('Sem cobertura ofensiva',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (unc.isEmpty)
        Text('Cobertura completa!',
            style: TextStyle(fontSize: 12, color: Colors.green.shade700,
                fontWeight: FontWeight.w600))
      else
        Wrap(spacing: 6, runSpacing: 6,
          children: unc.map((t) {
            final tc = TypeColors.fromType(ptType(t));
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tc.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: tc.withOpacity(0.4), width: 0.5)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Image.asset(typeIconAsset(t), width: 12, height: 12,
                    errorBuilder: (_, __, ___) => const SizedBox()),
                const SizedBox(width: 4),
                Text(ptType(t), style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w600, color: tc)),
              ]),
            );
          }).toList()),
    ]);
  }
}
