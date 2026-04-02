import 'package:flutter/material.dart';
import 'package:dexcurator/screens/detail/detail_shared.dart'
    show PokeballLoader;
import 'package:dexcurator/services/storage_service.dart';
import 'package:dexcurator/services/teams_storage_service.dart';
import 'package:dexcurator/screens/menu/team_builder_screen.dart';
import 'package:dexcurator/screens/menu/team_coverage_screen.dart';
import 'package:dexcurator/screens/menu/team_suggestion_screen.dart';

// ─── Dados de jogos ───────────────────────────────────────────────
const kTeamsGamesByGen = <int, List<Map<String, dynamic>>>{
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

Map<String, dynamic>? gameById(String id) {
  for (final gen in kTeamsGamesByGen.values)
    for (final g in gen)
      if (g['id'] == id) return g;
  return null;
}

// ─── Tela Hub ─────────────────────────────────────────────────────
class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});
  @override State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  List<PokemonTeam>      _teams      = [];
  bool                   _loading    = true;
  Map<String, dynamic>?  _activeGame;

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    final lastDex = await StorageService().getLastPokedexId() ?? 'scarlet___violet';
    final safe    = (lastDex.startsWith('pokopia') ||
        lastDex == 'pokémon_go' || lastDex == 'nacional')
        ? 'scarlet___violet' : lastDex;
    _activeGame = gameById(safe) ?? kTeamsGamesByGen[9]!.first;
    await _reload();
  }

  Future<void> _reload() async {
    final teams = await TeamsStorageService.instance.getAll();
    if (mounted) setState(() { _teams = teams; _loading = false; });
  }

  // ── Navegação ──────────────────────────────────────────────────
  Future<void> _openBuilder({PokemonTeam? team}) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => TeamBuilderScreen(activeGame: _activeGame!, existing: team)));
    _reload();
  }

  Future<void> _openCoverage({PokemonTeam? initial}) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => TeamCoverageScreen(
          activeGame: _activeGame!, savedTeams: _teams, initial: initial)));
    _reload();
  }

  Future<void> _openSuggestion() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => TeamSuggestionScreen(activeGame: _activeGame!)));
    _reload();
  }

  Future<void> _deleteTeam(PokemonTeam t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir time'),
        content: Text('Excluir "${t.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await TeamsStorageService.instance.delete(t.id);
      _reload();
    }
  }

  Future<void> _pickGame() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => TeamsGamePickerSheet(
          selectedId: _activeGame?['id'] as String? ?? ''),
    );
    if (result != null && mounted) setState(() => _activeGame = result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Times'),
          scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent),
      body: _loading
          ? Center(child: PokeballLoader())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [

            // Jogo ativo
            _GameBanner(game: _activeGame!, onTap: _pickGame),
            const SizedBox(height: 16),

            // Ações
            Row(children: [
              Expanded(child: _ActionCard(
                icon: Icons.add_circle_outline,
                label: 'Criar\nTime',
                color: scheme.primaryContainer,
                textColor: scheme.onPrimaryContainer,
                onTap: () => _openBuilder(),
              )),
              const SizedBox(width: 10),
              Expanded(child: _ActionCard(
                icon: Icons.shield_outlined,
                label: 'Validar\nCobertura',
                color: scheme.secondaryContainer,
                textColor: scheme.onSecondaryContainer,
                onTap: () => _openCoverage(),
              )),
              const SizedBox(width: 10),
              Expanded(child: _ActionCard(
                icon: Icons.auto_awesome_outlined,
                label: 'Sugerir\nTime',
                color: scheme.tertiaryContainer,
                textColor: scheme.onTertiaryContainer,
                onTap: _openSuggestion,
              )),
            ]),

            const SizedBox(height: 24),

            // Times salvos
            Row(children: [
              const Text('Times salvos',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${_teams.length} time${_teams.length != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 8),

            if (_teams.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text('Nenhum time salvo ainda.',
                    style: TextStyle(color: scheme.onSurfaceVariant))),
              )
            else
              for (final entry in _grouped().entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
                  child: Text(entry.key, style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant,
                      letterSpacing: 0.4)),
                ),
                for (final t in entry.value)
                  _TeamCard(
                    team: t, scheme: scheme,
                    onEdit:     () => _openBuilder(team: t),
                    onCoverage: () => _openCoverage(initial: t),
                    onDelete:   () => _deleteTeam(t),
                  ),
              ],
          ]),
    );
  }

  Map<String, List<PokemonTeam>> _grouped() {
    final m = <String, List<PokemonTeam>>{};
    for (final t in _teams) (m[t.gameName] ??= []).add(t);
    return m;
  }
}

