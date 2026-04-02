import 'dart:math';
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

// ─── IDs de lendários e míticos (Gen 1–9) ────────────────────────
const _legendaryIds = {
  // Gen 1
  144, 145, 146, 150, 151,
  // Gen 2
  243, 244, 245, 249, 250, 251,
  // Gen 3
  377, 378, 379, 380, 381, 382, 383, 384, 385, 386,
  // Gen 4
  480, 481, 482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493,
  // Gen 5
  494, 638, 639, 640, 641, 642, 643, 644, 645, 646, 647, 648, 649,
  // Gen 6
  716, 717, 718, 719, 720, 721,
  // Gen 7
  785, 786, 787, 788, 789, 790, 791, 792, 793, 794, 795, 796, 797, 798,
  799, 800, 801, 802, 803, 804, 805, 806, 807, 808, 809,
  // Gen 8
  888, 889, 890, 891, 892, 893, 894, 895, 896, 897, 898,
  // Gen 9
  997, 998, 999, 1000, 1001, 1002, 1003, 1004, 1007, 1008, 1009, 1010,
  1014, 1015, 1016, 1017, 1019, 1020, 1021, 1022, 1023, 1024, 1025,
};

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

// ─── Tela ─────────────────────────────────────────────────────────
class TeamSuggestionScreen extends StatefulWidget {
  final Map<String, dynamic> activeGame;
  const TeamSuggestionScreen({super.key, required this.activeGame});
  @override State<TeamSuggestionScreen> createState() => _TeamSuggestionScreenState();
}

class _TeamSuggestionScreenState extends State<TeamSuggestionScreen> {
  Map<String, dynamic> _game       = {};
  List<int>            _pool       = [];
  List<int>            _suggested  = [];
  bool                 _loading    = true;
  bool                 _generating = false;
  bool                 _allowLeg   = false; // padrão: sem lendários
  String?              _saveMsg;

  @override
  void initState() {
    super.initState();
    _game = Map.from(widget.activeGame);
    _loadAndGenerate();
  }

  Future<void> _loadAndGenerate() async {
    setState(() { _loading = true; _saveMsg = null; });
    final sections = PokeApiService.pokedexSections[_game['id']] ?? [];
    final ids = <int>{};
    for (final s in sections) {
      final e = await DexBundleService.instance.loadSection(s.apiName);
      if (e != null) for (final x in e) ids.add(x['speciesId']!);
    }
    if (ids.isEmpty) for (int i = 1; i <= 1025; i++) ids.add(i);
    _pool = ids.toList();
    await _generate();
  }

  Future<void> _generate() async {
    if (!mounted) return;
    setState(() { _generating = true; _saveMsg = null; });
    await Future.delayed(const Duration(milliseconds: 50)); // yield para UI atualizar
    final pool = _allowLeg
        ? _pool
        : _pool.where((id) => !_legendaryIds.contains(id)).toList();
    final team = _buildTeam(pool.isNotEmpty ? pool : _pool);
    if (mounted) setState(() { _suggested = team; _generating = false; _loading = false; });
  }

  List<int> _buildTeam(List<int> pool) {
    final svc      = PokedexDataService.instance;
    final shuffled = List<int>.from(pool)..shuffle(Random());
    final candidates = shuffled.take(min(250, shuffled.length)).toList();
    final team = <int>[];
    for (int step = 0; step < 6; step++) {
      int    bestId    = -1;
      double bestDelta = -9999;
      for (final id in candidates) {
        if (team.contains(id)) continue;
        final delta = _score([...team, id], svc) - _score(team, svc);
        if (delta > bestDelta) { bestDelta = delta; bestId = id; }
      }
      if (bestId == -1) break;
      team.add(bestId);
    }
    return team;
  }

