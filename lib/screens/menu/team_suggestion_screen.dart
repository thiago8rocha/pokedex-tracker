import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pokedex_tracker/theme/type_colors.dart';
import 'package:pokedex_tracker/screens/detail/detail_shared.dart'
    show ptType, typeIconAsset, calculateWeaknesses;
import 'package:pokedex_tracker/services/dex_bundle_service.dart';
import 'package:pokedex_tracker/services/pokeapi_service.dart';
import 'package:pokedex_tracker/services/pokedex_data_service.dart';
import 'package:pokedex_tracker/services/teams_storage_service.dart';
import 'package:pokedex_tracker/screens/menu/teams_screen.dart'
    show TeamsGamePickerSheet, kTeamsGamesByGen, gameById;

// ─── Tela de sugestão ─────────────────────────────────────────────
class TeamSuggestionScreen extends StatefulWidget {
  final Map<String, dynamic> activeGame;
  const TeamSuggestionScreen({super.key, required this.activeGame});
  @override State<TeamSuggestionScreen> createState() => _TeamSuggestionScreenState();
}

class _TeamSuggestionScreenState extends State<TeamSuggestionScreen> {
  Map<String, dynamic>  _game       = {};
  List<int>             _pool       = [];
  List<int>             _suggested  = [];
  bool                  _loading    = true;
  bool                  _generating = false;
  String?               _saveMsg;

  @override
  void initState() {
    super.initState();
    _game = Map.from(widget.activeGame);
    _loadAndGenerate();
  }

  // ── Carregar pool e gerar ──────────────────────────────────────
  Future<void> _loadAndGenerate() async {
    setState(() { _loading = true; _saveMsg = null; });
    final sections = PokeApiService.pokedexSections[_game['id']] ?? [];
    final ids      = <int>{};
    for (final s in sections) {
      final e = await DexBundleService.instance.loadSection(s.apiName);
      if (e != null) for (final x in e) ids.add(x['speciesId']!);
    }
    if (ids.isEmpty) for (int i = 1; i <= 1025; i++) ids.add(i);
    _pool = ids.toList();
    await _generate();
  }

  Future<void> _generate() async {
    setState(() { _generating = true; _saveMsg = null; });
    // Rodar em isolate via compute seria ideal, mas com 400 pokémon
    // o algoritmo greedy é rápido o suficiente no main thread
    final team = _buildTeam(_pool);
    if (mounted) setState(() { _suggested = team; _generating = false; _loading = false; });
  }

  // ── Algoritmo greedy de cobertura ──────────────────────────────
  // Score de um conjunto de pokémon:
  //   +2 por tipo ofensivamente coberto (tem alguém com STAB super efetivo)
  //   -3 por fraqueza compartilhada por 3+ membros (ponto crítico)
  //   -1 por fraqueza compartilhada por 2 membros
  List<int> _buildTeam(List<int> pool) {
    final svc     = PokedexDataService.instance;
    final rng     = Random();
    // Embaralhar para variedade entre gerações
    final shuffled = List<int>.from(pool)..shuffle(rng);
    // Usar apenas os primeiros 200 para velocidade (amostragem suficiente)
    final candidates = shuffled.take(min(200, shuffled.length)).toList();

    final team = <int>[];

    // Greedy: 6 iterações, cada uma adiciona o pokémon que mais melhora o score
    for (int step = 0; step < 6; step++) {
      int    bestId    = -1;
      double bestDelta = -9999;

      for (final id in candidates) {
        if (team.contains(id)) continue;
        final candidate = [...team, id];
        final delta     = _score(candidate, svc) - _score(team, svc);
        if (delta > bestDelta) { bestDelta = delta; bestId = id; }
      }

      if (bestId == -1) break;
      team.add(bestId);
    }

    return team;
  }