// ─── Widgets ──────────────────────────────────────────────────────
class _GameBanner extends StatelessWidget {
  final Map<String, dynamic> game;
  final VoidCallback onTap;
  const _GameBanner({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final c1 = Color(game['c1'] as int).withOpacity(isDark ? 0.4 : 0.25);
    final c2 = Color(game['c2'] as int).withOpacity(isDark ? 0.4 : 0.25);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c1, c2]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant)),
        child: Row(children: [
          const Icon(Icons.videogame_asset_outlined, size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(game['name'] as String,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Text('alterar', style: TextStyle(fontSize: 10,
              color: scheme.onSurfaceVariant)),
          const SizedBox(width: 2),
          Icon(Icons.expand_more, size: 14, color: scheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon; final String label;
  final Color color, textColor; final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label,
      required this.color, required this.textColor, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: color,
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, size: 24, color: textColor),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11,
            fontWeight: FontWeight.w600, color: textColor),
            textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _TeamCard extends StatelessWidget {
  final PokemonTeam team; final ColorScheme scheme;
  final VoidCallback onEdit, onCoverage, onDelete;
  const _TeamCard({required this.team, required this.scheme,
      required this.onEdit, required this.onCoverage, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(team.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          _iconBtn(Icons.shield_outlined, onCoverage),
          _iconBtn(Icons.edit_outlined, onEdit),
          _iconBtn(Icons.delete_outline, onDelete, color: Colors.red),
        ]),
        const SizedBox(height: 8),
        Row(children: List.generate(6, (i) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AspectRatio(aspectRatio: 1,
            child: i < team.members.length
                ? Image.asset('assets/sprites/artwork/${team.members[i]}.webp',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _emptySlot(scheme))
                : _emptySlot(scheme)),
        )))),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback fn, {Color? color}) =>
      IconButton(icon: Icon(icon, size: 18, color: color),
          onPressed: fn, padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32));

  Widget _emptySlot(ColorScheme s) => Container(
      decoration: BoxDecoration(color: s.surfaceContainer,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: s.outlineVariant, width: 0.5)),
      child: Icon(Icons.add, size: 14,
          color: s.onSurfaceVariant.withOpacity(0.25)));
}

// ─── Game picker (reutilizado pelas sub-telas) ────────────────────
class TeamsGamePickerSheet extends StatelessWidget {
  final String selectedId;
  const TeamsGamePickerSheet({super.key, required this.selectedId});

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final op      = isDark ? 0.4 : 0.25;

    Widget card(Map<String, dynamic> g) {
      final sel = g['id'] == selectedId;
      final c1  = Color(g['c1'] as int).withOpacity(op);
      final c2  = Color(g['c2'] as int).withOpacity(op);
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
            Expanded(child: Text(g['name'] as String, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: sel ? scheme.primary : scheme.onSurface))),
            if (sel) Icon(Icons.check_circle, size: 16, color: scheme.primary),
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
            children: kTeamsGamesByGen.entries.map((e) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
                    child: Text('Geração ${e.key}', style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant, letterSpacing: 0.5))),
                ...e.value.map(card),
              ],
            )).toList())),
      ]),
    );
  }
}