  double _score(List<int> team, PokedexDataService svc) {
    if (team.isEmpty) return 0;
    final covered = <String>{};
    for (final id in team) {
      for (final t in svc.getTypes(id)) {
        (_offChart[t.toLowerCase()] ?? {}).forEach((k, v) {
          if (v >= 2.0) covered.add(k);
        });
      }
    }
    double score = covered.length * 2.0;
    final weakCount = <String, int>{};
    for (final id in team) {
      calculateWeaknesses(svc.getTypes(id)).forEach((k, v) {
        if (v >= 2.0) weakCount[k] = (weakCount[k] ?? 0) + 1;
      });
    }
    for (final c in weakCount.values) {
      if (c >= 3) score -= 3; else if (c == 2) score -= 1;
    }
    final primaryTypes = team.map((id) =>
        svc.getTypes(id).isNotEmpty ? svc.getTypes(id)[0] : '').toSet();
    score += primaryTypes.length * 0.5;
    return score;
  }

  Future<void> _saveTeam() async {
    if (_suggested.isEmpty) return;
    final gameId   = _game['id']   as String? ?? '';
    final gameName = _game['name'] as String? ?? '';
    if (gameId.isEmpty) {
      setState(() => _saveMsg = 'Erro: jogo não selecionado.');
      return;
    }
    try {
      final canSave = await TeamsStorageService.instance.canSave(gameId);
      if (!canSave) {
        if (mounted) setState(() => _saveMsg =
            'Limite de ${TeamsStorageService.maxPerGame} times atingido para este jogo.');
        return;
      }
      final label = _allowLeg ? 'Sugestão (com lendários)' : 'Sugestão';
      final team  = PokemonTeam(
        id:       TeamsStorageService.newId(),
        gameId:   gameId,
        gameName: gameName,
        name:     '$label - $gameName',
        members:  List<int>.from(_suggested),
      );
      await TeamsStorageService.instance.save(team);
      if (mounted) setState(() => _saveMsg = 'Time salvo!');
    } catch (e) {
      if (mounted) setState(() => _saveMsg = 'Erro ao salvar: $e');
    }
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
      setState(() { _game = result; });
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
      appBar: AppBar(title: const Text('Sugestão de Time'),
          scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent),
      // Botões sticky no bottom
      bottomNavigationBar: _loading || _generating ? null : SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_saveMsg != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_saveMsg!, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: _saveMsg!.startsWith('Erro') || _saveMsg!.startsWith('Limite')
                            ? scheme.error : Colors.green.shade700)),
              ),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _generating ? null : _generate,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Nova sugestão'),
                style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    side: BorderSide(color: scheme.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              )),
              const SizedBox(width: 10),
              Expanded(child: FilledButton.icon(
                onPressed: _generating ? null : _saveTeam,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Salvar time'),
                style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              )),
            ]),
          ]),
        ),
      ),
      body: _loading
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              PokeballLoader(),
              SizedBox(height: 16),
              Text('Carregando Pokémon do jogo...'),
            ]))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              children: [

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
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600))),
                  Text('alterar', style: TextStyle(fontSize: 10,
                      color: scheme.onSurfaceVariant)),
                  const SizedBox(width: 2),
                  Icon(Icons.expand_more, size: 14,
                      color: scheme.onSurfaceVariant),
                ]),
              ),
            ),

            const SizedBox(height: 12),

            // Toggle lendários
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant, width: 0.5)),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_allowLeg ? 'Com lendários' : 'Sem lendários',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(_allowLeg
                        ? 'Inclui lendários e míticos'
                        : 'Apenas Pokémon comuns — bom para partidas normais',
                        style: TextStyle(fontSize: 11,
                            color: scheme.onSurfaceVariant)),
                  ],
                )),
                Switch(
                  value: _allowLeg,
                  onChanged: (v) {
                    setState(() => _allowLeg = v);
                    _generate();
                  },
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // Time sugerido
            if (_generating)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  PokeballLoader(),
                  const SizedBox(height: 16),
                  Text('Calculando melhor cobertura...',
                      style: TextStyle(fontSize: 13,
                          color: scheme.onSurfaceVariant)),
                ]),
              )
            else ...[
              Row(children: [
                const Text('Time sugerido', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _allowLeg
                        ? Colors.amber.withOpacity(0.15)
                        : scheme.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    _allowLeg ? 'Com lendários' : 'Sem lendários',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: _allowLeg ? Colors.amber.shade800
                            : scheme.primary)),
                ),
              ]),
              const SizedBox(height: 10),

              // Grid 2×3
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
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
                              color: scheme.onSurfaceVariant
                                  .withOpacity(0.4)))),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                        child: Column(children: [
                          Text(name, style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Row(mainAxisAlignment: MainAxisAlignment.center,
                              children: types.take(2).map((t) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 2),
                                child: Image.asset(typeIconAsset(t),
                                    width: 12, height: 12,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox()),
                              )).toList()),
                        ]),
                      ),
                    ]),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Cobertura expandida
              if (_suggested.isNotEmpty)
                _SuggestionCoverage(members: _suggested),

              const SizedBox(height: 8),
            ],
          ]),
    );
  }
}