  double _score(List<int> team, PokedexDataService svc) {
    if (team.isEmpty) return 0;

    // Cobertura ofensiva
    final covered = <String>{};
    for (final id in team) {
      for (final type in svc.getTypes(id)) {
        final chart = _offChart[type.toLowerCase()] ?? {};
        for (final e in chart.entries)
          if (e.value >= 2.0) covered.add(e.key);
      }
    }
    double score = covered.length * 2.0;

    // Fraquezas compartilhadas
    final weakCount = <String, int>{};
    for (final id in team) {
      final wk = calculateWeaknesses(svc.getTypes(id));
      for (final e in wk.entries)
        if (e.value >= 2.0) weakCount[e.key] = (weakCount[e.key] ?? 0) + 1;
    }
    for (final count in weakCount.values) {
      if (count >= 3) score -= 3;
      else if (count == 2) score -= 1;
    }

    // Diversidade de tipos (bônus por tipo primário único)
    final primaryTypes = team.map((id) =>
        svc.getTypes(id).isNotEmpty ? svc.getTypes(id)[0] : '').toSet();
    score += primaryTypes.length * 0.5;

    return score;
  }

  Future<void> _saveTeam() async {
    if (_suggested.isEmpty) return;
    final gameId   = _game['id'] as String;
    final gameName = _game['name'] as String;

    final canSave = await TeamsStorageService.instance.canSave(gameId);
    if (!canSave && mounted) {
      setState(() => _saveMsg =
          'Limite de ${TeamsStorageService.maxPerGame} times por jogo atingido.');
      return;
    }

    final team = PokemonTeam(
      id:       TeamsStorageService.newId(),
      gameId:   gameId,
      gameName: gameName,
      name:     'Sugestão - $gameName',
      members:  List.from(_suggested),
    );
    await TeamsStorageService.instance.save(team);
    if (mounted) setState(() => _saveMsg = 'Time salvo!');
  }

  Future<void> _changeGame() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => TeamsGamePickerSheet(
          selectedId: _game['id'] as String? ?? ''),
    );
    if (result != null && mounted) {
      setState(() => _game = result);
      _loadAndGenerate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c1 = Color(_game['c1'] as int? ?? 0xFFEF6C00)
        .withOpacity(isDark ? 0.4 : 0.25);
    final c2 = Color(_game['c2'] as int? ?? 0xFF7B1FA2)
        .withOpacity(isDark ? 0.4 : 0.25);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sugestão de Time'),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [

        // Jogo ativo
        GestureDetector(
          onTap: _changeGame,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c1, c2]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant)),
            child: Row(children: [
              const Icon(Icons.videogame_asset_outlined, size: 15),
              const SizedBox(width: 8),
              Expanded(child: Text(_game['name'] as String? ?? '',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              Text('alterar', style: TextStyle(fontSize: 10,
                  color: scheme.onSurfaceVariant)),
              const SizedBox(width: 2),
              Icon(Icons.expand_more, size: 14,
                  color: scheme.onSurfaceVariant),
            ]),
          ),
        ),

        const SizedBox(height: 20),

        if (_loading || _generating)
          _LoadingCard(scheme: scheme)
        else ...[

          // Time sugerido
          Text('Time sugerido',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),

          // Grid 2×3 dos membros
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, childAspectRatio: 0.85,
                crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: _suggested.length,
            itemBuilder: (ctx, i) {
              final id    = _suggested[i];
              final types = PokedexDataService.instance.getTypes(id);
              final name  = PokedexDataService.instance.getName(id);
              final tc    = types.isNotEmpty
                  ? TypeColors.fromType(ptType(types[0]))
                  : scheme.surfaceContainerHighest;
              return Container(
                decoration: BoxDecoration(
                  color: tc.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tc.withOpacity(0.35))),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(flex: 3, child: Image.asset(
                        'assets/sprites/artwork/$id.webp',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.catching_pokemon, size: 36,
                            color: scheme.onSurfaceVariant.withOpacity(0.4)))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                      child: Column(children: [
                        Text(name, style: const TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(mainAxisAlignment: MainAxisAlignment.center,
                            children: types.take(2).map((t) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Image.asset(typeIconAsset(t),
                                  width: 12, height: 12,
                                  errorBuilder: (_, __, ___) => const SizedBox()),
                            )).toList()),
                      ]),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Cobertura do time sugerido
          if (_suggested.isNotEmpty)
            _SuggestionCoverage(members: _suggested),

          const SizedBox(height: 20),

          // Ações
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Nova sugestão'),
              style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  side: BorderSide(color: scheme.primary, width: 1.5)),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(
              onPressed: _saveTeam,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Salvar time'),
              style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6))),
            )),
          ]),

          if (_saveMsg != null) ...[
            const SizedBox(height: 8),
            Text(_saveMsg!, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12,
                    color: _saveMsg!.startsWith('Limite')
                        ? scheme.error : Colors.green.shade700,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ]),
    );
  }
}

// ─── Chart ofensivo ───────────────────────────────────────────────
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

// ─── Cobertura do time sugerido ───────────────────────────────────
class _SuggestionCoverage extends StatelessWidget {
  final List<int> members;
  const _SuggestionCoverage({required this.members});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final svc    = PokedexDataService.instance;

    // Ofensiva
    final covered = <String>{};
    for (final id in members) {
      for (final type in svc.getTypes(id)) {
        final chart = _offChart[type.toLowerCase()] ?? {};
        for (final e in chart.entries)
          if (e.value >= 2.0) covered.add(e.key);
      }
    }
    final uncovered = ['normal','fire','water','electric','grass','ice',
        'fighting','poison','ground','flying','psychic','bug','rock',
        'ghost','dragon','dark','steel','fairy']
        .where((t) => !covered.contains(t)).toList();

    // Fraquezas
    final weakCount = <String, int>{};
    for (final id in members) {
      final wk = calculateWeaknesses(svc.getTypes(id));
      for (final e in wk.entries)
        if (e.value >= 2.0) weakCount[e.key] = (weakCount[e.key] ?? 0) + 1;
    }
    final sharedWeak = weakCount.entries
        .where((e) => e.value >= 2)
        .toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Score resumido
        Row(children: [
          Icon(Icons.shield_outlined, size: 14,
              color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text('Cobertura: ${covered.length}/18 tipos',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),

        if (sharedWeak.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Fraquezas compartilhadas',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4,
            children: sharedWeak.map((e) {
              final tc = TypeColors.fromType(ptType(e.key));
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: tc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: tc.withOpacity(0.35), width: 0.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset(typeIconAsset(e.key), width: 11, height: 11,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                  const SizedBox(width: 3),
                  Text(ptType(e.key), style: TextStyle(fontSize: 9,
                      fontWeight: FontWeight.w600, color: tc)),
                  const SizedBox(width: 3),
                  Text('${e.value}×', style: TextStyle(fontSize: 8,
                      color: e.value >= 3 ? scheme.error : scheme.onSurfaceVariant)),
                ]),
              );
            }).toList()),
        ],

        if (uncovered.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Sem cobertura ofensiva',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4,
            children: uncovered.map((t) {
              final tc = TypeColors.fromType(ptType(t));
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: tc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: tc.withOpacity(0.35), width: 0.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset(typeIconAsset(t), width: 11, height: 11,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                  const SizedBox(width: 3),
                  Text(ptType(t), style: TextStyle(fontSize: 9,
                      fontWeight: FontWeight.w600, color: tc)),
                ]),
              );
            }).toList()),
        ],
      ]),
    );
  }
}

// ─── Loading ──────────────────────────────────────────────────────
class _LoadingCard extends StatelessWidget {
  final ColorScheme scheme;
  const _LoadingCard({required this.scheme});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      const CircularProgressIndicator(),
      const SizedBox(height: 16),
      Text('Calculando melhor cobertura...',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
    ]),
  );
}