// ─── Cobertura ────────────────────────────────────────────────────
class _SuggestionCoverage extends StatelessWidget {
  final List<int> members;
  const _SuggestionCoverage({required this.members});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final svc    = PokedexDataService.instance;
    const allTypes = ['normal','fire','water','electric','grass','ice',
        'fighting','poison','ground','flying','psychic','bug','rock',
        'ghost','dragon','dark','steel','fairy'];

    final covered = <String>{};
    for (final id in members) {
      for (final t in svc.getTypes(id)) {
        (_offChart[t.toLowerCase()] ?? {}).forEach((k, v) {
          if (v >= 2.0) covered.add(k);
        });
      }
    }
    final uncovered = allTypes.where((t) => !covered.contains(t)).toList();

    final weakCount = <String, int>{};
    for (final id in members) {
      calculateWeaknesses(svc.getTypes(id)).forEach((k, v) {
        if (v >= 2.0) weakCount[k] = (weakCount[k] ?? 0) + 1;
      });
    }
    final sharedWeak = weakCount.entries.where((e) => e.value >= 2)
        .toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Score
        Row(children: [
          Icon(Icons.shield_outlined, size: 16,
              color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text('Cobertura: ${covered.length}/18 tipos',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: covered.length >= 15
                  ? Colors.green.withOpacity(0.15)
                  : covered.length >= 10
                      ? Colors.orange.withOpacity(0.12)
                      : scheme.errorContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4)),
            child: Text(
              covered.length >= 15 ? 'Excelente'
                  : covered.length >= 10 ? 'Boa' : 'Fraca',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: covered.length >= 15 ? Colors.green.shade700
                      : covered.length >= 10 ? Colors.orange.shade700
                      : scheme.error)),
          ),
        ]),

        if (sharedWeak.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Fraquezas compartilhadas',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant, letterSpacing: 0.3)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7,
            children: sharedWeak.map((e) {
              final tc = TypeColors.fromType(ptType(e.key));
              final isHigh = e.value >= 3;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tc.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: isHigh ? scheme.error : tc.withOpacity(0.4),
                      width: isHigh ? 1.5 : 0.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset(typeIconAsset(e.key),
                      width: 13, height: 13,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                  const SizedBox(width: 5),
                  Text(ptType(e.key), style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: tc)),
                  const SizedBox(width: 5),
                  Text('${e.value}×', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: isHigh ? scheme.error
                          : scheme.onSurfaceVariant)),
                ]),
              );
            }).toList()),
        ],

        if (uncovered.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Sem cobertura ofensiva',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant, letterSpacing: 0.3)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7,
            children: uncovered.map((t) {
              final tc = TypeColors.fromType(ptType(t));
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tc.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: tc.withOpacity(0.35), width: 0.5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset(typeIconAsset(t), width: 13, height: 13,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                  const SizedBox(width: 5),
                  Text(ptType(t), style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: tc)),
                ]),
              );
            }).toList()),
        ],

        if (uncovered.isEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.check_circle_outline, size: 16,
                color: Colors.green.shade600),
            const SizedBox(width: 6),
            Text('Cobertura ofensiva completa!',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.green.shade700)),
          ]),
        ],
      ]),
    );
  }
}
